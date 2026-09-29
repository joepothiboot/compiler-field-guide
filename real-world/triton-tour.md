# Triton Codebase Tour 🔱

> **Where Triton's pieces live in `triton-lang/triton`.** Triton is a
> Python front end over an MLIR-based compiler written in C++. Paths were
> checked on GitHub in September 2026.

## 🗺️ The top level

```
triton/
├── python/triton/
│   ├── language/core.py        tl.load, tl.store, tl.dot, tl.sum, tl.arange ...  (the DSL)
│   ├── runtime/jit.py          @triton.jit: parses the function, specializes, caches
│   ├── runtime/autotuner.py    @triton.autotune
│   └── compiler/compiler.py    drives the stages; CompiledKernel.asm["ttir"/"ttgir"/"llir"/"ptx"]
├── python/src/ir.cc            Python bindings that build MLIR ops from Python
├── python/tutorials/           01-vector-add.py, 03-matrix-multiplication.py, ...
├── include/triton/Dialect/
│   ├── Triton/IR/TritonOps.td          the tt dialect (ODS)
│   └── TritonGPU/IR/TritonGPUAttrDefs.td   layouts: #blocked, #mma, #shared ...
├── lib/Conversion/TritonToTritonGPU/   tt → ttg (attach layouts)
├── lib/Dialect/TritonGPU/Transforms/   Coalesce.cpp, AccelerateMatmul.cpp, pipelining ...
└── third_party/nvidia/
    ├── backend/compiler.py              make_ttir, make_ttgir, make_llir, make_ptx, make_cubin
    └── lib/TritonNVIDIAGPUToLLVM/       ttg → LLVM IR for NVIDIA
```

## 🔎 Concept → file

| Concept (guide page)                                                       | File                                                                                       |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| [Triton programming model](../05-ml-compilers/triton-programming-model.md) | `python/triton/language/core.py`; `python/tutorials/01-vector-add.py`                      |
| [JIT and caching](../07-codegen-runtime/jit-vs-aot.md)                     | `python/triton/runtime/jit.py`                                                             |
| [Autotuning](../05-ml-compilers/autotuning.md)                             | `python/triton/runtime/autotuner.py`                                                       |
| [Dialects / ODS](../02-ir-design/ods-and-tablegen.md)                      | `include/triton/Dialect/Triton/IR/TritonOps.td`                                            |
| [Layouts](../05-ml-compilers/layout-and-strides.md)                        | `include/triton/Dialect/TritonGPU/IR/TritonGPUAttrDefs.td`                                 |
| [Memory coalescing](../04-hardware/memory-coalescing.md)                   | `lib/Dialect/TritonGPU/Transforms/Coalesce.cpp`                                            |
| [Tensor cores](../04-hardware/tensor-cores.md)                             | `lib/Dialect/TritonGPU/Transforms/AccelerateMatmul.cpp` (picks `mma` layouts for `tt.dot`) |
| [Stage pipeline](../maps/where-each-tool-sits.md)                          | `third_party/nvidia/backend/compiler.py`                                                   |
| [Matmul](../rosetta/matmul-naive-tiled-fused.md)                           | `python/tutorials/03-matrix-multiplication.py`                                             |

## 📖 How to read it

1. Read `third_party/nvidia/backend/compiler.py` first: each `make_*`
   function lists the MLIR passes for one stage. It is the table of contents.
2. Then open one pass that matters for performance (`Coalesce.cpp`) and
   compare it with the [memory coalescing](../04-hardware/memory-coalescing.md)
   page's PTX.
3. On a Linux machine with an NVIDIA GPU, run a tutorial with
   `MLIR_ENABLE_DUMP=1` to see the IR after each pass. (Not possible on this
   Mac: Triton has no macOS build.)

## 🔗 Related

- [Triton programming model](../05-ml-compilers/triton-programming-model.md)
- [PyTorch Inductor tour](pytorch-inductor-tour.md): Triton's biggest user

---

✅ Paths verified on GitHub (`triton-lang/triton`, default branch, 2026-09);
not run locally
