# The Lazy State Trap from Point-Free

*Elaborate machinery built on a premise SwiftUI already rejects, then more
machinery to manage the consequences. Measured.*

A model built from an input: `@State`, Point-Free's `@LazyState`, and a Memo.
One screen, one test script, three results.

A parent owns an input and hands it to a child. The child builds an
`@Observable` model from it: `Model(input: input)`. Three scenarios differ
only in how the child holds that model:

```swift
_model = State(wrappedValue: Model(input: input))                    // StateChild
_model = LazyState { Model(input: input) }                           // LazyStateChild
MemoView(Model(input: input), dependencies: [input]) { model in … }  // MemoChild
```

The parent shows two buttons:

- "related action": bumps the input it hands the child
- "unrelated action": bumps a counter the child never sees

The child shows two lines:

- "model input": the input its model was built from
- "models created": counted inside `Model.init`

The script: one unrelated tap, then one related tap. The parent's input ends
at 2. One UI test per scenario runs it and asserts its row:

| child holds the model with | model input | models created |
|---|---|---|
| `@State`, built in `init` | 1 (stale) | 3 |
| Point-Free's `@LazyState` | 1 (stale) | 1 |
| a Memo keyed by the input | **2** | 2 |

Only the Memo row puts the rebuild under the data flow's control: the listed
dependencies decide. The stale rows can only be repaired by handing control
to the UI runtime: `.id()` resets the whole subtree, `onChange(of:)` patches
state a render late.

Run it: `xcodegen generate`, then the `TrapUITests` in `LazyStateTrap.xcodeproj`.
Needs Xcode 27 (Point-Free's package is swift-tools 6.4); the deployment
target is iOS 26.

## The UI tests

The table is not prose: each row is an assertion. One helper runs the
script; the three tests are one call each:

```swift
func testState() {
    run(scenario: "state", modelInput: 1, modelsCreated: 3)
}

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
```

`SCENARIO` picks the child at launch, the taps are real, and the assertions
are the screen's own labels. The lock holds in both directions: if a future
`@LazyState` starts following the input, its row fails.

## References

- Apple, [`State.init(wrappedValue:)`](https://developer.apple.com/documentation/swiftui/state/init(wrappedvalue:)):
  "You don't call this initializer directly."
- Point-Free, [`swiftui-lazy-state`](https://github.com/pointfreeco/swiftui-lazy-state):
  the value lives "at least until the view's identity changes".
- [swift-core-flow](https://github.com/sisoje/swift-core-flow): `MemoView`
  keeps a value across renders and rebuilds it only when its dependencies change.
- [SwiftUI Data Flow Masterclass](https://medium.com/@redhotbits/swiftui-data-flow-masterclass-099f0768f776):
  data enters a node at creation; dependency-tracked invalidation.
