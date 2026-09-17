# A model built from an input: `@State`, `@LazyState`, and a Memo

One screen, one test script, three ways to hold the model, three results.

```
[related action]        changes the input the child receives
parent input 1
[unrelated action]      re-renders the parent, nothing else
unrelated counter 0
──────────────────
model input 1           the input the child's model was built from
models created 1        counted inside Model.init
```

The script: one unrelated tap, then one related tap. The parent's input ends
at 2.

| child holds the model with | model input | models created |
|---|---|---|
| `@State`, built in `init` | 1 — stale | 3 |
| Point-Free's `@LazyState` | 1 — stale | 1 |
| a Memo keyed by the input | **2** | 2 |

Run it: `xcodegen generate`, then `ComparisonUITests` — three tests, the same
steps, each asserting its own row. Needs Xcode 27 (Point-Free's package is
swift-tools 6.4); the deployment target is iOS 26.

`App/` is one file per scenario, each ending in its `#Preview`:
`StateScenario.swift`, `LazyStateScenario.swift`, `MemoScenario.swift`, over
the shared `Parent.swift` and `Model.swift`.

## The problem

A parent owns a value and hands it to a child. The child needs an
`@Observable` model built from that value: `Model(input: input)`.

Two requirements follow, and both must hold:

1. **The model follows the input.** When the parent's value changes, the
   child shows a model built from the new value.
2. **The model is kept otherwise.** A parent re-render that does not change
   the input builds nothing and keeps the same instance.

The model cannot be a stored property with an initializer — `input` does not
exist yet. So it has to be built somewhere else.

## The naive solution: `@State` in `init`

```swift
@State private var model: Model

init(input: Int) {
    _model = State(wrappedValue: Model(input: input))
}
```

It fails both requirements.

`Model(input:)` is an ordinary argument, evaluated every time the parent's
`body` builds this child: launch, the unrelated tap, the related tap — three
models. `@State` keeps the first and discards the rest. Requirement 2 fails.

And the one it keeps is the first one. After the related tap the parent holds
2 and the model still says 1. Requirement 1 fails — silently, with no warning
and no error.

