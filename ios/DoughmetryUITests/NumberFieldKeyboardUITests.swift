import XCTest

/// 하드웨어 키보드 회귀 테스트 — iPad iOS 17에선 첫 키에 NumberField의 FocusState가 풀렸고, 그 뒤 키는
/// 칸에 보이기만 하고 계산·저장에서 버려졌다. 소프트웨어 키보드가 아니라 HID 키(typeKey)로 친다.
/// iOS 17.5 · 18.2 · 27의 iPhone·iPad에서 돌릴 것
///
///     xcodebuild test -project ios/Doughmetry.xcodeproj -scheme Doughmetry \
///       -destination 'platform=iOS Simulator,name=<기기>,OS=17.5' \
///       -only-testing:DoughmetryUITests/NumberFieldKeyboardUITests
final class NumberFieldKeyboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestDataDir", "uitest-\(UUID().uuidString)",
            "-appLanguage", "ko",
        ]
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
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

    /// 칸을 눌러 포커스를 준 뒤 하드웨어 키로 지우고 친다.
    /// 칸의 가운데를 누른다 — iOS 17·18 목록은 칸의 틀을 행 전체로 알리기도 해, 오른쪽 끝(dx 0.9)이 단위 "g"에 떨어졌다
    @MainActor
    private func typeWithHardwareKeys(_ app: XCUIApplication, into field: XCUIElement, _ text: String) {
        field.tap()
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

    /// 칸(UITextField)은 한 줄 높이라 44pt 행의 위쪽 여백과, 접근성 글자 크기에서 윗줄로 올라간 라벨은 칸 밖이다 —
    /// 그 자리를 눌러도 칸이 포커스를 얻어야 한다 (NumberField 바탕 FieldTapArea)
    @MainActor
    func testTappingAboveFieldFocusesIt() throws {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = launch(contentSize: size)
            let bar = app.descendants(matching: .any)["calc.resultBar"].firstMatch
            XCTAssertTrue(bar.waitForExistence(timeout: 10))
            let list = app.collectionViews.firstMatch
            let water = app.textFields["ingredient.water"].firstMatch
            // 큰 글자에선 물 행이 아직 만들어지지 않았다 — 나타날 때까지 목록을 민다
            var swipes = 0
            while !water.waitForExistence(timeout: 1), swipes < 15 {
                list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                    .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
                swipes += 1
            }
            let row = app.cells.containing(.textField, identifier: "ingredient.water").firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), size)
            // 행 전체가 내비게이션 바와 결과 바 사이에 오도록
            let top = app.navigationBars.firstMatch.frame.maxY
            var attempts = 0
            while attempts < 8 {
                let up = row.frame.maxY > bar.frame.minY - 8
                let down = row.frame.minY < top + 8
                guard up != down else { break }
                list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(
                        forDuration: 0.05,
                        thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.4 : 0.6)))
                attempts += 1
            }
            Thread.sleep(forTimeInterval: 1)
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.08)).tap()
            expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: water)
            waitForExpectations(timeout: 3)
            app.terminate()
        }
    }

    /// 한 행에 쌓인 칸(액체 이름·무게 아래 수분 함량) — 아래 칸의 늘린 여백이 윗칸의 아래쪽을 덮어도
    /// 윗칸을 누르면 윗칸이 포커스를 얻는다 (iOS 17은 tap.location(in: window)가 (0,0)이었다)
    @MainActor
    func testStackedFieldKeepsOwnFocus() throws {
        let app = launch()
        let bar = app.descendants(matching: .any)["calc.resultBar"].firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        let list = app.collectionViews.firstMatch
        let add = app.buttons["액체 재료 추가"].firstMatch
        var swipes = 0
        while !(add.exists && add.isHittable && add.frame.maxY < bar.frame.minY - 8), swipes < 15 {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
            swipes += 1
        }
        // 요소 tap()은 iOS 17.5에서 메뉴를 열지 못하기도 한다 — 라벨 글자 자리를 좌표로 누르고, 안 열리면 한 번 더
        let milk = app.buttons["우유 (수분 88%)"].firstMatch
        Thread.sleep(forTimeInterval: 1)
        for _ in 0..<2 where !milk.exists {
            add.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            _ = milk.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(milk.waitForExistence(timeout: 2))
        milk.tap()
        let name = app.textFields["액체 재료 이름"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        revealAboveResultBar(app, app.textFields["우유 수분 함량 (%)"].firstMatch)
        Thread.sleep(forTimeInterval: 1)
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75)).tap()
        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: name)
        waitForExpectations(timeout: 3)
    }
}
