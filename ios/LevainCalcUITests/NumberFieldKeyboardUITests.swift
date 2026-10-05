import XCTest

/// 하드웨어 키보드 회귀 테스트 — iPad iOS 17에선 첫 키에 NumberField의 FocusState가 풀렸고, 그 뒤 키는
/// 칸에 보이기만 하고 계산·저장에서 버려졌다. 소프트웨어 키보드가 아니라 HID 키(typeKey)로 친다.
/// iOS 17.5 · 18.2 · 27의 iPad에서 돌릴 것
///
///     xcodebuild test -project ios/LevainCalc.xcodeproj -scheme LevainCalc \
///       -destination 'platform=iOS Simulator,name=<iPad>,OS=17.5' \
///       -only-testing:LevainCalcUITests/NumberFieldKeyboardUITests
final class NumberFieldKeyboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDataDir", "uitest-\(UUID().uuidString)",
            "-appLanguage", "ko",
        ]
        app.launch()
        return app
    }

    /// NumberField에 단 식별자는 행·라벨·단위·입력 칸에 모두 붙는다 — 입력 칸만 고른다
    @MainActor
    private func numberField(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let field = app.textFields[identifier].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), identifier)
        return field
    }

    /// 결과 바 뒤에 가린 칸을 누르면 결과 바가 눌린다 — 칸이 바 위로 올라올 때까지 목록을 민다
    @MainActor
    private func revealAboveResultBar(_ app: XCUIApplication, _ field: XCUIElement) {
        let bar = app.descendants(matching: .any)["calc.resultBar"].firstMatch
        let list = app.collectionViews.firstMatch
        var attempts = 0
        while field.frame.maxY > bar.frame.minY - 8, attempts < 6 {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(
                    forDuration: 0.05,
                    thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
            attempts += 1
        }
    }

    /// 칸을 눌러 포커스를 준 뒤 하드웨어 키로 지우고 친다
    @MainActor
    private func typeWithHardwareKeys(_ app: XCUIApplication, into field: XCUIElement, _ text: String) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        _ = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)],
            timeout: 2)
        // 포커스 때 값 전체가 선택되지만(SelectAllOnFocus) 선택이 늦게 걸리는 경우를 위해 남은 글자도 지운다
        let current = field.value as? String ?? ""
        for _ in 0...current.count {
            app.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
        }
        for character in text {
            app.typeKey(String(character), modifierFlags: [])
        }
    }

    @MainActor
    func testHardwareKeyboardDigitsReachCalculation() throws {
        let app = launch()
        let bar = app.descendants(matching: .any)["calc.resultBar"].firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        // 기본 배합(T65 900 · 물 620 · 르방 200 @100%)의 총 수분율 72.0%
        XCTAssertTrue(bar.label.contains("72.0%"), bar.label)

        let water = numberField(app, "ingredient.water")
        revealAboveResultBar(app, water)
        typeWithHardwareKeys(app, into: water, "700")
        // (700 + 100) / (900 + 100) = 80.0%, 총 반죽 900 + 700 + 200 + 소금 20 = 1820 g
        let updated = NSPredicate(format: "label CONTAINS %@", "80.0%")
        expectation(for: updated, evaluatedWith: bar)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(bar.label.contains("1820"), bar.label)
        XCTAssertEqual(water.value as? String, "700")
    }

    /// iOS 17.5에선 편집 중에도 FocusState가 false로 거듭 튀어, 그때마다 "703."이 "703"으로 되돌려지고
    /// 다음 키가 잘린 글자 뒤에 붙었다(703.05 → 70305). 튀는 시점이 들쭉날쭉해 여러 번 친다.
    /// 매번 새로 띄운다 — 편집 중인 칸을 다시 누르면 편집 메뉴가 떠 지우기 키를 삼킨다
    @MainActor
    func testHardwareKeyboardDecimalsSurvive() throws {
        // (물 + 르방 속 물 100) / (900 + 100)
        for (typed, hydration) in [("703.05", "80.3%"), ("711.15", "81.1%"), ("722.45", "82.2%")] {
            let app = launch()
            let bar = app.descendants(matching: .any)["calc.resultBar"].firstMatch
            XCTAssertTrue(bar.waitForExistence(timeout: 10))
            let water = numberField(app, "ingredient.water")
            revealAboveResultBar(app, water)
            typeWithHardwareKeys(app, into: water, typed)
            expectation(for: NSPredicate(format: "label CONTAINS %@", hydration), evaluatedWith: bar)
            waitForExpectations(timeout: 5)
            XCTAssertEqual(water.value as? String, typed)
        }
    }
}
