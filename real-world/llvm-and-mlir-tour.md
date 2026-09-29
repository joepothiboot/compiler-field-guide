# LLVM and MLIR Codebase Tour 🐉

> **Where the ideas in this guide live in `llvm/llvm-project`.** Every path
> below was checked against the GitHub repository in September 2026. The
> repo is large (millions of lines), so use this page as a map: find the
> concept, open the file, and read the top-of-file comment first.

## 🗺️ The top level

```
llvm-project/
├── llvm/            the LLVM IR, optimizer and backends
│   ├── include/llvm/ADT/        containers: SmallVector, ArrayRef, DenseMap, ilist ...
│   ├── include/llvm/Support/    Casting.h, Allocator.h, Error.h, raw_ostream ...
│   ├── include/llvm/IR/         Value, Instruction, BasicBlock, Function, PassManager ...
│   ├── lib/Transforms/          IR optimizations (Scalar/, Utils/, Vectorize/, InstCombine/)
│   ├── lib/CodeGen/             instruction selection, register allocation, machine passes
│   └── lib/Target/<Arch>/       one backend per target: AArch64, X86, NVPTX, AMDGPU ...
├── mlir/            the MLIR framework and upstream dialects
│   ├── include/mlir/IR/         Operation, Block, Region, Builders, PatternMatch, OpBase.td
│   ├── lib/Transforms/          canonicalize, CSE, inliner, pattern drivers
│   ├── lib/Dialect/<Name>/      one folder per dialect (Arith, SCF, Linalg, GPU ...)
│   ├── lib/Conversion/          one folder per lowering (SCFToControlFlow ...)
│   └── examples/toy/            the official tutorial compiler, chapter by chapter
└── clang/           the C/C++ front end
```

## 🔎 Concept → file

