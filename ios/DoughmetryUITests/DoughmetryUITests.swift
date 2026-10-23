import XCTest

/// 출시 전 스모크 테스트 — 앱을 띄워 탭 이동·계산·저장·가져오기 확인 흐름을 한 번씩 지난다.
/// 실행마다 빈 저장 폴더(-uiTestDataDir, DEBUG 빌드 전용)로 시작하고 iCloud와 합치지 않는다.
/// 화면 요소는 접근성 식별자로 찾는다 — 라벨은 앱 언어(-appLanguage)에 따라 바뀐다.
///
///     xcodebuild test -project ios/Doughmetry.xcodeproj -scheme Doughmetry \
///       -destination 'platform=iOS Simulator,name=<기기>,OS=<버전>' -only-testing:DoughmetryUITests
final class DoughmetryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 탭 라벨 (앱 언어별) — 탭 막대 항목에는 접근성 식별자를 달 수 없다
    private static let tabLabels = [
        "ko": ["계산기", "변환", "레시피", "도구"],
        "en": ["Calculator", "Convert", "Recipes", "Tools"],
    ]

    @MainActor
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        // 상대 경로는 앱 임시 폴더 아래 — 실행마다 새 폴더라 앞 테스트의 레시피·draft가 남지 않는다
        app.launchArguments = [
            "-uiTestDataDir", "uitest-\(UUID().uuidString)",
            "-appLanguage", language,
        ]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// iPhone은 아래 탭 막대, iPad(iPadOS 18+)는 위 탭 막대 — 어느 쪽이든 라벨로 찾는다
    @MainActor
    private func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[label]
        return inBar.exists ? inBar : app.buttons[label].firstMatch
    }

    @MainActor
    private func openTab(_ app: XCUIApplication, language: String, index: Int) {
        let label = Self.tabLabels[language]![index]
        let button = tab(app, label)
        XCTAssertTrue(button.waitForExistence(timeout: 10), "탭 \(label)")
        button.tap()
    }

    /// NumberField에 단 식별자는 행·라벨·단위·입력 칸에 모두 붙는다 — 입력 칸만 고른다
    @MainActor
    private func numberField(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let field = app.textFields[identifier].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), identifier)
        return field
    }

    /// 숫자 칸은 포커스를 얻으면 값 전체가 선택된다 (SelectAllOnFocus) — 지우고 치는 것과 같지만
    /// 선택이 늦게 걸리는 경우를 위해 남은 글자도 지운다
    @MainActor
    private func replace(_ field: XCUIElement, with text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1) + text)
    }

    /// 시트 안 요소는 올라오는 애니메이션이 시작될 때부터 보이는데, 시트 전환은 탭 전의 '앱이 한가해질 때까지
    /// 기다림'에 잡히지 않는다 — 전환 중의 탭은 앱에 전달되지 않고 버려진다 (iOS 27에서 확인). Apple Intelligence
    /// 초안처럼 결과가 늦게 오면 존재 확인 직후가 전환 한가운데일 수 있어, 시트 안을 누르기 전에 전환이 끝나기를 기다린다
    @MainActor
    private func waitForSheetToSettle(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        Thread.sleep(forTimeInterval: 1)
        return element.isHittable
    }

    /// 결과 바는 목록 위에 떠 있다 — 그 뒤에 가린 칸을 누르면 결과 바가 눌려 배합표 시트가 열린다.
    /// 작은 화면이나 키보드가 올라온 상태에서는 칸이 결과 바 위로 올라올 때까지 목록을 민다
    @MainActor
    private func revealAboveResultBar(_ app: XCUIApplication, _ field: XCUIElement) {
        let bar = element(app, "calc.resultBar")
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

    // MARK: - (a) 네 탭 — 한국어·영어

    @MainActor
    func testVisitAllTabsInBothLanguages() throws {
        for language in ["ko", "en"] {
            let app = launch(language: language)
            for index in 0..<4 {
                openTab(app, language: language, index: index)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "\(language)-tab\(index)"
                shot.lifetime = .keepAlways
                add(shot)
            }
            app.terminate()
        }
    }

    // MARK: - (b) 계산기 입력 → 결과 바

    @MainActor
    func testCalculatorInputUpdatesResultBar() throws {
        let app = launch(language: "ko")
        let bar = element(app, "calc.resultBar")
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        let before = bar.label
        // 기본 배합(T65 900 · 물 620 · 르방 200 @100%)의 총 수분율은 72% — %는 늘 소수 한 자리 (fmtPct)
        XCTAssertTrue(before.contains("72.0%"), before)

        for (identifier, text) in [("ingredient.flourGrams", "1000"), ("ingredient.water", "750")] {
            let field = numberField(app, identifier)
            revealAboveResultBar(app, field)
            replace(field, with: text)
        }
        // (750 + 100) / (1000 + 100) = 77.3%
        let updated = NSPredicate(format: "label CONTAINS %@", "77.3%")
        expectation(for: updated, evaluatedWith: bar)
        waitForExpectations(timeout: 5)
        XCTAssertNotEqual(bar.label, before)
    }

    // MARK: - (c) 저장 → 레시피 목록 → 계산기로 불러오기

    @MainActor
    func testSaveRecipeAndLoadBack() throws {
        let app = launch(language: "ko")
        let save = element(app, "calc.save")
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let confirm = element(app, "saveRecipe.confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        openTab(app, language: "ko", index: 2)
        let row = element(app, "recipes.row")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let load = element(app, "recipeDetail.load")
        XCTAssertTrue(load.waitForExistence(timeout: 5))
        load.tap()

        // 저장한 그대로라 확인 없이 계산기 탭으로 돌아온다
        XCTAssertTrue(element(app, "calc.resultBar").waitForExistence(timeout: 5))
        // iPadOS 18+의 위 탭 막대 항목은 선택 상태를 알리지 않는다 — 아래 탭 막대(iPhone)에서만 본다
        let calculatorTab = app.tabBars.buttons["계산기"]
        if calculatorTab.exists { XCTAssertTrue(calculatorTab.isSelected) }
    }

    // MARK: - (c′) 계산기 불러오기 — 이름으로 검색해 고른다

    @MainActor
    func testCalculatorLoadPickerSearch() throws {
        let app = launch(language: "ko")
        let name = app.textFields["calc.name"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        for recipeName in ["Alpha Loaf", "Beta Loaf"] {
            replace(name, with: recipeName)
            element(app, "calc.save").tap()
            let confirm = element(app, "saveRecipe.confirm")
            XCTAssertTrue(waitForSheetToSettle(confirm, timeout: 5))
            confirm.tap()
            XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        }
        // 저장하지 않은 입력이 남게 — 고르면 확인을 거친다
        replace(name, with: "Draft")

        element(app, "calc.loadRecipe").tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(waitForSheetToSettle(search, timeout: 5))
        let rows = app.buttons.matching(identifier: "recipePicker.row")
        XCTAssertEqual(rows.count, 2)
        search.tap()
        search.typeText("alpha")
        expectation(for: NSPredicate(format: "count == 1"), evaluatedWith: rows)
        waitForExpectations(timeout: 5)
        rows.firstMatch.tap()

        let confirmLoad = app.buttons["recipePicker.confirmLoad"].firstMatch
        if confirmLoad.waitForExistence(timeout: 3) { confirmLoad.tap() }
        XCTAssertTrue(element(app, "recipePicker.list").waitForNonExistence(timeout: 5), "고른 뒤 목록이 닫히지 않았다")
        let loaded = NSPredicate(format: "value == %@", "Alpha Loaf")
        expectation(for: loaded, evaluatedWith: name)
        waitForExpectations(timeout: 5)
    }

    // MARK: - (d) 텍스트 가져오기는 확인 시트를 거친다

    @MainActor
    func testTextImportGoesThroughReview() throws {
        let app = launch(language: "ko")
        openTab(app, language: "ko", index: 2)

        for confirmSave in [false, true] {
            let entry = element(app, "recipes.import")
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            let paste = app.buttons["텍스트 붙여넣기"].firstMatch
            XCTAssertTrue(paste.waitForExistence(timeout: 5))
            paste.tap()

            let text = app.textViews.firstMatch
            XCTAssertTrue(waitForSheetToSettle(text, timeout: 5))
            text.tap()
            // iPad 폼 시트는 키보드가 올라오면 위로 옮겨 간다 — 옮긴 뒤에 쳐야 '분석'을 제자리에서 누른다.
            // 지운 시뮬레이터의 첫 키보드는 20초 가까이 걸린다
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 30)
            text.typeText("Flour T65 900g\nWater 620g\nSalt 20g\nLevain 200g")
            element(app, "textImport.analyze").tap()

            // 인식 결과는 저장 전에 반드시 확인 시트로 — 확인 없이 라이브러리에 들어가면 안 된다.
            // Apple Intelligence 분석은 10초 기한을 넘기면 규칙 결과로 넘어간다 — 설치 직후 모델을 처음 올리는 시간까지 넉넉히
            let reviewSave = element(app, "importReview.save")
            XCTAssertTrue(waitForSheetToSettle(reviewSave, timeout: 60), "확인 시트가 뜨지 않았다")
            if confirmSave {
                reviewSave.tap()
                XCTAssertTrue(reviewSave.waitForNonExistence(timeout: 5), "저장을 눌렀는데 확인 시트가 닫히지 않았다")
                XCTAssertTrue(element(app, "recipes.row").waitForExistence(timeout: 5))
            } else {
                element(app, "importReview.cancel").tap()
                XCTAssertTrue(reviewSave.waitForNonExistence(timeout: 5))
                XCTAssertFalse(element(app, "recipes.row").exists, "확인 시트를 닫았는데 레시피가 저장됐다")
            }
        }
    }
}
