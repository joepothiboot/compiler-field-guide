# Interview Guide 🎤

Preparation for compiler and ML-systems interviews, with a focus on the
**Mojo Libraries Engineer** role. Every answer links back to the guide page
with the full explanation and real output, so you can go from "I can say
it" to "I can show it".

## 🗂️ What's here

| Page                                                                                     | Use it for                                                                       |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| [question-bank-cpp.md](question-bank-cpp.md)                                             | C++ for compilers: ownership, dispatch, RTTI, containers                         |
| [question-bank-ir-and-mlir.md](question-bank-ir-and-mlir.md)                             | SSA, CFG, dominance, dialects, ops, lowering                                     |
| [question-bank-optimizations-and-codegen.md](question-bank-optimizations-and-codegen.md) | Passes, folding, CSE, fusion, tiling, vectorization, isel, regalloc              |
| [question-bank-gpu-and-ml-compilers.md](question-bank-gpu-and-ml-compilers.md)           | GPU execution model, memory, Triton, `torch.compile`, tensor cores               |
| [question-bank-mojo.md](question-bank-mojo.md)                                           | Mojo language and library design (role-specific)                                 |
| [coding-exercises.md](coding-exercises.md)                                               | Whiteboard / live-coding problems, with solutions in `codebases/` and `samples/` |
| [talking-about-your-projects.md](talking-about-your-projects.md)                         | Short, honest, number-backed project stories                                     |

## 🧠 How to use the question banks

Each question has a **model answer hidden in a fold**. Answer out loud
first, then open it:

```
<details><summary>Answer</summary> ... </details>
```

A good compiler interview answer has three layers. Aim for all three:

```
 1. DEFINITION     one sentence, precise              "SSA: every value is assigned once."
 2. MECHANISM      how it works / why it exists        "φ at joins; built via dominance frontiers."
 3. EVIDENCE       something you ran or wrote          "In my mechanics repo, an interpreter checks
                                                        the SSA form gives the same results."
```

The third layer is what this guide gives you: every page has real output
you produced on your own machine.

## 📅 An 8-week plan

| Week | Read                                                                                      | Do                                                                             | Can explain                                          |
| ---- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------- |
| 1    | [00-bridge](../00-bridge/), [maps](../maps/)                                              | Run `scripts/regen.sh`                                                         | The whole stack in 2 minutes                         |
| 2    | [01-foundations](../01-foundations/), [09 dominators + SSA](../09-algorithms/)            | Break `bad_dominance.mlir`, then fix it with a block argument                  | SSA, φ, dominance, mem2reg                           |
| 3    | [08-cpp-for-compilers](../08-cpp-for-compilers/)                                          | `scripts/test-codebases.sh --asan`; re-implement `dyn_cast` from memory        | Ownership, `isa`/`cast`/`dyn_cast`, CRTP             |
| 4    | [02-ir-design](../02-ir-design/), [03-transformations](../03-transformations/)            | Write a folding pattern in nano-dsp-mlir                                       | Dialects, patterns, canonicalize vs CSE              |
| 5    | [09 dataflow + regalloc](../09-algorithms/), [07-codegen-runtime](../07-codegen-runtime/) | Read `llc -stop-after` MIR for your own function                               | Liveness, interference, isel, ABI                    |
| 6    | [04-hardware](../04-hardware/)                                                            | Rerun `cache_walk.mojo` and `matmul_cpu.mojo`; explain every number            | Cache, SIMD, GPU hierarchy, coalescing               |
| 7    | [05-ml-compilers](../05-ml-compilers/), [06-mojo](../06-mojo/)                            | Write a new Mojo SIMD kernel with a benchmark and test                         | Fusion, autotuning, Mojo parameters/traits/ownership |
| 8    | This folder, [real-world](../real-world/)                                                 | Mock interviews using the question banks; read `simd.mojo` in the Modular repo | Your projects, in numbers                            |

## 🎯 What a Mojo Libraries Engineer interview is likely to probe

Based on the role's focus (generic, SIMD-heavy, well-tested, benchmarked
library code):

- **Generic programming**: parameters, traits, specialization, compile-time
  evaluation ([06-mojo](../06-mojo/))
- **Performance reasoning**: memory hierarchy, SIMD width, measuring
  correctly ([04-hardware](../04-hardware/),
  [matmul page](../rosetta/matmul-naive-tiled-fused.md))
- **Correctness habits**: bit-exact tests against a reference, NaN
  semantics, float reassociation ([reduction page](../rosetta/reduction-in-5-irs.md))
- **API design**: ownership conventions, when to copy, views vs owners
  ([ownership](../06-mojo/ownership-and-transfer.md), [ArrayRef](../08-cpp-for-compilers/small-vector-and-arrayref.md))
- **Compiler awareness**: how your Mojo becomes MLIR, LLVM IR and machine code
  ([where each tool sits](../maps/where-each-tool-sits.md))