None of this is a flaw in `@State`. It is `@State` used against its
documentation. Apple's page for
[`State.init(wrappedValue:)`](https://developer.apple.com/documentation/swiftui/state/init(wrappedvalue:))
opens with "You don't call this initializer directly", and the
[`State`](https://developer.apple.com/documentation/swiftui/state) overview
says to keep state private so it cannot be set from an initializer, to use it
only for storage local to the view, and that its storage is initialised once
per view instance. State is the view's *own* truth. A value that arrives from
the parent is not the view's own, and seeding state from it is the misuse —
the wasted allocations and the stale model are what that misuse looks like.

## Point-Free's solution: `@LazyState`

*A careful answer to a question that should not have been asked.*

```swift
@LazyState private var model: Model

init(input: Int) {
    _model = LazyState { Model(input: input) }
}
```

[`@LazyState`](https://github.com/pointfreeco/swiftui-lazy-state) wraps the
creation in a closure that runs once. Three creations become one: requirement
2 is met, and that improvement is real and measured above.

Requirement 1 is untouched. The model is still built from the first input and
never again — their README says the value lives "at least until the view's
identity changes". After the related tap the screen shows a model for a value
the parent no longer holds, exactly as under `@State`.

So `@LazyState` fixes a problem that exists only once Apple's rule is broken.
The pattern it makes convenient is the one Apple documents as not to be
written; followed as documented, `@State` never allocates a discarded model,
because it is never handed one from an `init`.

**It solves the visible half of the problem and keeps the silent half.** The
discarded allocations were a symptom of a pattern — state initialised from a
parameter — whose real defect is staleness. Making the pattern cheaper makes
it more attractive, and it is still wrong the moment the input changes. What
remains is the old repair kit, and their README names it: `onChange(of:)`,
`task(id:)`, or changing the view's identity — a rebuild by hand, or
`.id(input)`, which does rebuild, by destroying the child and every piece of
state under it.

### The flaw in the argument

The case for `@LazyState` runs: building a model in `init` with `@State` is
wasteful; here is a way to do it without the waste; therefore do it this way.
The premise nobody examines is the first clause — that the model should be
built in `init` and held as state at all. Apple says it should not. The
argument improves a thing it never shows to be right, and an improved wrong
answer is still wrong: the model is stale under `@LazyState` exactly as under
`@State`. It is the XY problem — asking how to repair the attempted solution
instead of asking what the problem was. **The problem was never "my state
initialiser runs too often". It was "this value depends on an input".**

## The correct solution: a Memo keyed by the input

The question is not "how do I build this once?" but "**when must it be
rebuilt?**" The expression answers it: when a value it reads changes. React
has had the primitive for years —
[`useMemo(calculate, dependencies)`](https://react.dev/reference/react/useMemo).
`App/MemoView.swift` is that, as a SwiftUI view, in about forty lines:

```swift
let input: Int

var body: some View {
    MemoView(Model(input: input), dependencies: [input]) { model in
        ModelRow(model: model)
    }
}
```

A plain class kept in `@State` stores the last dependencies and the value
built from them. Same dependencies: the stored value comes back and nothing
is built — the unrelated tap costs nothing. Different: the expression runs
once. Two creations for two inputs, and the model on screen is the one for
the input the parent holds. Both requirements hold, and the subtree keeps its
identity and its state.

A Memo does not make the discouraged pattern nicer; it replaces it. Nothing
is seeded into state, so there is no rule to break and nothing to go stale.

**It is the only one of the three that follows the data flow.** Data flows
down from the parent; a value derived from it must be re-derived when it
changes and left alone when it does not. `@State` and `@LazyState` cut the
flow at the first render — whatever arrives later is ignored. The Memo keeps
it connected: the dependencies are the flow, written down. That is why it is
correct and the other two are not — it is the only one that knows what the
model depends on. The cost is that the caller says so: the dependencies are
listed by hand, and a value left out is a change the Memo will not follow —
the contract of `task(id:)` and `onChange(of:)`, written next to the
expression it describes.

## A note on the counter

`Model.creations` counts inside `Model.init` and the row displays it. Two
things about it were found the hard way, and both are this example's subject
in miniature.

It has to be observable. A plain `static var` froze the `@State` row at
`models created 1` while three models had been built: the kept model is the
same instance on every render, so `ModelRow` compares equal and SwiftUI skips
its body — nothing re-reads the static. The other two scenarios hid the bug.

And it has to be written without being read. The first version was
`count += 1` — a read, then a write — and it hung the `@State` scenario: the
model is created inside the parent's `body`, the read subscribed the parent
to the counter, the write re-rendered it, forever. One more thing that goes
wrong when models are built in `init` during someone else's render.

## References

- React — [`useMemo`](https://react.dev/reference/react/useMemo): cache a
  calculation between renders, recomputed when a listed dependency changes.
  The Memo pattern this example applies to SwiftUI; same word, same argument
  order, same contract.
- Apple — [`State`](https://developer.apple.com/documentation/swiftui/state)
  and [`State.init(wrappedValue:)`](https://developer.apple.com/documentation/swiftui/state/init(wrappedvalue:)):
  state is private, local to the view, initialised once, and not set from an
  initializer.
- Point-Free — [`@LazyState`](https://github.com/pointfreeco/swiftui-lazy-state)
  and the [announcement](https://www.pointfree.co/blog/posts/228-lazystate-1-0-now-available-to-everyone).
- Lazar Otasevic — [SwiftUI Data Flow Masterclass](https://medium.com/@redhotbits/swiftui-data-flow-masterclass-099f0768f776):
  data enters a node at creation; dependency-tracked invalidation.

---

`MemoView` here is inlined from
[swift-core-flow](https://github.com/sisoje/swift-core-flow), where it is
public API and `QueryView` is built on it.
