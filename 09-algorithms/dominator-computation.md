# Dominator Computation 🌲

> **One line:** Compute each block's **immediate dominator** (its closest
> strict dominator) by iterating over the blocks in reverse postorder until
> nothing changes (the Cooper–Harvey–Kennedy algorithm). Then derive
> **dominance frontiers**: the join points where a definition's dominance
> ends, which is where SSA needs φs.

## 🌉 From frontend

Think of a funnel report in analytics: "every user who reached checkout
passed through the cart page". The cart page _dominates_ checkout. The
immediate dominator is the last such mandatory page. The dominance frontier
is the first page reachable both with and without passing through it.

## 🖼️ Picture

```
 the counted loop (compiler-mechanics file 05)

   entry(0) ──► header(1) ──► body(2)          idom:  header ← entry
                  ▲  │           │                     body   ← header
                  │  └──► exit(3)│                     exit   ← header
                  └──────────────┘

 dominance frontier DF(n): blocks where n's dominance "runs out"
   DF(body)   = { header }    body dominates a predecessor of header (itself),
                              but not header → a definition in body needs a φ in header
   DF(header) = { header }    the loop header is in its own frontier (back edge)

 reverse postorder (RPO): visit a block only after all its forward predecessors
   → the iterative solver converges in ~2 passes for normal CFGs
```

## 🔧 In each tool

From [codebases/compiler-mechanics-cpp/05_ssa_construction.cpp](../codebases/compiler-mechanics-cpp/05_ssa_construction.cpp).

**Reverse postorder**: a DFS that records blocks after their successors,
then reverses the list:

```cpp
std::vector<int> reversePostOrder(const Function &f) {
  std::vector<bool> visited(f.blocks.size(), false);
  std::vector<int> post;
  postOrderDFS(f, 0, visited, post);
  return std::vector<int>(post.rbegin(), post.rend());
}
```

**The iterative solver.** `intersect` walks two blocks up the (partial)
dominator tree until they meet:

```cpp
int intersect(int a, int b, const std::vector<int> &idom, const std::vector<int> &rpoNum) {
  while (a != b) {
    while (rpoNum[a] > rpoNum[b]) a = idom[a];
    while (rpoNum[b] > rpoNum[a]) b = idom[b];
  }
  return a;
}

std::vector<int> computeIDom(const Function &f) {
  ...
  idom[0] = 0;                               // seed: entry dominates itself
  bool changed = true;
  while (changed) {
    changed = false;
    for (int b : rpo) {
      if (b == 0) continue;
      int newIdom = -1;
      for (int p : f.blocks[b].preds) {
        if (idom[p] == -1) continue;         // predecessor not processed yet
        newIdom = (newIdom == -1) ? p : intersect(p, newIdom, idom, rpoNum);
      }
      if (newIdom != -1 && idom[b] != newIdom) { idom[b] = newIdom; changed = true; }
    }
  }
  return idom;
}
```

**Dominance frontiers**: for each join point, walk up from each
predecessor until reaching the join's immediate dominator:

```cpp
for (int b = 0; b < n; ++b) {
  if (f.blocks[b].preds.size() < 2) continue;   // only join points need φs
  for (int p : f.blocks[b].preds) {
    int runner = p;
    while (runner != idom[b]) {
      df[runner].insert(b);
      runner = idom[runner];
    }
  }
}
```

Checked by the tests: `idom[header] == entry`, `idom[body] == header`,
`idom[exit] == header`, `DF(body) == {header}`, `DF(header) == {header}`.
The real LLVM dominator tree for the same shape of loop is on the
[Dominance](../01-foundations/dominance.md) page.

| Real codebase | Dominators                                                                                                                                                                          |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM          | `llvm/include/llvm/Support/GenericDomTreeConstruction.h`: the **Semi-NCA** algorithm, with incremental updates; `llvm/include/llvm/IR/Dominators.h`; `opt -passes='print<domtree>'` |
| LLVM IDF      | `llvm/include/llvm/Analysis/IteratedDominanceFrontier.h`: iterated frontiers for φ placement                                                                                        |
| MLIR          | `mlir/include/mlir/IR/Dominance.h` (`DominanceInfo`); used by the verifier and by CSE (the `(A) DominanceInfo` line in `--mlir-timing`)                                             |

## 🎤 Interview angle

- "How do you compute dominators?" → iterative data-flow over RPO with the
  `intersect` walk (Cooper–Harvey–Kennedy: simple and fast in practice), or
  Lengauer–Tarjan / Semi-NCA for guaranteed complexity (LLVM uses Semi-NCA).
- "What is a dominance frontier used for?" → exactly where φ nodes go when
  building SSA.
- "Why reverse postorder?" → for forward problems, a block's predecessors
  (except back edges) are processed before it, so facts flow in one sweep.

## ⚠️ Common confusion

- **The file's comment calls Cooper–Harvey–Kennedy "the one LLVM's
  GenericDomTree is modeled on".** Today LLVM's
  `GenericDomTreeConstruction.h` implements Semi-NCA, a different
  algorithm with the same result. Both are worth knowing. CHK is the one to
  write on a whiteboard.
- **Unreachable blocks have no dominator.** Solvers skip them (`idom = -1`).

## 🔗 Related

- [Dominance](../01-foundations/dominance.md)
- [SSA construction](ssa-construction.md)
- [Loops in IR](../01-foundations/loops-in-ir.md)

---

✅ Verified against: compiler-mechanics-cpp `14818a3` (tests pass) · LLVM
source layout checked on GitHub (llvm/llvm-project, 2026-09)
