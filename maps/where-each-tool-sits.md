# Where Each Tool Sits (Detailed) 🧩

> **The pipeline inside each tool,** stage by stage, with the command or
> flag that shows you that stage. Use it with
> [the whole stack](the-whole-stack.md), which shows how the tools
> connect.

## 🐉 LLVM (Clang)

```
 .c ──► Clang AST ──► LLVM IR (-O0: allocas) ──► opt passes (mem2reg, instcombine,
        -ast-dump      -emit-llvm                  loop-vectorize, ...) -O2
                                                           │
     machine code ◄── MC layer ◄── regalloc ◄── isel (SelectionDAG/GlobalISel)
     -S / -c          (encoding)   -stop-after=     -stop-after=finalize-isel
                                   virtregrewriter
```

| See it               | Command                                                                       | Page                                                                    |
| -------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Tokens / AST         | `clang -Xclang -dump-tokens` / `-ast-dump`                                    | [Lexer and parser](../01-foundations/lexer-and-parser.md)               |
| IR in SSA form       | `clang -O0 -Xclang -disable-O0-optnone -S -emit-llvm` + `opt -passes=mem2reg` | [SSA](../01-foundations/ssa.md)                                         |
| Optimization remarks | `-Rpass=loop-vectorize`                                                       | [Vectorization](../03-transformations/vectorization.md)                 |
| Machine IR           | `llc -stop-after=finalize-isel` / `virtregrewriter`                           | [Instruction selection](../07-codegen-runtime/instruction-selection.md) |

## 🏗️ Upstream MLIR

```
 your dialect (e.g. dsp, schema)
     │ your conversion pass
     ▼
 linalg / tensor ──► bufferization ──► linalg on memref ──► scf / affine loops
                     --one-shot-bufferize                    --convert-linalg-to-loops
     ┌─────────────────────────────────────────────────────────────┘
     ▼                                         ▼
 CPU: vector ──► cf ──► llvm dialect        GPU: gpu.launch ──► gpu.module ──► nvvm
      --convert-scf-to-cf --convert-to-llvm      --gpu-kernel-outlining  --gpu-lower-to-nvvm-pipeline
     │                                               │
     ▼ mlir-translate --mlir-to-llvmir               ▼ embedded PTX (gpu.binary)
 LLVM IR ──► llc / clang                          PTX
```

| See it              | Flag                        | Page                                                                    |
| ------------------- | --------------------------- | ----------------------------------------------------------------------- |
| Every pass's output | `--mlir-print-ir-after-all` | [Pass and pass manager](../03-transformations/pass-and-pass-manager.md) |
| Generic form        | `--mlir-print-op-generic`   | [Operation](../02-ir-design/operation.md)                               |
| Uses of each value  | `--mlir-print-value-users`  | [Use-def chains](../01-foundations/use-def-chains.md)                   |
| Timing              | `--mlir-timing`             | [Pass and pass manager](../03-transformations/pass-and-pass-manager.md) |

## 🔱 Triton (NVIDIA backend)

```
 @triton.jit Python ──► ttir (tt dialect) ──► ttgir (ttg: layouts, pipelining,
   (Python ast)          make_ttir              mma selection) make_ttgir
                                                     │
      cubin ◄── ptxas ◄── ptx ◄── llir (LLVM IR) ◄───┘
      make_cubin          make_ptx  make_llir
```

| See it                   | How                                                                                        |
| ------------------------ | ------------------------------------------------------------------------------------------ |
| MLIR after each pass     | `MLIR_ENABLE_DUMP=1`                                                                       |
| All stages of one kernel | `compiled = kernel[grid](...)`; `compiled.asm["ttir"]`, `["ttgir"]`, `["llir"]`, `["ptx"]` |
| Cache                    | `~/.triton/cache/`                                                                         |

(From Triton's documentation and source; not run on this Mac.)

## 🔥 PyTorch `torch.compile`

```
 Python fn ──► TorchDynamo ──► FX graph ──► AOTAutograd ──► Inductor ──┬─► Triton kernels (GPU)
               bytecode tracing, guards     fwd/bwd graphs  fusion,     └─► C++ / OpenMP (CPU)
                                                            scheduling
```

| See it         | How                        | Page                                                 |
| -------------- | -------------------------- | ---------------------------------------------------- |
| Captured graph | `TORCH_LOGS="graph_code"`  | [torch.compile](../05-ml-compilers/torch-compile.md) |
| Generated code | `TORCH_LOGS="output_code"` | [torch.compile](../05-ml-compilers/torch-compile.md) |
| Recompiles     | `TORCH_LOGS="recompiles"`  | —                                                    |

## 🔥 Mojo / MAX

```
 .mojo ──► Mojo parser ──► Mojo's internal MLIR dialects ──► LLVM IR ──┬─► CPU machine code
                           (parameters specialized,                     ├─► PTX (NVIDIA)
                            comptime evaluated)                         ├─► AMDGPU
                                                                        └─► Metal (Apple GPU)
 MAX graph ──► MAX graph compiler ──► Mojo kernels (layout, linalg, nn packages)
```

| See it                  | Command                                                      | Page                                                               |
| ----------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------ |
| LLVM IR                 | `mojo build --emit llvm file.mojo`                           | —                                                                  |
| Host assembly + GPU PTX | `mojo build --emit asm --target-accelerator=sm_80 file.mojo` | [PTX, ptxas and SASS](../07-codegen-runtime/ptx-ptxas-and-sass.md) |
| Target configuration    | `mojo build --print-effective-target`                        | —                                                                  |

## 🧪 My projects

```
 json-schema-mlir   JSON Schema ─► schema dialect ─► arith/scf/math ─► LLVM IR ─► native validator
 nano-dsp-mlir      dsp dialect ─► linalg.generic ─► loops ─► LLVM IR     (+ Mojo SIMD kernels, same golden tests;
                                                                        tiled + vectorized by a Transform schedule)
 vizmlir            reads --mlir-print-ir-after-all output: GPU view with proven memory verdicts, pass diffs (Rust → WASM parser)
 llvm-idioms-workbench   C++ AST, LLVM-style RTTI, pass manager   (codebases/)
 compiler-mechanics-cpp  SSA, dataflow, regalloc by hand           (codebases/)
```

---

✅ Verified against: LLVM/MLIR 23.1.1, Mojo 1.1.0, PyTorch 2.5.1 (run
locally) · Triton: documentation and source, not run
