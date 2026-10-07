# Dataflow Analysis 🌊

> **One line:** A dataflow analysis computes a fact per program point (which
> variables are live, which definitions reach here) by defining a
> **transfer function** per block and a **meet** at join points, then
> iterating with a worklist until nothing changes (a _fixpoint_).
> Termination is guaranteed because facts only grow and there are finitely
> many of them.

## 🖼️ Picture

```
                      direction   meet    facts                used by
                      ─────────   ────    ─────                ───────
 LIVE VARIABLES       backward    ∪       variables            DCE, REGISTER ALLOCATION
 REACHING DEFS        forward     ∪       definition sites     constant propagation, def-use chains

 LIVENESS equations                        REACHING DEFINITIONS equations
   OUT(B) = ∪ IN(S)  over successors S       IN(B)  = ∪ OUT(P)  over predecessors P
   IN(B)  = USE(B) ∪ (OUT(B) − DEF(B))       OUT(B) = GEN(B) ∪ (IN(B) − KILL(B))

 USE(B) = UPWARD-EXPOSED uses only: read in B before B writes them
          `s = s + i` uses s;   `s = 0; x = s` does NOT make s live-in

 facts as BITVECTORS: meet = one machine-word OR per 64 facts
```

## 🔧 In each tool

From [codebases/compiler-mechanics-cpp/06_dataflow_analysis.cpp](../codebases/compiler-mechanics-cpp/06_dataflow_analysis.cpp),
on the same counted loop as the SSA page:

```
B0: i = 0; s = 0                -> B1
B1: t = i < n; br t             -> B2, B3
B2: s = s + i; i = i + 1        -> B1
B3: ret s
```

**Liveness worklist** (backward: when `IN(B)` changes, requeue the predecessors):

```cpp
while (!worklist.empty()) {
  int b = worklist.front(); worklist.pop_front();
  BitVec newOut(v);
  for (int s : cfg.blocks[b].succs) newOut.unionWith(res.in[s]);
  BitVec newIn = newOut;
  newIn.subtract(def[b]);
  newIn.unionWith(use[b]);
  res.out[b] = newOut;
  if (!(newIn == res.in[b])) {
    res.in[b] = newIn;
    for (int p : cfg.blocks[b].preds) worklist.push_back(p);
  }
}
```

The hand-verified fixpoint the tests check:

| Block | live-in | live-out |
| ----- | ------- | -------- |
| B0    | `n`     | `i n s`  |
| B1    | `i n s` | `i n s`  |
| B2    | `i n s` | `i n s`  |
| B3    | `s`     | ∅        |

Real output: `live-in(B1) = i n s`. Note that `t` is **never live-out** of
any block: it is consumed by the branch in its own block. That is why a
register allocator can keep it in a scratch register, and why SSA
construction placed a φ for `t` that turned out to be dead.

**Reaching definitions**, with definitions numbered
`d0: i@B0  d1: s@B0  d2: t@B1  d3: s@B2  d4: i@B2`:

- `IN(B1) = {d0, d1, d2, d3, d4}`: the back edge merges the entry and
  loop-body definitions.
- `OUT(B2) = {d2, d3, d4}`: `d0` and `d1` are killed by `d4` and `d3`.
- The use of `s` in `B3` has **two** reaching definitions (`d1` and `d3`),
  so naive constant propagation cannot replace it. In SSA, that use reads a
  single φ instead. SSA makes this analysis unnecessary.

| Real codebase | Dataflow                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM (IR)     | Most IR analyses rely on SSA instead of classic bitvector dataflow; `LiveIntervals` (`llvm/lib/CodeGen/LiveIntervals.cpp`) computes liveness for machine code |
| MLIR          | `mlir/Analysis/DataFlow/`: a generic sparse/dense dataflow framework (dead code analysis, constant propagation, integer range analysis)                       |
| Everywhere    | The worklist + fixpoint shape also drives MLIR's greedy pattern driver ([Pattern rewrite](../03-transformations/pattern-rewrite.md))                          |

## 🎤 Interview angle

- "Define liveness." → `v` is live at point `p` if some path from `p`
  reaches a use of `v` without passing a redefinition. Backward, meet = union.
- "Why does it terminate?" → finite lattice (subsets of variables), monotone
  transfer functions: sets only grow, so after finitely many changes nothing changes.
- "Why is order important?" → reverse postorder (forward) or postorder
  (backward) reaches the fixpoint in fewer passes. A plain worklist converges
  to the same answer, just possibly slower.
- "How does SSA simplify this?" → each use has exactly one reaching
  definition by construction, so def-use chains come for free.

## ⚠️ Common confusion

- **Upward-exposed uses.** Counting every use in `USE(B)` makes too many
  variables live. Only reads before a write in the same block count.
- **May vs must.** Liveness and reaching definitions are _may_ analyses
  (union). "Available expressions" is a _must_ analysis (intersection), used
  for CSE.

## 🔗 Related

- [Graph-coloring register allocation](graph-coloring-register-allocation.md): consumes liveness
- [SSA construction](ssa-construction.md)
- [Use-def chains](../01-foundations/use-def-chains.md)

---

✅ Verified against: compiler-mechanics-cpp `14818a3` (tests pass; output above
is real)