| Concept (guide page)                                                             | File in `llvm/llvm-project`                                                                                                                                                                                        |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [LLVM-style RTTI](../08-cpp-for-compilers/llvm-style-rtti.md)                    | `llvm/include/llvm/Support/Casting.h`; kind ranges in `llvm/include/llvm/IR/Value.def`, `Instruction.def`                                                                                                          |
| [SmallVector and ArrayRef](../08-cpp-for-compilers/small-vector-and-arrayref.md) | `llvm/include/llvm/ADT/SmallVector.h`, `ArrayRef.h`                                                                                                                                                                |
| [Intrusive lists](../08-cpp-for-compilers/intrusive-lists.md)                    | `llvm/include/llvm/ADT/ilist.h`                                                                                                                                                                                    |
| [Arenas](../08-cpp-for-compilers/ownership-and-arenas.md)                        | `llvm/include/llvm/Support/Allocator.h` (`BumpPtrAllocator`); `mlir/include/mlir/IR/MLIRContext.h`                                                                                                                 |
| [CRTP visitors](../08-cpp-for-compilers/virtual-dispatch-and-crtp.md)            | `llvm/include/llvm/IR/InstVisitor.h`; `PassInfoMixin` in `llvm/include/llvm/IR/PassManager.h`                                                                                                                      |
| [Dominators](../09-algorithms/dominator-computation.md)                          | `llvm/include/llvm/Support/GenericDomTreeConstruction.h` (Semi-NCA), `llvm/include/llvm/IR/Dominators.h`, `mlir/include/mlir/IR/Dominance.h`                                                                       |
| [SSA construction](../09-algorithms/ssa-construction.md)                         | `llvm/lib/Transforms/Utils/PromoteMemoryToRegister.cpp` (mem2reg), `llvm/include/llvm/Analysis/IteratedDominanceFrontier.h`, `llvm/lib/Transforms/Utils/SSAUpdater.cpp`, `mlir/lib/Transforms/Mem2Reg.cpp`         |
| [Loops](../01-foundations/loops-in-ir.md)                                        | `llvm/lib/Analysis/LoopInfo.cpp`                                                                                                                                                                                   |
| [Dataflow](../09-algorithms/dataflow-analysis.md)                                | `mlir/include/mlir/Analysis/DataFlow/` (LivenessAnalysis.h, DeadCodeAnalysis.h, IntegerRangeAnalysis.h ...)                                                                                                        |
| [CSE and DCE](../03-transformations/cse-and-dce.md)                              | `llvm/lib/Transforms/Scalar/EarlyCSE.cpp`, `GVN.cpp`; `mlir/lib/Transforms/CSE.cpp`                                                                                                                                |
| [Canonicalization](../03-transformations/canonicalization-and-folding.md)        | `llvm/lib/Transforms/InstCombine/`; `mlir/lib/Transforms/Canonicalizer.cpp`; folders in e.g. `mlir/lib/Dialect/Arith/IR/ArithOps.cpp`                                                                              |
| [Pattern rewrite](../03-transformations/pattern-rewrite.md)                      | `mlir/include/mlir/IR/PatternMatch.h`, `mlir/lib/Transforms/Utils/GreedyPatternRewriteDriver.cpp`                                                                                                                  |
| [Legalization](../02-ir-design/legalization.md)                                  | `mlir/include/mlir/Transforms/DialectConversion.h`, `mlir/lib/Transforms/Utils/DialectConversion.cpp`                                                                                                              |
| [Pass manager](../03-transformations/pass-and-pass-manager.md)                   | `llvm/include/llvm/IR/PassManager.h`; `mlir/lib/Pass/Pass.cpp`, `PassTiming.cpp`, `IRPrinting.cpp`                                                                                                                 |
| [ODS](../02-ir-design/ods-and-tablegen.md)                                       | `mlir/include/mlir/IR/OpBase.td`; a real dialect: `mlir/include/mlir/Dialect/Arith/IR/ArithOps.td`                                                                                                                 |
| [Dialect lowering](../02-ir-design/dialect.md)                                   | `mlir/lib/Conversion/SCFToControlFlow/SCFToControlFlow.cpp`                                                                                                                                                        |
| [Fusion](../03-transformations/fusion.md)                                        | `mlir/lib/Dialect/Linalg/Transforms/ElementwiseOpFusion.cpp`                                                                                                                                                       |
| [Bufferization](../03-transformations/bufferization.md)                          | `mlir/lib/Dialect/Bufferization/Transforms/OneShotAnalysis.cpp`                                                                                                                                                    |
| [Vectorization](../03-transformations/vectorization.md)                          | `llvm/lib/Transforms/Vectorize/LoopVectorize.cpp`, `SLPVectorizer.cpp`                                                                                                                                             |
| [Instruction selection](../07-codegen-runtime/instruction-selection.md)          | `llvm/lib/CodeGen/SelectionDAG/SelectionDAGISel.cpp`, `llvm/lib/CodeGen/GlobalISel/`, patterns in `llvm/lib/Target/AArch64/AArch64InstrInfo.td`; `llvm/lib/CodeGen/MachineCombiner.cpp` (the `neg`+`madd` rewrite) |
| [Register allocation](../07-codegen-runtime/register-allocation.md)              | `llvm/lib/CodeGen/RegAllocGreedy.cpp`, `RegAllocFast.cpp`, `RegAllocBasic.cpp`, `LiveIntervals.cpp`                                                                                                                |
| [PTX](../07-codegen-runtime/ptx-ptxas-and-sass.md)                               | `llvm/lib/Target/NVPTX/`; MLIR's GPU pipeline: `mlir/lib/Dialect/GPU/Pipelines/GPUToNVVMPipeline.cpp`                                                                                                              |
| [JIT](../07-codegen-runtime/jit-vs-aot.md)                                       | `llvm/lib/ExecutionEngine/Orc/`                                                                                                                                                                                    |

## 📖 How to read it

1. **Start with a pass you already ran.** For example, `mlir-opt
--canonicalize` → `mlir/lib/Transforms/Canonicalizer.cpp` is short and
   shows how a pass collects patterns and calls the greedy driver.
2. **Follow the tests, not just the code.** Every pass has lit tests under
   `llvm/test/` or `mlir/test/`: `.ll`/`.mlir` input plus `// CHECK:` lines
   with the expected output. They are the best documentation of what a pass
   actually does.
3. **Toy tutorial.** `mlir/examples/toy/Ch1` … `Ch7` builds a language step
   by step: AST → a custom dialect → canonicalization → lowering to affine →
   LLVM. It is the upstream version of what nano-dsp-mlir does.

## 🔗 Related

- [LLVM coding conventions](../08-cpp-for-compilers/llvm-coding-conventions.md)
- [Where each tool sits](../maps/where-each-tool-sits.md)

---

✅ Paths verified on GitHub (`llvm/llvm-project`, default branch, 2026-09)
