# Compiler Algorithms by Hand 🧮

Classic compiler algorithms, implemented and tested in [codebases/compiler-mechanics-cpp](../codebases/compiler-mechanics-cpp/), explained step by step.

| Page | In one line |
| ---- | ----------- |
| [Dominator Computation 🌲](dominator-computation.md) | Compute each block's immediate dominator (its closest strict dominator) by iterating over the blocks in reverse postorder until nothing changes (the Cooper–Harvey–Kennedy algorithm). |
| [SSA Construction 🏗️](ssa-construction.md) | Converting a program with reassigned variables into SSA takes three steps: place φ nodes at the iterated dominance frontier of each variable's definitions, rename every definition and use by walking the dominator tree with a stack per variable, then delete dead φs. |
| [Dataflow Analysis 🌊](dataflow-analysis.md) | A dataflow analysis computes a fact per program point (which variables are live, which definitions reach here) by defining a transfer function per block and a meet at join points, then iterating with a worklist until nothing changes (a _fixpoint_). |
| [Graph-Coloring Register Allocation 🎨](graph-coloring-register-allocation.md) | Build an interference graph (an edge between two values that are live at the same time), then color it with K colors = K registers, using the Chaitin–Briggs heuristic: simplify (remove nodes of degree < K), spill optimistically when stuck, then select colors in reverse order. |

New pages start from [../_templates/term.md](../_templates/term.md).
