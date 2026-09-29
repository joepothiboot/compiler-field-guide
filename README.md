# compiler-field-guide 🧭

A single place to learn compilers, from the vocabulary of MLIR and LLVM up
to Triton, PyTorch and Mojo. It is written for someone coming from frontend
and general software engineering.

The guide is organized **by concept, not by tool**. Each term gets one page,
and that page shows how LLVM, MLIR, Triton and Mojo each handle it. You should
not need to open four projects' docs to understand one idea.

**Everything is real.** Every IR listing, assembly dump, error message and
benchmark number on these pages was produced on this machine, from the
inputs in [samples/](samples/) and the code in [codebases/](codebases/). Pages
say so when something could not be run here (Triton, SASS, the Mac GPU).

## 🗺️ Where to start

1. **[maps/the-whole-stack.md](maps/the-whole-stack.md)**: one diagram from
   Python to machine code, and where each tool sits.
2. **[00-bridge/](00-bridge/)**: Babel, ASTs, bundler plugins, TypeScript
   types and V8 tiers, mapped onto compiler ideas.
3. **[01-foundations/](01-foundations/)**: basic blocks, SSA, dominance, loops.
4. **[rosetta/vector-add-in-5-irs.md](rosetta/vector-add-in-5-irs.md)**: one
   program in five IRs, to connect the vocabulary.
5. Then any chapter. **[GLOSSARY.md](GLOSSARY.md)** is the A–Z index, and
   **[interview/](interview/)** has a week-by-week plan.

## 📚 Contents

| Folder                                        | Covers                                                                                                                    | Pages |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ----- |
| [00-bridge](00-bridge/)                       | FE/SWE ideas mapped to compiler ideas                                                                                     | 5     |
| [01-foundations](01-foundations/)             | Lexer/parser, basic block, CFG, SSA, dominance, use-def, loops                                                            | 6     |
| [02-ir-design](02-ir-design/)                 | Dialect, op, region, types, attributes, ODS/TableGen, legalization                                                        | 7     |
| [03-transformations](03-transformations/)     | Passes, patterns, folding, CSE/DCE, inlining, fusion, tiling, vectorization, bufferization                                | 9     |
| [04-hardware](04-hardware/)                   | SIMD, caches, GPU hierarchy, shared memory, coalescing, occupancy, tensor cores                                           | 7     |
| [05-ml-compilers](05-ml-compilers/)           | Tensors, layouts, kernels, graph vs kernel compilers, Triton, autotuning, `torch.compile`                                 | 7     |
| [06-mojo](06-mojo/)                           | Argument conventions, ownership, traits, parameters, `comptime`, SIMD, MAX kernels (Mojo 1.1)                             | 7     |
| [07-codegen-runtime](07-codegen-runtime/)     | Instruction selection, register allocation, JIT/AOT, ABI, linking, PTX/SASS                                               | 6     |
| [08-cpp-for-compilers](08-cpp-for-compilers/) | Ownership and arenas, SmallVector, CRTP, `isa`/`dyn_cast`, intrusive lists, variant ASTs, safe rewrites, LLVM conventions | 8     |
| [09-algorithms](09-algorithms/)               | Dominators, SSA construction, dataflow, graph-coloring register allocation, by hand                                       | 4     |
| [maps](maps/)                                 | The whole stack; each tool's pipeline; a matmul's journey to PTX                                                          | 3     |
| [rosetta](rosetta/)                           | Vector add, reduction and matmul across tools, with measurements                                                          | 3     |
| [real-world](real-world/)                     | Codebase tours: LLVM/MLIR, Triton, PyTorch Inductor, Mojo/MAX, my projects                                                | 5     |
| [interview](interview/)                       | Study plan, 5 question banks (100 questions), coding exercises, project stories                                           | 7     |
| [codebases](codebases/)                       | Runnable C++: compiler-mechanics-cpp and llvm-idioms-workbench (11 test suites)                                           | —     |
| [samples](samples/)                           | Inputs for every listing and benchmark in the guide                                                                       | —     |

## 📐 How every concept page is laid out

Each page follows [\_templates/term.md](_templates/term.md):

| Section             | Purpose                                                              |
| ------------------- | -------------------------------------------------------------------- |
| **One line**        | The definition, short enough to remember                             |
| 🌉 From frontend    | An analogy to something you already know, and where it stops working |
| 🖼️ Picture          | An ASCII diagram. Every page has one.                                |
| 🔧 In each tool     | Real output, plus how LLVM, MLIR, Triton and Mojo express the idea   |
| ⚠️ Common confusion | The mistake people usually make with this term                       |
| 🔗 Related          | Links to neighboring terms                                           |
| ✅ Verified against | The toolchain versions the page was checked with                     |

## 🧪 Reproduce everything

```bash
pixi install
```

```bash
MOJO_RUN=1 ./scripts/regen.sh
```

```bash
./scripts/test-codebases.sh --asan
```

```bash
python3 scripts/gen-indexes.py
```

- `regen.sh` regenerates every compiler listing and benchmark into
  `samples/out/`. After a toolchain upgrade, compare it with the pages and
  update their **Verified against** lines.
- `test-codebases.sh` builds and tests the C++ codebases. With `--asan`, it
  also runs them under AddressSanitizer + UndefinedBehaviorSanitizer.
- `mojo-ptx.sh` compiles a Mojo file's GPU kernels to NVIDIA PTX without an
  NVIDIA GPU.
- `gen-indexes.py` rebuilds the chapter tables after you add a page.

## 🧰 Toolchain

| Tool                | Version                      | How                                                                 |
| ------------------- | ---------------------------- | ------------------------------------------------------------------- |
| LLVM / MLIR / Clang | 23.1.1                       | Homebrew `llvm` (`mlir-opt`, `mlir-translate`, `llc`, `opt`, `lli`) |
| Mojo + MAX          | 1.1.0 + 26.6                 | `pixi.toml` in this repo (`mojo`, `max` from the Modular channel)   |
| PyTorch             | 2.5.1                        | system `python3` (CPU `torch.compile`)                              |
| Apple clang         | 21                           | system compiler for the C++ codebases and linking samples           |
| Machine             | Apple M2 (4P+4E cores, 8 GB) | macOS 27                                                            |

**Not run here:** Triton (no macOS build and no NVIDIA GPU), NVIDIA SASS
(`ptxas` needs the CUDA toolkit), and Mojo kernels on the Mac GPU (needs
Xcode's Metal toolchain: `xcodebuild -downloadComponent MetalToolchain`).
The GPU samples are compiled to PTX instead.
