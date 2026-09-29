# Glossary 📖

The A–Z index. One line per term, and every term links to the page that
explains it with real output.

## A–C

| Term                 | One line                                                                                              | Page                                                                               |
| -------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| ABI                  | The binary calling contract: which registers hold arguments and return values, how structs are passed | [abi-and-calling-conventions](07-codegen-runtime/abi-and-calling-conventions.md)   |
| AOT (ahead-of-time)  | Compile before running and ship a binary                                                              | [jit-vs-aot](07-codegen-runtime/jit-vs-aot.md)                                     |
| Arena / context      | One long-lived object owns every node; everyone else holds raw non-owning pointers                    | [ownership-and-arenas](08-cpp-for-compilers/ownership-and-arenas.md)               |
| `ArrayRef`           | Non-owning (pointer, length) view of a contiguous list                                                | [small-vector-and-arrayref](08-cpp-for-compilers/small-vector-and-arrayref.md)     |
| AST                  | Tree that mirrors how the source was written                                                          | [ast-vs-ir](00-bridge/ast-vs-ir.md)                                                |
| Attribute (MLIR)     | A compile-time constant attached to an op                                                             | [attributes-and-properties](02-ir-design/attributes-and-properties.md)             |
| Autotuning           | Compile several configs, time each on real hardware, keep the fastest                                 | [autotuning](05-ml-compilers/autotuning.md)                                        |
| Back edge            | CFG edge whose target dominates its source; it defines a loop                                         | [loops-in-ir](01-foundations/loops-in-ir.md)                                       |
| Bank conflict        | Several threads of a warp hitting the same shared-memory bank, serializing access                     | [shared-memory-and-registers](04-hardware/shared-memory-and-registers.md)          |
| Basic block          | Straight-line code: one entry at the top, one terminator at the bottom                                | [basic-block](01-foundations/basic-block.md)                                       |
| Block argument       | MLIR's version of φ: values passed into a block by each branch                                        | [ssa](01-foundations/ssa.md)                                                       |
| Block (GPU) / CTA    | Up to 1024 threads that share shared memory and can barrier                                           | [gpu-thread-warp-block-grid](04-hardware/gpu-thread-warp-block-grid.md)            |
| Broadcast (stride 0) | Repeating data along a dimension without copying                                                      | [layout-and-strides](05-ml-compilers/layout-and-strides.md)                        |
| Bufferization        | Converting value-style `tensor`s into writable `memref` buffers                                       | [bufferization](03-transformations/bufferization.md)                               |
| Cache line           | Fixed-size chunk (128 B on the M2) that memory moves in                                               | [cache-and-memory-hierarchy](04-hardware/cache-and-memory-hierarchy.md)            |
| Canonicalization     | Rewriting IR into one standard, simpler form                                                          | [canonicalization-and-folding](03-transformations/canonicalization-and-folding.md) |
| `cast<>`             | LLVM checked downcast: an assertion that never returns null                                           | [llvm-style-rtti](08-cpp-for-compilers/llvm-style-rtti.md)                         |
| CFG                  | Control-flow graph: basic blocks connected by jumps                                                   | [basic-block](01-foundations/basic-block.md)                                       |
| `classof`            | Static predicate behind `isa`/`dyn_cast`: a kind equality or range check                              | [llvm-style-rtti](08-cpp-for-compilers/llvm-style-rtti.md)                         |
| Coalescing           | A warp's neighboring accesses merged into few memory transactions                                     | [memory-coalescing](04-hardware/memory-coalescing.md)                              |
| Codegen              | Turning the lowest IR into machine code                                                               | [instruction-selection](07-codegen-runtime/instruction-selection.md)               |
| `comptime` (Mojo)    | Compile-time values, branches (`comptime if`) and unrolled loops (`comptime for`)                     | [comptime](06-mojo/comptime.md)                                                    |
| Constant folding     | Computing constant expressions at compile time                                                        | [canonicalization-and-folding](03-transformations/canonicalization-and-folding.md) |
| Contiguous           | Row-major with no gaps: strides are (product of later sizes, …, 1)                                    | [layout-and-strides](05-ml-compilers/layout-and-strides.md)                        |
| Conversion pattern   | A pattern that rewrites an illegal op into legal ones during dialect conversion                       | [legalization](02-ir-design/legalization.md)                                       |
| CRTP                 | Base class templated on its derived class, for static dispatch                                        | [virtual-dispatch-and-crtp](08-cpp-for-compilers/virtual-dispatch-and-crtp.md)     |
| CSE                  | Common subexpression elimination: compute once, reuse                                                 | [cse-and-dce](03-transformations/cse-and-dce.md)                                   |

