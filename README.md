# LazyState: Point-Free's newest antipattern

*Built on a premise SwiftUI already rejects: state seeded from a parent's
value. Three UI tests show what it costs.*

> "Many real models cannot be created with a static inline default. They need
> data from the parent view."
>
> Point-Free, [LazyState 1.0](https://www.pointfree.co/blog/posts/228-lazystate-1-0-now-available-to-everyone)

```swift
struct Child: View {
    @State private var model = Model(input: parentValue)
}
```

A model built from a parent's value has two requirements, and both must hold:

1. **The model follows the input.** When the parent's value changes, the child
   shows a model built from the new value.
2. **The model is kept otherwise.** A parent re-render that does not change the
   input builds nothing and keeps the same instance.

This line asks for a second source of truth. `parentValue` belongs to the
parent; `@State` would freeze a model built from its first value, and
requirement 1 fails.

The line does not even compile, and that is the least of its problems. Instead
of fixing the data flow, the usual workaround moves it into `init`:

```swift
_model = State(wrappedValue: Model(input: parentValue))
```

**This is the line [Apple](https://developer.apple.com/documentation/swiftui/state/init(wrappedvalue:))
tells you not to write: "You don't call this initializer directly."**

## Proper alternatives

Fix the data flow instead. There are two ways to remove the second source of
truth:

1. **Up: create it on the event.** The opposite of what most people do. A view
   struct's `init` runs on every parent render, but a node enters the graph
   once, on a mutation. That mutation, or the one that changes the input,
   builds the model, and the parent passes it down. The child stays dumb; the
   parent knows how to build its model.
2. **Down: derive it by dependencies.** The model stays in the child, derived
   instead of seeded: the parent passes only the value, and the model should be
   rebuilt when that value changes, kept otherwise. The parent stays dumb; the
   child lists what the model depends on.

## Point-Free's answer

The `init` workaround builds a model on every parent render and throws all but
the first away. Point-Free keeps the premise and makes it cheaper:

```swift
_model = LazyState { Model(input: parentValue) }
```

The closure runs once, so only one model is built. But it is still the one
built from the first value, and it ignores every value after.

**The waste is gone. The staleness stays.**

Their README concedes it: "Once a view's state is initialized it cannot be
updated from the outside by providing a new parameter. The state must be
updated by other means, such as using `onChange(of:)` or `task(id:)` in the
view, or changing the view's identity." The data flow is left to repairs.

The usual defence is that state is meant to behave this way: the child owns
its source of truth, and the parent only seeds it. But the value was never the child's.
A copy the child controls is a duplicated source of truth, and a `Binding`
does not help: it shares the value, it does not rebuild a model derived from
it.

## The measurement

One screen, one test script. A parent owns an input and hands it to a child.
The child builds an `@Observable` model from it: `Model(input: input)`. Two
scenarios hold that model the wrong way:

```swift
_model = State(wrappedValue: Model(input: input))  // StateChild
_model = LazyState { Model(input: input) }         // LazyStateChild
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

`@State` fails both requirements: a model on every parent render, three here,
and the one it keeps is stale. `@LazyState` builds one, just as stale. Both
can only be repaired by handing control to the UI runtime: `.id()` resets the
whole subtree, `onChange(of:)` patches state a render late.

## The correct way

**The correct way to create the model within the child is a Memo keyed by the
input**: the second way, packaged. The first way needs no machinery and is not
measured here.

```swift
MemoView(Model(input: input), dependencies: [input]) { model in … }  // MemoChild
```

The same script, all three scenarios:

| child holds the model with | model input | models created |
|---|---|---|
| `@State`, built in `init` | 1 (stale) | 3 |
| Point-Free's `@LazyState` | 1 (stale) | 1 |
| a Memo keyed by the input | **2** | 2 |

The Memo meets both requirements and needs no repair from the physical view
lifecycle: no `.id()`, no `onChange(of:)`, no `task(id:)`. **It controls the
data flow directly**: while the view lives, the listed dependencies alone
decide when the model is rebuilt. A changed dependency replaces the whole
model, so state that must survive an input change does not belong in it.

## The UI tests

The tables are not prose: each row is an assertion. One helper runs the
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

Run it: `xcodegen generate`, then the `TrapUITests` in `LazyStateTrap.xcodeproj`.
Needs Xcode 27 (Point-Free's package is swift-tools 6.4); the deployment
target is iOS 26.

## References

- Apple, [`State.init(wrappedValue:)`](https://developer.apple.com/documentation/swiftui/state/init(wrappedvalue:)):
  "You don't call this initializer directly."
- Apple, [Data Flow Through SwiftUI](https://developer.apple.com/videos/play/wwdc2019/226/)
  (WWDC19), the two fundamental SwiftUI principles, from which all others
  follow: "Every time you read a piece of data in your view, you're creating a
  dependency for that view", and "you should always have a single source of
  truth. Duplicated source of truth can lead to bug and inconsistency."
- Point-Free, [`swiftui-lazy-state`](https://github.com/pointfreeco/swiftui-lazy-state):
  the value lives "at least until the view's identity changes".
- React, [`useMemo`](https://react.dev/reference/react/useMemo): the same
  Memo, a value kept across renders and rebuilt only when a listed dependency
  changes.
- [swift-core-flow](https://github.com/sisoje/swift-core-flow): `MemoView`
  keeps a value across renders and rebuilds it only when its dependencies change.
- [SwiftUI Data Flow Masterclass](https://medium.com/@redhotbits/swiftui-data-flow-masterclass-099f0768f776):
  data enters a node at creation; dependency-tracked invalidation.
