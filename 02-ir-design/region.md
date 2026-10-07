# Region 🪆

> **One line:** A region is a list of blocks nested _inside_ an op. It is how
> MLIR represents a function body, a loop body or the branches of an `if`
> while keeping the structure visible.

## 🖼️ Picture

```
 builtin.module ─────────────── region 0
 └─ func.func @vadd ─────────── region 0
    └─ block ^bb0(%a, %b, %c)
       ├─ arith.constant
       ├─ memref.dim
       ├─ scf.for ───────────── region 0  (the loop body)
       │  └─ block ^bb0(%i)            ← loop variable = block argument
       │     ├─ memref.load
       │     ├─ arith.addf
       │     ├─ memref.store
       │     └─ scf.yield              ← terminator of the region's block
       └─ func.return

 scf.if has TWO regions:              op → regions → blocks → ops → regions → ...
   region 0: then { scf.yield %x }    (the nesting can go as deep as needed)
   region 1: else { scf.yield %0 }
```

## 🔧 In each tool

Visibility rule: code inside a region can use values defined **above** it
(the loop body uses `%a` from the function), as long as those definitions
dominate the op. Values defined inside the region cannot leak out, except
through the terminator (`scf.yield %x` becomes the result of the `scf.if`).

Some ops are **IsolatedFromAbove**: nothing from outside is visible. For
example `func.func`: a function body cannot use another function's
values. This isolation also lets MLIR run passes on different functions
**in parallel**.

| Tool    | Nesting                                                                                                       |
| ------- | ------------------------------------------------------------------------------------------------------------- |
| LLVM IR | None: a function is a flat list of blocks. Loops and `if`s exist only as CFG shapes                           |
| MLIR    | Regions at any depth. Converting `scf` → `cf` _flattens_ regions into plain blocks                            |
| Triton  | `scf.for` / `scf.if` regions in Triton IR; `tt.reduce` has a region holding the combine function (e.g. `add`) |
| Mojo    | Not visible; source-level blocks lower into regions internally                                                |

Real example of flattening, from the [dialect](dialect.md) page: the
`scf.if` with two regions becomes four plain blocks after
`--convert-scf-to-cf`.

## ⚠️ Common confusion

- **Region vs block.** A region _contains_ blocks. Most regions have one
  block (loop bodies, `if` branches). A function body region can have many
  blocks after lowering to `cf`.
- **Region vs scope.** Similar idea, but a region is a real object in the
  IR that passes can move, clone or inline.
- **Graph regions** (rare): some ops declare regions where SSA dominance is
  not required, for example to model hardware netlists. Everything in this
  guide uses normal SSA regions.

## 🔗 Related

- [Operation](operation.md)
- [Dominance](../01-foundations/dominance.md)
- [Loops in IR](../01-foundations/loops-in-ir.md)

---

✅ Verified against: MLIR 23.1.1
