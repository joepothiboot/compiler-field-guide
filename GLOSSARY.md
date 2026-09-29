# Glossary 📖

The A–Z index. One line per term. Linked terms have a full page. ⏳ marks a
term whose page has not been written yet, with the chapter it will go in.

## A–C

| Term                | One line                                                                                                | Page                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| AOT (ahead-of-time) | Compile before the program runs, producing a binary                                                     | ⏳ 07                                                               |
| AST                 | Tree that mirrors how the source was written                                                            | [ast-vs-ir](00-bridge/ast-vs-ir.md)                                 |
| Attribute (MLIR)    | A compile-time constant attached to an op, e.g. `0 : i32` or a predicate like `sgt`                     | ⏳ 02                                                               |
| Autotuning          | Try several kernel configurations (block sizes, and so on), keep the fastest                            | ⏳ 05                                                               |
| Basic block         | Straight-line instructions: one entry at the top, one terminator at the bottom                          | [basic-block](01-foundations/basic-block.md)                        |
| Block argument      | MLIR's replacement for φ: values passed into a block when you jump to it                                | [ssa](01-foundations/ssa.md)                                        |
| Bufferization       | Converting value-style `tensor`s into writable `memref` buffers                                         | ⏳ 03                                                               |
| Canonicalization    | Rewriting IR into one standard, simpler form, e.g. `if`/`else` → `maxsi`                                | [bundler-plugins-vs-passes](00-bridge/bundler-plugins-vs-passes.md) |
| CFG                 | Control-flow graph: basic blocks connected by jumps                                                     | [basic-block](01-foundations/basic-block.md)                        |
| Coalescing          | Neighboring GPU threads reading neighboring addresses, so the reads combine into one memory transaction | ⏳ 04                                                               |
| Codegen             | Turning the lowest IR into machine code or assembly                                                     | ⏳ 07                                                               |
| `comptime` (Mojo)   | Declares a value computed at compile time, e.g. `comptime width = ...`                                  | [vector-add](rosetta/vector-add-in-5-irs.md)                        |
| Constant folding    | Computing constant expressions at compile time: `2*3` → `6`                                             | ⏳ 03                                                               |
| CSE                 | Common subexpression elimination: compute `a+b` once and reuse it                                       | ⏳ 03                                                               |

## D–K

| Term                  | One line                                                                                   | Page                                   |
| --------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------- |
| DCE                   | Dead code elimination: remove what nothing uses (tree-shaking)                             | ⏳ 03                                  |
| Dialect (MLIR)        | A named set of ops, types and attributes, e.g. `arith`, `scf`, `llvm`                      | [dialect](02-ir-design/dialect.md)     |
| Dominance             | Block A _dominates_ B if every path to B passes through A                                  | ⏳ 01                                  |
| Fusion                | Merging several ops or kernels into one so intermediate results never go to memory         | ⏳ 03                                  |
| Graph compiler        | Optimizes a whole model graph (fusion, layout) before generating kernels                   | ⏳ 05                                  |
| Inductor              | PyTorch's `torch.compile` backend. It writes Triton kernels on GPU                         | [whole-stack](maps/the-whole-stack.md) |
| Instruction selection | Choosing real machine instructions for each IR operation                                   | ⏳ 07                                  |
| IR                    | Intermediate representation: code in a form built for analysis and transformation          | [ast-vs-ir](00-bridge/ast-vs-ir.md)    |
| JIT                   | Compile while the program is running (Triton, and `mojo run`)                              | ⏳ 07                                  |
| Kernel                | One function launched on an accelerator (or a hot CPU loop) that does one tensor operation | ⏳ 05                                  |

## L–R

