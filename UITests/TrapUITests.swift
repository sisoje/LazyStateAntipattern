import XCTest

/// One script, three scenarios: one unrelated tap, then one related tap.
/// Every step is the same; only the child that builds the model differs.
final class TrapUITests: XCTestCase {
    // The parent's input ends at 2, so a correct child's model holds 2.

    /// Follows the input; one model per input value (1, 2).
    @MainActor
    func testMemoView() {
        run(scenario: "memo", modelInput: 2, modelsCreated: 2)
    }

    /// Stale, and a model created on every parent render (launch + 2 taps),
    /// 2 thrown away.
    @MainActor
    func testState() {
        run(scenario: "state", modelInput: 1, modelsCreated: 3)
    }

    /// One model, and stale: still the one built from input 1.
    @MainActor
    func testLazyState() {
        run(scenario: "lazyState", modelInput: 1, modelsCreated: 1)
    }

    @MainActor
    private func run(scenario: String, modelInput: Int, modelsCreated: Int) {
        let app = XCUIApplication()
        app.launchEnvironment["SCENARIO"] = scenario
        app.launch()

        app.buttons["unrelated action"].tap()
        app.buttons["related action"].tap()

        XCTAssertTrue(app.staticTexts["parent input 2"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["model input \(modelInput)"].exists)
        XCTAssertTrue(app.staticTexts["models created \(modelsCreated)"].exists)
    }
}