## D–H

| Term                      | One line                                                                  | Page                                                                                      |
| ------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Dataflow analysis         | Per-block transfer functions + meet at joins, iterated to a fixpoint      | [dataflow-analysis](09-algorithms/dataflow-analysis.md)                                   |
| DCE                       | Dead code elimination: remove unused, side-effect-free code               | [cse-and-dce](03-transformations/cse-and-dce.md)                                          |
| Dialect (MLIR)            | A named set of ops, types and attributes, e.g. `arith`, `scf`, `llvm`     | [dialect](02-ir-design/dialect.md)                                                        |
| Dominance                 | A dominates B if every path from entry to B goes through A                | [dominance](01-foundations/dominance.md)                                                  |
| Dominance frontier        | Where a block's dominance ends: exactly where φs are needed               | [dominator-computation](09-algorithms/dominator-computation.md)                           |
| Dominator tree            | Each block's parent is its immediate dominator                            | [dominator-computation](09-algorithms/dominator-computation.md)                           |
| DType (Mojo)              | Element type of a SIMD value: `DType.float32`, `DType.int8` …             | [simd-and-dtype](06-mojo/simd-and-dtype.md)                                               |
| `dyn_cast<>`              | LLVM query downcast: the pointer if the type matches, otherwise null      | [llvm-style-rtti](08-cpp-for-compilers/llvm-style-rtti.md)                                |
| Epilogue fusion           | Applying following elementwise ops to a kernel's result before storing it | [matmul-naive-tiled-fused](rosetta/matmul-naive-tiled-fused.md)                           |
| Fast-math / `reassoc`     | Flags allowing the compiler to reorder float math                         | [reduction-in-5-irs](rosetta/reduction-in-5-irs.md)                                       |
| FMA / `madd`              | Fused multiply-add: `a * b + c` in one instruction                        | [instruction-selection](07-codegen-runtime/instruction-selection.md)                      |
| Fusion                    | Merging ops so intermediates never go to memory                           | [fusion](03-transformations/fusion.md)                                                    |
| Generic form (MLIR)       | The uniform `"dialect.op"(operands) <{props}> : type` syntax for any op   | [operation](02-ir-design/operation.md)                                                    |
| GlobalISel / SelectionDAG | LLVM's two instruction selectors                                          | [instruction-selection](07-codegen-runtime/instruction-selection.md)                      |
| Graph compiler            | Optimizes the whole model: fusion, layout, memory planning                | [graph-vs-kernel-compiler](05-ml-compilers/graph-vs-kernel-compiler.md)                   |
| Graph coloring (regalloc) | Registers as colors on an interference graph (Chaitin–Briggs)             | [graph-coloring-register-allocation](09-algorithms/graph-coloring-register-allocation.md) |
| Greedy pattern driver     | Applies rewrite patterns from a worklist until a fixpoint                 | [pattern-rewrite](03-transformations/pattern-rewrite.md)                                  |
| Guards (`torch.compile`)  | Checks deciding when compiled code is reused or recompiled                | [torch-compile](05-ml-compilers/torch-compile.md)                                         |

## I–L