| Term                 | One line                                                                                   | Page                                                                |
| -------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| Layout               | How a tensor's logical indices map to memory addresses or threads                          | ⏳ 05                                                               |
| Legalization         | Converting until only the ops the target "allows" remain                                   | ⏳ 02                                                               |
| `linalg`             | MLIR dialect for structured tensor math (matmul, conv, `generic`)                          | [dialect](02-ir-design/dialect.md)                                  |
| LLVM IR              | LLVM's single, target-independent SSA IR (`.ll`)                                           | [whole-stack](maps/the-whole-stack.md)                              |
| Lowering             | Translating to a lower-level IR: more concrete, less high-level meaning                    | [dialect](02-ir-design/dialect.md)                                  |
| Mask                 | Per-lane on/off flags for out-of-range elements (Triton `mask=`)                           | [vector-add](rosetta/vector-add-in-5-irs.md)                        |
| MAX                  | Modular's graph compiler and inference framework. Its kernels are written in Mojo          | [whole-stack](maps/the-whole-stack.md)                              |
| `mem2reg`            | LLVM pass that turns stack variables into SSA values and inserts φs                        | [ssa](01-foundations/ssa.md)                                        |
| `memref`             | MLIR type for a buffer in memory that can be written to                                    | [vector-add](rosetta/vector-add-in-5-irs.md)                        |
| Occupancy            | How many threads a GPU keeps active compared with its maximum                              | ⏳ 04                                                               |
| Op (operation)       | The single unit of MLIR: name, operands, results, attributes, regions                      | ⏳ 02                                                               |
| Parameter (Mojo)     | Compile-time input in `[...]`, as opposed to runtime _arguments_ in `(...)`                | [vector-add](rosetta/vector-add-in-5-irs.md)                        |
| Pass                 | One transformation over the whole IR                                                       | [bundler-plugins-vs-passes](00-bridge/bundler-plugins-vs-passes.md) |
| Pattern (rewrite)    | A small local rule: match an op shape, replace it                                          | [bundler-plugins-vs-passes](00-bridge/bundler-plugins-vs-passes.md) |
| φ (phi)              | SSA instruction that picks a value based on which block control came from                  | [ssa](01-foundations/ssa.md)                                        |
| Program (Triton)     | One instance of a Triton kernel, identified by `tl.program_id`; runs as a GPU thread block | [vector-add](rosetta/vector-add-in-5-irs.md)                        |
| Progressive lowering | Lowering in many small steps through several dialects instead of one big jump              | [dialect](02-ir-design/dialect.md)                                  |
| PTX                  | NVIDIA's virtual GPU assembly. `ptxas` compiles it to SASS                                 | [vector-add](rosetta/vector-add-in-5-irs.md)                        |
| Region (MLIR)        | A list of blocks nested inside an op, e.g. the body of `scf.for`                           | ⏳ 02                                                               |
| Register allocation  | Mapping unlimited SSA values onto the CPU/GPU's limited registers                          | ⏳ 07                                                               |

## S–Z

| Term                  | One line                                                                              | Page                                                    |
| --------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| SASS                  | The real machine code of an NVIDIA GPU (below PTX)                                    | [vector-add](rosetta/vector-add-in-5-irs.md)            |
| `scf`                 | MLIR "structured control flow": `scf.for`, `scf.if`, `scf.while`                      | [dialect](02-ir-design/dialect.md)                      |
| Shared memory         | Fast on-chip GPU memory shared by the threads in one block                            | ⏳ 04                                                   |
| SIMD                  | Single instruction, multiple data: one instruction works on a vector of lanes         | [vector-add](rosetta/vector-add-in-5-irs.md)            |
| SSA                   | Static single assignment: every value is defined exactly once                         | [ssa](01-foundations/ssa.md)                            |
| Target triple         | String naming the output machine, e.g. `nvptx64-nvidia-cuda`                          | [babel-is-a-compiler](00-bridge/babel-is-a-compiler.md) |
| `tensor` (MLIR)       | Value-style n-D array type, SSA-friendly and not writable in place                    | ⏳ 05                                                   |
| Terminator            | The last op of a block, which transfers control: `br`, `cond_br`, `return`            | [basic-block](01-foundations/basic-block.md)            |
| Thread / block / grid | GPU hierarchy: threads form blocks, and blocks form a grid                            | ⏳ 04                                                   |
| Tiling                | Splitting a loop nest into blocks (tiles) that fit in cache or shared memory          | ⏳ 03                                                   |
| Trait (Mojo)          | An interface a type conforms to, e.g. `Copyable`, `Movable`                           | ⏳ 06                                                   |
| `tt` / `ttg`          | Triton's MLIR dialects: tile ops, then tile ops with GPU layouts                      | [dialect](02-ir-design/dialect.md)                      |
| Vectorization         | Rewriting scalar loops to use SIMD instructions                                       | ⏳ 03                                                   |
| Warp                  | 32 NVIDIA GPU threads that execute in lockstep (AMD calls it a wavefront, usually 64) | ⏳ 04                                                   |
