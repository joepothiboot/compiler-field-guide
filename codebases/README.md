# Codebases 🗂️

Runnable C++ study code, copied into this guide so the explanations and the
code live in one place. The pages in
[08-cpp-for-compilers](../08-cpp-for-compilers/) and
[09-algorithms](../09-algorithms/) walk through this code. This folder is the
source they quote.

| Codebase | What it is | Origin (copied at) |
| -------- | ---------- | ------------------ |
| [compiler-mechanics-cpp](compiler-mechanics-cpp/) | Seven single-file C++17 programs: ownership, dispatch, LLVM-style casting, IR data structures, SSA construction, dataflow analysis, register allocation. Standard library only. | [joepothiboot/compiler-mechanics-cpp](https://github.com/joepothiboot/compiler-mechanics-cpp) @ `14818a3` |
| [llvm-idioms-workbench](llvm-idioms-workbench/) | Three CMake modules that build one expression AST in stages: ownership + `SmallVector` → LLVM-style RTTI → a pass manager with safe in-place rewrites. Compiled with `-fno-rtti -fno-exceptions`. | [joepothiboot/llvm-idioms-workbench](https://github.com/joepothiboot/llvm-idioms-workbench) @ `454c234` (modules 1–3; module 4, an MLIR rewrite pass, is still in progress in the original repo) |

## ▶️ Build and test everything

```bash
./scripts/test-codebases.sh
```

```bash
./scripts/test-codebases.sh --asan
```

Result on this Mac (Apple clang 21, Debug):

```
==> codebases/compiler-mechanics-cpp
100% tests passed out of 8
==> codebases/llvm-idioms-workbench/module1-ast-ownership
100% tests passed out of 1
==> codebases/llvm-idioms-workbench/module2-custom-rtti
100% tests passed out of 1
==> codebases/llvm-idioms-workbench/module3-pass-manager
100% tests passed out of 1
```

With `--asan`, all suites also pass under AddressSanitizer + UndefinedBehaviorSanitizer.

## 🧭 Where each file is explained

| File | Guide page |
| ---- | ---------- |
| `compiler-mechanics-cpp/01_memory_ownership.cpp` | [Ownership and arenas](../08-cpp-for-compilers/ownership-and-arenas.md) |
| `compiler-mechanics-cpp/02_polymorphism.cpp` | [Virtual dispatch and CRTP](../08-cpp-for-compilers/virtual-dispatch-and-crtp.md) |
| `compiler-mechanics-cpp/03_rtti_isa_dyncast.cpp` | [LLVM-style RTTI](../08-cpp-for-compilers/llvm-style-rtti.md) |
| `compiler-mechanics-cpp/04_ir_data_structures.cpp` | [Intrusive lists](../08-cpp-for-compilers/intrusive-lists.md), [Variant ASTs](../08-cpp-for-compilers/variant-asts.md) |
| `compiler-mechanics-cpp/05_ssa_construction.cpp` | [Dominator computation](../09-algorithms/dominator-computation.md), [SSA construction](../09-algorithms/ssa-construction.md) |
| `compiler-mechanics-cpp/06_dataflow_analysis.cpp` | [Dataflow analysis](../09-algorithms/dataflow-analysis.md) |
| `compiler-mechanics-cpp/07_register_allocation.cpp` | [Graph-coloring register allocation](../09-algorithms/graph-coloring-register-allocation.md) |
| `llvm-idioms-workbench/module1-ast-ownership/` | [Ownership and arenas](../08-cpp-for-compilers/ownership-and-arenas.md), [SmallVector and ArrayRef](../08-cpp-for-compilers/small-vector-and-arrayref.md) |
| `llvm-idioms-workbench/module2-custom-rtti/` | [LLVM-style RTTI](../08-cpp-for-compilers/llvm-style-rtti.md) |
| `llvm-idioms-workbench/module3-pass-manager/` | [Owning slots and safe rewrites](../08-cpp-for-compilers/owning-slots-and-safe-rewrites.md) |

## ⚠️ Keeping the copies in sync

These are copies, not submodules, so this repo stays self-contained. If you
change an original repo, refresh the copy:

```bash
rm -rf codebases/compiler-mechanics-cpp && mkdir codebases/compiler-mechanics-cpp && git -C ../../compiler-mechanics-cpp archive HEAD | tar -x -C codebases/compiler-mechanics-cpp
```

Then update the commit in the table above and rerun the tests.
