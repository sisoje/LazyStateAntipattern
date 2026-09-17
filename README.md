# LazyStateTrap

*Elaborate machinery built on a premise SwiftUI already rejects, then more
machinery to manage the consequences — measured.*

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

- "related action" — bumps the input it hands the child
- "unrelated action" — bumps a counter the child never sees

The child shows two lines:

- "model input" — the input its model was built from
- "models created" — counted inside `Model.init`

The script: one unrelated tap, then one related tap. The parent's input ends
at 2. One UI test per scenario runs it and asserts its row:

| child holds the model with | model input | models created |
|---|---|---|
| `@State`, built in `init` | 1 — stale | 3 |
| Point-Free's `@LazyState` | 1 — stale | 1 |
| a Memo keyed by the input | **2** | 2 |

Only the Memo row puts the rebuild under the data flow's control: the listed
dependencies decide. The stale rows can only be repaired by handing control
to the UI runtime — `.id()` resets the whole subtree, `onChange(of:)` patches
state a render late.

Run it: `xcodegen generate`, then the `TrapUITests` in `LazyStateTrap.xcodeproj`.
Needs Xcode 27 (Point-Free's package is swift-tools 6.4); the deployment
target is iOS 26.

## References

- Apple — [`State.init(wrappedValue:)`](https://developer.apple.com/documentation/swiftui/state/init(wrappedvalue:)):
  "You don't call this initializer directly."
- Point-Free — [`swiftui-lazy-state`](https://github.com/pointfreeco/swiftui-lazy-state):
  the value lives "at least until the view's identity changes".
- [swift-core-flow](https://github.com/sisoje/swift-core-flow) — `MemoView`
  as public API; `QueryView` is built on it.
- [SwiftUI Data Flow Masterclass](https://medium.com/@redhotbits/swiftui-data-flow-masterclass-099f0768f776) —
  data enters a node at creation; dependency-tracked invalidation.
