import XCTest

/// 계산기 이름 칸 아래 상태 줄, 저장 시트의 '덮어쓰기'·'새 레시피로 저장', 변환기 → 계산기 보내기.
/// DoughmetryUITests처럼 실행마다 빈 저장 폴더(-uiTestDataDir)로 시작하고, 화면 요소는 접근성 식별자로 찾는다
final class CalculatorLinkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestDataDir", "uitest-\(UUID().uuidString)", "-appLanguage", "ko"]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// iPhone은 아래 탭 막대, iPad(iPadOS 18+)는 위 탭 막대. 키보드가 떠 있으면 아래 탭 막대를 가린다 —
    /// 결과 바의 완료로 먼저 내린다
    @MainActor
    private func openTab(_ app: XCUIApplication, _ label: String) {
        if app.keyboards.firstMatch.exists {
            app.buttons["완료"].firstMatch.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        }
        let inBar = app.tabBars.buttons[label]
        (inBar.exists ? inBar : app.buttons[label].firstMatch).tap()
    }

    @MainActor
    private func replace(_ field: XCUIElement, with text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1) + text)
    }

    /// 폼은 화면에 들어온 행만 접근성 요소로 만든다 — 대상이 보이고 결과 바 위로 올라올 때까지 민다
    @MainActor
    private func reveal(_ app: XCUIApplication, _ target: XCUIElement) {
        let bar = element(app, "calc.resultBar")
        let list = app.collectionViews.firstMatch
        for _ in 0..<10 {
            if target.exists, target.isHittable, !(bar.exists && target.frame.maxY > bar.frame.minY - 8) { return }
            list.swipeUp(velocity: .slow)
        }
    }

    /// 시트 전환 중의 탭은 버려진다 — DoughmetryUITests.waitForSheetToSettle과 같은 이유
    @MainActor
    private func waitForSheetToSettle(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        Thread.sleep(forTimeInterval: 1)
        return element.isHittable
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) {
        expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 5) {
        expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    /// 계산기 위로 올라오는 아래 결과 바·키보드가 이름 칸을 가리지 않게 목록을 맨 위로
    @MainActor
    private func scrollToTop(_ app: XCUIApplication) {
        let name = app.textFields["calc.name"].firstMatch
        for _ in 0..<10 where !(name.exists && name.isHittable) {
            app.collectionViews.firstMatch.swipeDown(velocity: .fast)
        }
    }

    @MainActor
    func testStatusLineAndExplicitSaveChoices() throws {
        let app = launch()
        let status = element(app, "calc.status")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "예시 배합")

        let name = app.textFields["calc.name"].firstMatch
        replace(name, with: "Alpha")
        waitForLabel(status, "새 배합 · 저장 안 됨")

        // 이어진 레시피가 없으면 저장 버튼 하나 — 덮어쓰기는 없다
        element(app, "calc.save").tap()
        let confirm = element(app, "saveRecipe.confirm")
        XCTAssertTrue(waitForSheetToSettle(confirm, timeout: 5))
        XCTAssertFalse(element(app, "saveRecipe.overwrite").exists)
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        waitForLabel(status, "저장된 레시피 · 변경 없음")

        replace(name, with: "Alpha 2")
        waitForLabel(status, "수정됨 — 저장 안 됨")

        // 이어진 레시피를 고쳤으면 두 버튼 — 덮어쓰기는 이름도 바뀐다고 밝힌다
        element(app, "calc.save").tap()
        let overwrite = element(app, "saveRecipe.overwrite")
        XCTAssertTrue(waitForSheetToSettle(overwrite, timeout: 5))
        XCTAssertTrue(confirm.exists, "새 레시피로 저장 버튼이 없다")
        XCTAssertTrue(
            overwrite.label.contains("'Alpha' 레시피를 바꾸고 이름을 'Alpha 2'(으)로 고칩니다"), overwrite.label)
        overwrite.tap()
        XCTAssertTrue(overwrite.waitForNonExistence(timeout: 5))
        waitForLabel(status, "저장된 레시피 · 변경 없음")

        // 덮어썼으니 레시피는 여전히 하나
        openTab(app, "레시피")
        let rows = app.buttons.matching(identifier: "recipes.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.firstMatch.label.hasPrefix("Alpha 2"), rows.firstMatch.label)
    }

    /// 모드 B 저장은 레시피와 잇지 않는다 — 저장한 그대로면 상태 줄도 저장됨
    @MainActor
    func testModeBSaveShowsSaved() throws {
        let app = launch()
        let status = element(app, "calc.status")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        app.buttons["목표 역산"].firstMatch.tap()
        waitForLabel(status, "새 배합 · 저장 안 됨")

        element(app, "calc.save").tap()
        let confirm = element(app, "saveRecipe.confirm")
        XCTAssertTrue(waitForSheetToSettle(confirm, timeout: 5))
        XCTAssertFalse(element(app, "saveRecipe.overwrite").exists)
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        waitForLabel(status, "저장된 레시피 · 변경 없음")

        replace(app.textFields["calc.name"].firstMatch, with: "Beta")
        waitForLabel(status, "새 배합 · 저장 안 됨")
    }

    @MainActor
    func testConverterSendsConvertedDoughToCalculatorUnlinked() throws {
        let app = launch()
        let status = element(app, "calc.status")
        XCTAssertTrue(status.waitForExistence(timeout: 10))

        // 손대지 않은 예시는 지워질 입력이 없다 — 확인 없이 계산기로 간다
        let send = element(app, "calc.sendToConverter")
        reveal(app, send)
        send.tap()
        let more = element(app, "converter.more")
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let sendToCalc = app.buttons["converter.sendToCalc"].firstMatch
        XCTAssertTrue(sendToCalc.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["converter.share"].firstMatch.exists, "배합표 공유가 없다")
        sendToCalc.tap()

        XCTAssertTrue(
            app.staticTexts["'캉파뉴 (뒤흐 50%)'을(를) 계산기로 보냈습니다"].waitForExistence(timeout: 3),
            "보냈다는 알림이 없다")
        scrollToTop(app)
        let name = app.textFields["calc.name"].firstMatch
        waitForValue(name, "캉파뉴 (뒤흐 50%)")
        waitForLabel(status, "새 배합 · 저장 안 됨")

        // 레시피와 잇지 않았다 — 저장 시트에 덮어쓰기가 없다
        element(app, "calc.save").tap()
        let confirm = element(app, "saveRecipe.confirm")
        XCTAssertTrue(waitForSheetToSettle(confirm, timeout: 5))
        XCTAssertFalse(element(app, "saveRecipe.overwrite").exists)
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        waitForLabel(status, "저장된 레시피 · 변경 없음")

        // 저장하지 않은 입력이 있으면 바꾸기 전에 묻는다
        replace(name, with: "Draft")
        waitForLabel(status, "수정됨 — 저장 안 됨")
        openTab(app, "변환")
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(sendToCalc.waitForExistence(timeout: 5))
        sendToCalc.tap()
        let confirmSend = app.buttons["converter.confirmSendToCalc"].firstMatch
        XCTAssertTrue(confirmSend.waitForExistence(timeout: 5), "확인창이 없다")
        confirmSend.tap()
        scrollToTop(app)
        waitForValue(name, "캉파뉴 (뒤흐 50%)")
        waitForLabel(status, "새 배합 · 저장 안 됨")

        // 변환 결과의 배합표 공유 — 메뉴 안의 ShareLink가 공유 시트를 띄운다
        openTab(app, "변환")
        more.tap()
        let share = app.buttons["converter.share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5), "공유 시트가 뜨지 않았다")
    }
}
