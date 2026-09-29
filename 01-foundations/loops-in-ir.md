# Loops in IR 🔄

> **One line:** At the IR level a loop is a cycle in the CFG: a **header**
> block that decides whether to continue, a **body**, a **latch** that jumps
> back, and one or more **exits**.

## 🌉 From frontend

`for`, `while`, `do/while`, `.forEach` and recursion-turned-loop all look
different in JS. Once lowered to basic blocks, they all become the same
shape. The compiler finds loops by looking for **back edges** in the graph,
not by looking for the `for` keyword.

## 🖼️ Picture

```
            ┌──────────────┐
            │ preheader    │  ← runs once before the loop; a safe place
            │ (entry)      │    to put code hoisted out of the loop
            └──────┬───────┘
                   ▼
            ┌──────────────┐ ◄─────────────┐
            │ header       │               │
            │ i = φ(0,i+1) │               │
            │ i < n ?      │ ── exiting ─┐ │
            └──────┬───────┘             │ │
                   ▼                     │ │ back edge
            ┌──────────────┐             │ │ (latch → header)
            │ body         │             │ │
            └──────┬───────┘             │ │
                   ▼                     │ │
            ┌──────────────┐             │ │
            │ latch        │ ────────────┼─┘
            │ i = i + 1    │             │
            └──────────────┘             ▼
                                  ┌──────────────┐
                                  │ exit         │
                                  └──────────────┘
```

| Part               | Definition                                                          |
| ------------------ | ------------------------------------------------------------------- |
| Header             | The one block every iteration enters through; it dominates the loop |
| Latch              | A block with a back edge to the header                              |
| Back edge          | An edge whose target dominates its source                           |
| Exiting block      | A block inside the loop with an edge leaving it                     |
| Preheader          | The single block outside the loop that jumps to the header          |
| Induction variable | `i`: changes by a fixed step each iteration                         |

## 🔧 In each tool

Real LLVM loop analysis for [samples/vadd.c](../samples/vadd.c)
(`opt -passes='mem2reg,loop-simplify,print<loops>'`):

```
Loop info for function 'vadd':
Loop at depth 1 containing: %5<header><exiting>,%7,%17<latch>
```

`%5` is both the header and the exiting block (the `i < n` test is there),
`%7` is the body, and `%17` is the latch that does `i + 1` and jumps back.

| Tool    | Loop forms                                                                                                                                                    |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM IR | Only the CFG shape above. Passes recover loops with `LoopInfo`, and `loop-simplify` puts them in a standard form                                              |
| MLIR    | **Structured** loops (`scf.for`, `scf.while`, `affine.for`) that keep the loop as one op with a body region, **and** the CFG form after `--convert-scf-to-cf` |
| Triton  | Python `for i in range(...)` inside a kernel becomes `scf.for`. Most parallelism is across programs, not loops                                                |
| Mojo    | `for` / `while` in source; `comptime for` unrolls at compile time (see [comptime](../06-mojo/comptime.md))                                                    |

Why MLIR keeps structured loops: in `scf.for %i = %c0 to %n step %c1`,
the bounds and step are _right there_. Transformations like tiling and
vectorization need exactly that information. In the CFG form the compiler
would first have to rediscover it.

## ⚠️ Common confusion

- **Loop-carried values.** A value computed in one iteration and used in
  the next (a running sum) becomes a φ in the header in LLVM, and
  `iter_args` in `scf.for`. See
  [Reduction in 5 IRs](../rosetta/reduction-in-5-irs.md).
- **Unrolling is not vectorization.** Unrolling copies the body several
  times per iteration. Vectorization makes the body process several
  elements with SIMD instructions. `-O2` often does both.
- **Loop nesting depth** matters for performance work: the innermost loop
  runs the most times, so that is where optimizations focus.

## 🔗 Related

- [Basic block and CFG](basic-block.md)
- [Dominance](dominance.md)
- [Tiling](../03-transformations/tiling.md)
- [Vectorization](../03-transformations/vectorization.md)

---

✅ Verified against: LLVM/MLIR 23.1.1
