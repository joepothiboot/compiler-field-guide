# compiler-field-guide 🧭

A single place to learn the vocabulary and mental models of compilers, from
MLIR and LLVM up to Triton and Mojo. It is written for someone coming from
frontend and general software engineering.

The guide is organized **by concept, not by tool**. Each term gets one page, and
that page shows how LLVM, MLIR, Triton and Mojo each handle it. You should not
need to open the official docs of four projects to understand one idea.

## 🗺️ Where to start

1. **[maps/the-whole-stack.md](maps/the-whole-stack.md)**: one diagram of the
   whole stack, from Python to machine code, and where each tool sits in it.
2. **[00-bridge/](00-bridge/)**: things you already know from frontend work
   (Babel, ASTs, bundler plugins) mapped onto compiler ideas.
3. **[01-foundations/](01-foundations/)**: basic blocks, SSA and CFGs. Almost
   every later page depends on these.
4. **[rosetta/vector-add-in-5-irs.md](rosetta/vector-add-in-5-irs.md)**: one
   program written in five IRs. It shows how the concepts connect.
5. Then read the chapters in any order, and use **[GLOSSARY.md](GLOSSARY.md)**
   as the A–Z index.

## 📚 Chapters

| Folder                                    | Covers                                                     | Status |
| ----------------------------------------- | ---------------------------------------------------------- | ------ |
| [00-bridge](00-bridge/)                   | FE/SWE ideas mapped to compiler ideas                      | ✅     |
| [01-foundations](01-foundations/)         | AST, IR, basic block, CFG, SSA, dominance                  | 🚧     |
| [02-ir-design](02-ir-design/)             | Dialect, op, region, attribute, type, progressive lowering | 🚧     |
| [03-transformations](03-transformations/) | Passes, pattern rewrites, fusion, tiling, vectorization    | ⏳     |
| [04-hardware](04-hardware/)               | SIMD, caches, GPU execution model, memory coalescing       | ⏳     |
| [05-ml-compilers](05-ml-compilers/)       | Tensors, layouts, kernels, graph compilers, Triton model   | ⏳     |
| [06-mojo](06-mojo/)                       | Ownership, traits, parameters, `comptime`, `SIMD`, MAX     | ⏳     |
| [07-codegen-runtime](07-codegen-runtime/) | Instruction selection, register allocation, JIT/AOT, PTX   | ⏳     |
| [maps](maps/)                             | Full-page ASCII diagrams                                   | 🚧     |
| [rosetta](rosetta/)                       | The same program in every tool, compared side by side      | 🚧     |

✅ written · 🚧 some pages written · ⏳ outline only

## 📐 How every term page is laid out

Each page follows [\_templates/term.md](_templates/term.md):

| Section             | Purpose                                                              |
| ------------------- | -------------------------------------------------------------------- |
| **One line**        | The definition, short enough to remember                             |
| 🌉 From frontend    | An analogy to something you already know, and where it stops working |
| 🖼️ Picture          | An ASCII diagram. Every page has one.                                |
| 🔧 In each tool     | How LLVM IR, MLIR, Triton and Mojo express or hide the idea          |
| ⚠️ Common confusion | The mistake people usually make with this term                       |
| 🔗 Related          | Links to neighboring terms                                           |
| ✅ Verified against | The toolchain versions the page's code was checked with              |

## 🧪 Code on these pages is real

Every IR listing is real compiler output, not typed from memory. The inputs
are in [samples/](samples/), and [scripts/regen.sh](scripts/regen.sh)
regenerates all of the outputs:

```bash
MOJO_PROJECT=../nano-dsp-mlir ./scripts/regen.sh
```

After a toolchain upgrade, rerun the script, compare `samples/out/` with the
pages, and update each changed page's **Verified against** line.

Current toolchain: **LLVM/MLIR 23.1.1** (Homebrew), **Mojo 1.1.0** (pixi).
Triton code is not run locally because this machine has no NVIDIA GPU. Pages
that show Triton say so.