| Term                  | One line                                                                 | Page                                                                                      |
| --------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| `index` (MLIR)        | Target-width integer type for sizes and loop counters                    | [types](02-ir-design/types.md)                                                            |
| Inductor              | PyTorch's `torch.compile` backend; writes Triton (GPU) or C++ (CPU)      | [torch-compile](05-ml-compilers/torch-compile.md)                                         |
| Inlining              | Replacing a call with a copy of the callee's body                        | [inlining](03-transformations/inlining.md)                                                |
| Instruction selection | Choosing real machine instructions for IR operations                     | [instruction-selection](07-codegen-runtime/instruction-selection.md)                      |
| Interference graph    | Values as nodes, an edge when two are live at the same time              | [graph-coloring-register-allocation](09-algorithms/graph-coloring-register-allocation.md) |
| Intrusive list        | A list whose links live inside each element: O(1), allocation-free edits | [intrusive-lists](08-cpp-for-compilers/intrusive-lists.md)                                |
| IR                    | Intermediate representation: code in a form built for analysis           | [ast-vs-ir](00-bridge/ast-vs-ir.md)                                                       |
| `isa<>`               | LLVM type test built on `classof`                                        | [llvm-style-rtti](08-cpp-for-compilers/llvm-style-rtti.md)                                |
| IsolatedFromAbove     | An op whose regions can't see outer values (e.g. `func.func`)            | [region](02-ir-design/region.md)                                                          |
| `iter_args`           | Values carried from one `scf.for` iteration to the next                  | [reduction-in-5-irs](rosetta/reduction-in-5-irs.md)                                       |
| JIT                   | Compile while running, specialized on real inputs                        | [jit-vs-aot](07-codegen-runtime/jit-vs-aot.md)                                            |
| Kernel                | One compiled function launched on an accelerator for one (fused) op      | [kernel](05-ml-compilers/kernel.md)                                                       |
| Layout                | How logical indices map to memory (or to threads)                        | [layout-and-strides](05-ml-compilers/layout-and-strides.md)                               |
| `LayoutTensor` (MAX)  | A pointer plus a compile-time layout, with tiling                        | [max-and-mojo-kernels](06-mojo/max-and-mojo-kernels.md)                                   |
| Legalization          | Converting until only ops the target accepts remain                      | [legalization](02-ir-design/legalization.md)                                              |
| Lexer / parser        | Text → tokens → tree                                                     | [lexer-and-parser](01-foundations/lexer-and-parser.md)                                    |
| `linalg`              | MLIR dialect for structured tensor math (`matmul`, `generic`)            | [dialect](02-ir-design/dialect.md)                                                        |
| Linking / relocation  | Resolving symbols across object files and patching addresses             | [linking-and-object-files](07-codegen-runtime/linking-and-object-files.md)                |
| Liveness              | Which values may still be used later: backward dataflow                  | [dataflow-analysis](09-algorithms/dataflow-analysis.md)                                   |
| LLVM IR               | LLVM's single, target-independent SSA IR                                 | [the-whole-stack](maps/the-whole-stack.md)                                                |
| Lowering              | Translating to a lower-level IR                                          | [dialect](02-ir-design/dialect.md)                                                        |

## M–P

