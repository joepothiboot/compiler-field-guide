# Graph-Coloring Register Allocation 🎨

> **One line:** Build an **interference graph** (an edge between two values
> that are live at the same time), then color it with K colors = K
> registers, using the Chaitin–Briggs heuristic: **simplify** (remove nodes
> of degree < K), **spill** optimistically when stuck, then **select** colors
> in reverse order.

## 🖼️ Picture

```
 SIMPLIFY: repeatedly remove a node with degree < K, push it on a stack
           (whatever its neighbors get, < K of them → a color is left for it)
 SPILL:    all remaining nodes have degree >= K → push one OPTIMISTICALLY
           (Briggs: its neighbors might share colors, so it may still fit)
 SELECT:   pop each node, give it the lowest color its colored neighbors don't use;
           no color left → a REAL spill (store it in memory, rewrite, retry)

 4-cycle, K = 2 — where Briggs beats Chaitin:
     n0 ── n1           every node has degree 2 = K → simplify is stuck at once
     │      │           Chaitin: spill.   Briggs: push n0 optimistically, continue
     n3 ── n2           result: n0,n2 = color 0; n1,n3 = color 1 — NO spill
```

## 🔧 In each tool

From [codebases/compiler-mechanics-cpp/07_register_allocation.cpp](../codebases/compiler-mechanics-cpp/07_register_allocation.cpp).

**Simplify / optimistic spill:**

```cpp
while (remaining > 0) {
  int pick = -1;
  for (int i = 0; i < n; ++i)                                     // an easy node?
    if (!removed[i] && g.preColor[i] < 0 && degree[i] < K) { pick = i; break; }
  if (pick == -1) {                                               // stuck: optimistic spill
    for (int i = 0; i < n; ++i)
      if (!removed[i] && g.preColor[i] < 0 && (pick == -1 || degree[i] > degree[pick]))
        pick = i;                                                 // highest degree relieves most
  }
  removed[pick] = true;
  stack.push_back(pick);
  --remaining;
  for (int nb : g.adj[pick]) if (!removed[nb]) --degree[nb];
}
```

**Select:**

```cpp
while (!stack.empty()) {
  int v = stack.back(); stack.pop_back();
  std::vector<bool> taken(K, false);
  for (int nb : g.adj[v]) { int c = result.color[nb]; if (c >= 0 && c < K) taken[c] = true; }
  int chosen = -1;
  for (int c = 0; c < K; ++c) if (!taken[c]) { chosen = c; break; }
  if (chosen == -1) result.spilled[v] = true;       // optimism did not pay off
  else result.color[v] = chosen;
}
```

**Where the graph comes from**: live ranges. Two values interfere when their
intervals overlap:

```
   0: a = ...          a live [0,4)          a ── b
   1: b = ...          b live [1,3)          │  ╱
   2: c = a + b        c live [2,6)          c ── d
   5: d = c * 2        d live [5,8)
   max pressure = 3 at point 2 (a, b, c)
```

Real output: `K=3 -> 3 colors, 0 spills; K=2 -> 1 spills`.

The five tests cover: a colorable graph, a forced spill (a triangle with
K = 2), **Briggs' optimism** (the 4-cycle), a **precolored** physical
register (`%eax` pinned to color 0; its neighbor is forced to color 1, and a
non-neighbor may reuse color 0), and the live-range builder. A `verify()`
function checks the key property after every allocation: no two interfering
values share a register.

| Real codebase | Allocator                                                                                                                                                                                      |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM          | **Greedy** (`llvm/lib/CodeGen/RegAllocGreedy.cpp`): priority-based, splits live ranges instead of spilling whole ranges; **Basic** (`RegAllocBasic.cpp`); **Fast** (`RegAllocFast.cpp`, `-O0`) |
| LLVM output   | Real before/after MIR on the [Register allocation](../07-codegen-runtime/register-allocation.md) page                                                                                          |
| NVIDIA        | Done by `ptxas`; the result determines [occupancy](../04-hardware/occupancy.md)                                                                                                                |
| JITs          | Often **linear scan**: one pass over sorted live intervals, faster but less optimal                                                                                                            |

## 🎤 Interview angle

- "Is register allocation NP-complete?" → graph coloring is. Compilers use
  heuristics (Chaitin–Briggs) or other formulations (linear scan, LLVM greedy).
- "Why remove degree < K first?" → such a node can always be colored at the
  end, so it can safely be set aside.
- "What does Briggs add over Chaitin?" → optimistic spilling: push the node
  anyway, and only spill if no color is actually free at select time. The
  4-cycle test is the proof.
- "How do you choose what to spill?" → by spill cost: use frequency
  weighted by loop depth, divided by degree. Loop-carried values are
  spilled last.

## ⚠️ Common confusion

- **Precolored nodes are never simplified or spilled.** They model fixed
  registers (ABI argument registers, x86 `div` writing `EAX:EDX`) and just
  occupy a color for their neighbors.
- **LLVM does not use pure graph coloring.** The vocabulary (interference,
  spill, live range) is the same, and it is what interviews ask about.

## 🔗 Related

- [Register allocation (LLVM, real MIR)](../07-codegen-runtime/register-allocation.md)
- [Dataflow analysis](dataflow-analysis.md): liveness builds the graph
- [ABI and calling conventions](../07-codegen-runtime/abi-and-calling-conventions.md): precolored registers

---

✅ Verified against: compiler-mechanics-cpp `14818a3` (tests pass; output above
is real)
