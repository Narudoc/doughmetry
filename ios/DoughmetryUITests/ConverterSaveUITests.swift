import XCTest

/// 변환 결과를 새 레시피로 저장하면 원본의 분할 개수·태그가 따라간다 — 계산기 → 변환 → 저장 → 레시피 상세 → 다시 변환기로.
/// DoughmetryUITests처럼 실행마다 빈 저장 폴더(-uiTestDataDir)로 시작하고, 화면 요소는 접근성 식별자로 찾는다
final class ConverterSaveUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// 폼은 화면에 들어온 행만 접근성 요소로 만든다 — 대상이 보이고 결과 바(있으면) 위로 올라올 때까지 민다
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

    /// 저장 시트에 원본의 태그와 분할 행(개당 무게는 변환 결과의 총 반죽 기준)이 미리 채워졌는지
    @MainActor
    private func assertSaveSheetCarriesSource(_ app: XCUIApplication, tags: String, each: String) {
        let field = app.textFields["saveRecipe.tags"].firstMatch
        XCTAssertTrue(waitForSheetToSettle(field, timeout: 5))
        XCTAssertEqual(field.value as? String, tags)
        let division = element(app, "saveRecipe.division")
        XCTAssertTrue(division.exists, "분할 미리보기 행이 없다")
        XCTAssertTrue(division.label.hasPrefix("분할 2개"), division.label)
        XCTAssertEqual(division.value as? String, each)
    }

    @MainActor
    func testConvertedRecipeKeepsPiecesAndTags() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestDataDir", "uitest-\(UUID().uuidString)", "-appLanguage", "ko"]
        app.launch()

        // 기본 배합(총 반죽 1740 g)을 2개로 나누고 태그를 달아 저장한다 — 계산기가 이 레시피에 연결된다
        XCTAssertTrue(element(app, "calc.save").waitForExistence(timeout: 10))
        let pieces = app.textFields["calc.pieces"].firstMatch
        reveal(app, pieces)
        pieces.tap()
        let current = pieces.value as? String ?? ""
        pieces.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1) + "2")
        element(app, "calc.save").tap()
        let tags = app.textFields["saveRecipe.tags"].firstMatch
        XCTAssertTrue(waitForSheetToSettle(tags, timeout: 5))
        tags.tap()
        tags.typeText("weekend, rye")
        element(app, "saveRecipe.confirm").tap()
        XCTAssertTrue(tags.waitForNonExistence(timeout: 5))

        let send = element(app, "calc.sendToConverter")
        reveal(app, send)
        send.tap()

        // 르방 질량 고정 변환은 총 반죽을 바꾸지 않는다 — 개당 870 g 그대로
        let convert = element(app, "converter.save")
        XCTAssertTrue(convert.waitForExistence(timeout: 5))
        convert.tap()
        assertSaveSheetCarriesSource(app, tags: "weekend, rye", each: "870.0그램")
        element(app, "saveRecipe.confirm").tap()
        XCTAssertTrue(tags.waitForNonExistence(timeout: 5))

        // 레시피 탭(iPhone은 아래, iPadOS 18+는 위 탭 막대)
        let recipesTab = app.tabBars.buttons["레시피"].exists ? app.tabBars.buttons["레시피"] : app.buttons["레시피"].firstMatch
        recipesTab.tap()
        let converted = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "recipes.row", "캉파뉴 (뒤흐 50%)")
        ).firstMatch
        XCTAssertTrue(converted.waitForExistence(timeout: 5))
        converted.tap()

        // 새 레시피의 배합표에 분할 행과 태그가 있다
        XCTAssertTrue(app.staticTexts["#weekend #rye"].waitForExistence(timeout: 5), "태그가 저장되지 않았다")
        let divisionRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "분할 2개 — 개당")).firstMatch
        // 화면 가운데는 iPhone에선 상세, iPad 두 열에선 상세 열이다
        for _ in 0..<8 where !divisionRow.exists {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(divisionRow.exists, "분할 개수가 저장되지 않았다")

        // 상세에서 다시 변환기로 — 레시피의 분할·태그가 함께 간다
        app.buttons["변환기로 보내기"].firstMatch.tap()
        XCTAssertTrue(convert.waitForExistence(timeout: 5))
        convert.tap()
        assertSaveSheetCarriesSource(app, tags: "weekend, rye", each: "870.0그램")
    }
}