| Term                  | One line                                                              | Page                                                                                      |
| --------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Mask                  | Per-lane on/off flags for out-of-range or conditional lanes           | [triton-programming-model](05-ml-compilers/triton-programming-model.md)                   |
| MAX                   | Modular's inference platform: graph compiler + Mojo kernel libraries  | [max-and-mojo-kernels](06-mojo/max-and-mojo-kernels.md)                                   |
| `mem2reg`             | LLVM pass promoting stack variables to SSA values, inserting φs       | [ssa-construction](09-algorithms/ssa-construction.md)                                     |
| Memory-bound          | Limited by memory traffic, not arithmetic                             | [cache-and-memory-hierarchy](04-hardware/cache-and-memory-hierarchy.md)                   |
| `memref`              | MLIR buffer type (pointer, offset, sizes, strides)                    | [types](02-ir-design/types.md)                                                            |
| MIR                   | LLVM Machine IR: real opcodes, virtual then physical registers        | [instruction-selection](07-codegen-runtime/instruction-selection.md)                      |
| `mma`                 | Tensor-core matrix multiply-accumulate instruction                    | [tensor-cores](04-hardware/tensor-cores.md)                                               |
| Monomorphization      | Compiling a generic function once per concrete type                   | [traits](06-mojo/traits.md)                                                               |
| Move / transfer (`^`) | Handing ownership to another owner                                    | [ownership-and-transfer](06-mojo/ownership-and-transfer.md)                               |
| Occupancy             | Resident warps per SM divided by the maximum                          | [occupancy](04-hardware/occupancy.md)                                                     |
| ODS / TableGen        | Declarative op definitions that generate C++                          | [ods-and-tablegen](02-ir-design/ods-and-tablegen.md)                                      |
| Op (operation)        | MLIR's unit: name, operands, results, attributes, regions             | [operation](02-ir-design/operation.md)                                                    |
| Owning slot           | The `unique_ptr&` edge a rewrite must write through to replace a node | [owning-slots-and-safe-rewrites](08-cpp-for-compilers/owning-slots-and-safe-rewrites.md)  |
| Parameter (Mojo)      | Compile-time input in `[...]`, vs runtime arguments in `(...)`        | [parameters-vs-arguments](06-mojo/parameters-vs-arguments.md)                             |
| Pass / pass manager   | One IR transformation; the pipeline runner                            | [pass-and-pass-manager](03-transformations/pass-and-pass-manager.md)                      |
| Pattern (rewrite)     | Local rule: match an op shape, replace it                             | [pattern-rewrite](03-transformations/pattern-rewrite.md)                                  |
| φ (phi)               | SSA instruction picking a value by incoming edge                      | [ssa](01-foundations/ssa.md)                                                              |
| Precolored node       | A value fixed to a physical register (ABI, special instructions)      | [graph-coloring-register-allocation](09-algorithms/graph-coloring-register-allocation.md) |
| Program (Triton)      | One kernel instance handling one block of data                        | [triton-programming-model](05-ml-compilers/triton-programming-model.md)                   |
| Progressive lowering  | Lowering in many small steps through several dialects                 | [dialect](02-ir-design/dialect.md)                                                        |
| Property (MLIR)       | An attribute the op definition owns, printed as `<{...}>`             | [attributes-and-properties](02-ir-design/attributes-and-properties.md)                    |
| PTX                   | NVIDIA's virtual GPU assembly                                         | [ptx-ptxas-and-sass](07-codegen-runtime/ptx-ptxas-and-sass.md)                            |
| `Pure`                | MLIR trait: no side effects, so unused instances can be deleted       | [operation](02-ir-design/operation.md)                                                    |

## R–S

| Term                  | One line                                                               | Page                                                                                      |
| --------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| RAII guard            | An object whose destructor restores state on every exit path           | [ownership-and-arenas](08-cpp-for-compilers/ownership-and-arenas.md)                      |
| Reaching definitions  | Which definition sites can reach a point: forward dataflow             | [dataflow-analysis](09-algorithms/dataflow-analysis.md)                                   |
| Reduction             | Combining many values into one (sum, max); order-sensitive for floats  | [reduction-in-5-irs](rosetta/reduction-in-5-irs.md)                                       |
| Region (MLIR)         | A list of blocks nested inside an op                                   | [region](02-ir-design/region.md)                                                          |
| Register allocation   | Mapping virtual registers to physical ones, spilling the rest          | [register-allocation](07-codegen-runtime/register-allocation.md)                          |
| Register blocking     | Keeping a tile of the output in registers across the reduction loop    | [matmul-naive-tiled-fused](rosetta/matmul-naive-tiled-fused.md)                           |
| Reverse postorder     | Block order where predecessors (except back edges) come first          | [dominator-computation](09-algorithms/dominator-computation.md)                           |
| SASS                  | NVIDIA's real GPU machine code, produced by `ptxas`                    | [ptx-ptxas-and-sass](07-codegen-runtime/ptx-ptxas-and-sass.md)                            |
| `scf`                 | MLIR structured control flow: `scf.for`, `scf.if`, `scf.parallel`      | [dialect](02-ir-design/dialect.md)                                                        |
| Shared memory         | Fast on-chip memory shared by one GPU block, managed by hand           | [shared-memory-and-registers](04-hardware/shared-memory-and-registers.md)                 |
| Shuffle (`shfl.sync`) | Exchanging registers between lanes of a warp                           | [reduction-in-5-irs](rosetta/reduction-in-5-irs.md)                                       |
| SIMD                  | One instruction operating on several lanes                             | [simd-and-vector-width](04-hardware/simd-and-vector-width.md)                             |
| `SIMD[dtype, width]`  | Mojo's core numeric type; scalars are width-1 SIMD                     | [simd-and-dtype](06-mojo/simd-and-dtype.md)                                               |
| `SmallVector`         | Vector with N inline elements before heap allocation                   | [small-vector-and-arrayref](08-cpp-for-compilers/small-vector-and-arrayref.md)            |
| Spill                 | Storing a value in memory because no register is free                  | [graph-coloring-register-allocation](09-algorithms/graph-coloring-register-allocation.md) |
| SSA                   | Static single assignment: every value defined exactly once             | [ssa](01-foundations/ssa.md)                                                              |
| SSA construction      | φ placement at iterated dominance frontiers + renaming (Cytron et al.) | [ssa-construction](09-algorithms/ssa-construction.md)                                     |
| Strides               | Element distance per dimension                                         | [layout-and-strides](05-ml-compilers/layout-and-strides.md)                               |

