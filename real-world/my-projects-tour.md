# My Projects Tour 🧪

> **Each of my repositories as a real-world sample of the concepts in this
> guide.** Use this page to connect a concept to code you wrote and can
> explain in detail, which is the strongest material for an interview.

## 🗺️ Where each project sits

```
                    front end      custom dialect     upstream MLIR       LLVM / codegen      runtime / tooling
                    ─────────      ──────────────     ─────────────       ──────────────      ─────────────────
 json-schema-mlir   JSON Schema ─► schema dialect ──► arith/scf/math ──► LLVM IR ──────────► native validator
                    (lexer, parser, importer)
 nano-dsp-mlir      dsp dialect ───────────────────► linalg → loops ──► LLVM IR ──────────► JIT / .o
                    (DSL front end planned)          (tiled + vectorized)                    + Mojo SIMD kernels
 vizmlir                                              reads --mlir-print-ir-after-all  ─────► browser visualizer
 llvm-idioms-workbench   C++ AST + RTTI + pass manager   (codebases/)
 compiler-mechanics-cpp  SSA, dataflow, regalloc by hand  (codebases/)
```

## 📦 nano-dsp-mlir (`b2058a6`)

A small MLIR compiler for a tiny image/math DSL. Its README designs six IR
levels: Python DSL → `dsp` dialect → `linalg.generic` on tensors → tiled +
vectorized loops (a Transform-dialect schedule) → memref buffers → LLVM IR.
Status per its README at this commit: the `dsp` dialect (including the int8
`dsp.qmatmul`), its lowering to `linalg.generic`, tiling + vectorization
from a Transform-dialect schedule (Stage 3, bit-exact against the unscheduled
code), and bufferization through LLVM (upstream passes) are **done**. A Mojo
SIMD kernel library with a C++ reference oracle is done, tested against the
same golden values. The benchmark sweep that validates the tile-size model
(Stage 5) and the DSL front end are not done.

| Concept                                 | In nano-dsp-mlir                                           | Guide page                                                                            |
| --------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Custom dialect in ODS                   | `include/nanodsp/Dialect/DSP/IR/DSPOps.td`                 | [ODS and TableGen](../02-ir-design/ods-and-tablegen.md)                               |
| Canonicalization pattern                | `ReluOp::canonicalize` in `lib/Dialect/DSP/IR/DSPOps.cpp`  | [Pattern rewrite](../03-transformations/pattern-rewrite.md)                           |
| Full conversion, ConversionTarget       | `lib/Conversion/DSPToLinalg/DSPToLinalg.cpp`               | [Legalization](../02-ir-design/legalization.md)                                       |
| `linalg.generic` (fusion-ready)         | output of `--convert-dsp-to-linalg`                        | [Fusion](../03-transformations/fusion.md)                                             |
| End-to-end lowering to LLVM             | `test/Integration/end-to-end.mlir`                         | [Dialect](../02-ir-design/dialect.md)                                                 |
| Tiling + vectorization as data          | `lib/Schedule/`, `-nanodsp-optimize`, `test/Schedule/`     | [Tiling](../03-transformations/tiling.md)                                             |
| SIMD kernels in Mojo                    | `mojo/nanodsp/kernels.mojo`                                | [SIMD and DType](../06-mojo/simd-and-dtype.md)                                        |
| NaN semantics (`maximumf` vs `maxnumf`) | `dsp.relu` description in `DSPOps.td`                      | [Canonicalization and folding](../03-transformations/canonicalization-and-folding.md) |

## 📐 json-schema-mlir (`a558730`)

Compiles JSON Schema documents into native validators. A hand-written front
end (`schema-translate --import-json-schema`: lexer, recursive-descent parser,
importer) raises a document into a `schema` dialect, one op per keyword,
located at that keyword. Rules are then simplified as constraints (subsumption, fusion,
contradiction detection) and lowered with a `TypeConverter` to
`arith`/`scf`/`math` and LLVM IR.

| Concept                          | In json-schema-mlir                               | Guide page                                                                            |
| -------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Lexer and parser (hand-written)  | `lib/Schema/Import/Lexer.cpp`, `Parser.cpp`       | [Lexer and parser](../01-foundations/lexer-and-parser.md)                             |
| Dialect definition               | `include/Schema/SchemaDialect.td`, `SchemaOps.td` | [Dialect](../02-ir-design/dialect.md)                                                 |
| Domain-specific canonicalization | `--schema-canonicalize` (constraint lattice)      | [Canonicalization and folding](../03-transformations/canonicalization-and-folding.md) |
| Type conversion during lowering  | `--lower-schema-to-std` (`!schema.value → i64`)   | [Legalization](../02-ir-design/legalization.md)                                       |
| Full pipeline to LLVM            | `--schema-to-llvm-pipeline`                       | [Pass and pass manager](../03-transformations/pass-and-pass-manager.md)               |

## 🔍 vizmlir (`a04a5ec`)

A browser tool that reads `mlir-opt --mlir-print-ir-after-all` output and
shows GPU work visually: blocks, warps, memory spaces, and a
coalesced/strided/broadcast verdict for every access, proven for every warp
when addresses are linear. Also reads Triton GPU IR, and shows pass-by-pass
differences and timing.

| Concept                      | In vizmlir                                      | Guide page                                                                    |
| ---------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------- |
| IR after each pass           | its trace input format (`docs/trace-format.md`) | [Pass and pass manager](../03-transformations/pass-and-pass-manager.md)       |
| Coalescing analysis          | memory verdicts per access                      | [Memory coalescing](../04-hardware/memory-coalescing.md)                      |
| Thread / warp / block / grid | the GPU view                                    | [GPU thread, warp, block, grid](../04-hardware/gpu-thread-warp-block-grid.md) |
| Lowering `gpu.launch` to PTX | kernel history view                             | [A tensor's journey](../maps/tensor-journey-matmul-to-ptx.md)                 |

## 🛠️ llvm-idioms-workbench and compiler-mechanics-cpp

Copied into [codebases/](../codebases/) and explained in
[08-cpp-for-compilers](../08-cpp-for-compilers/) and
[09-algorithms](../09-algorithms/). Together they cover the C++ and
algorithms layer beneath all the projects above: ownership, RTTI,
passes, SSA, dataflow and register allocation.

## 🔗 Related

- [Talking about your projects](../interview/talking-about-your-projects.md)
- [Where each tool sits](../maps/where-each-tool-sits.md)

---

✅ Verified against: each repository's README and source at the commits shown