## T–Z

| Term                         | One line                                                                      | Page                                                                           |
| ---------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Target triple                | String naming the output machine, e.g. `nvptx64-nvidia-cuda`                  | [babel-is-a-compiler](00-bridge/babel-is-a-compiler.md)                        |
| `tensor` (MLIR)              | Immutable n-D array value                                                     | [tensor-and-shape](05-ml-compilers/tensor-and-shape.md)                        |
| Tensor cores                 | Matrix-multiply units reached through `mma` instructions                      | [tensor-cores](04-hardware/tensor-cores.md)                                    |
| Terminator                   | The last op of a block: `br`, `cond_br`, `return`                             | [basic-block](01-foundations/basic-block.md)                                   |
| Thread / warp / block / grid | The GPU execution hierarchy                                                   | [gpu-thread-warp-block-grid](04-hardware/gpu-thread-warp-block-grid.md)        |
| Tiling                       | Splitting loops into blocks that fit in fast memory                           | [tiling](03-transformations/tiling.md)                                         |
| `torch.compile`              | Dynamo capture + Inductor codegen                                             | [torch-compile](05-ml-compilers/torch-compile.md)                              |
| Trait (Mojo)                 | A compile-time interface constraining parameters                              | [traits](06-mojo/traits.md)                                                    |
| Trait (MLIR)                 | A property on an op definition, e.g. `Pure`                                   | [operation](02-ir-design/operation.md)                                         |
| `tt` / `ttg`                 | Triton's MLIR dialects: tile ops, then tile ops + GPU layouts                 | [triton-tour](real-world/triton-tour.md)                                       |
| Type conversion              | Mapping types during lowering (`TypeConverter`, `unrealized_conversion_cast`) | [legalization](02-ir-design/legalization.md)                                   |
| Use-def chain                | Each value's single definition and its list of uses                           | [use-def-chains](01-foundations/use-def-chains.md)                             |
| Variant AST                  | AST nodes as a closed `std::variant`, visited exhaustively                    | [variant-asts](08-cpp-for-compilers/variant-asts.md)                           |
| Vectorization                | Rewriting scalar loops to use SIMD instructions                               | [vectorization](03-transformations/vectorization.md)                           |
| Virtual dispatch / vtable    | Runtime method selection through a per-class table                            | [virtual-dispatch-and-crtp](08-cpp-for-compilers/virtual-dispatch-and-crtp.md) |
| Warp                         | 32 threads executing in lockstep (NVIDIA; Apple SIMD-group)                   | [gpu-thread-warp-block-grid](04-hardware/gpu-thread-warp-block-grid.md)        |
| Warp divergence              | A warp running both sides of a branch because its threads disagree            | [gpu-thread-warp-block-grid](04-hardware/gpu-thread-warp-block-grid.md)        |
