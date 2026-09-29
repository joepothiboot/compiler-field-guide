# Tensor Cores 🟩

> **One line:** Tensor cores are dedicated matrix-multiply units. One
> instruction, executed by a whole warp together, computes a small matrix
> product like `D = A × B + C` for a 16×8×16 tile, usually with low-precision
> inputs (f16, bf16, fp8) and f32 accumulation.

## 🌉 From frontend

It is like the browser handing CSS transforms to the GPU compositor instead
of computing them on the main thread: specialized hardware for one shape of
work, much faster than doing it in general code. Matrix multiply is the
one shape that dominates ML, so GPUs got a dedicated unit for it.

## 🖼️ Picture

```
 one mma.sync instruction, m16n8k16 (whole warp, 32 threads):

        A (16×16, f16)        B (16×8, f16)        C, D (16×8, f32)
      ┌────────────────┐    ┌────────┐           ┌────────┐
      │                │    │        │           │        │
   16 │                │ ×  │  16×8  │    +      │  16×8  │  = D
      │                │    │        │           │        │
      └────────────────┘    └────────┘           └────────┘
           16                    8

  = 16 × 8 × 16 = 2,048 multiply-adds in ONE instruction

  no thread holds a whole matrix: the tiles are spread across the
  registers of all 32 threads (each holds a few "fragments")

 published A100 peak:   f32 on regular cores    19.5 TFLOPS
                        f16 on tensor cores    312   TFLOPS   (16×)
```

## 🔧 In each tool

Real PTX from LLVM 23 (`llc -mcpu=sm_80` on
[samples/tensor_core_mma.ll](../samples/tensor_core_mma.ll), which calls
the intrinsic `llvm.nvvm.mma.m16n8k16.row.col.f32.f32`):

```
mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32
    {%r8, %r9, %r10, %r11},     ← D: this thread's 4 f32 results
    {%r1, %r2, %r3, %r4},       ← A: 4 registers, each 2 × f16
    {%r5, %r6},                 ← B: 2 registers, each 2 × f16
    {%r7, %r7, %r7, %r7};       ← C: accumulator (all zero here)
```

Reading the name: `m16n8k16` tile shape, `row.col` layouts of A and B,
`f32.f16.f16.f32` the types of D, A, B, C. `.sync.aligned` means all 32
threads of the warp must execute it together.

| Tool    | How you reach tensor cores                                                                                           |
| ------- | -------------------------------------------------------------------------------------------------------------------- |
| CUDA    | `wmma` / `mma` intrinsics, or libraries (cuBLAS, CUTLASS)                                                            |
| LLVM IR | `llvm.nvvm.mma.*` and `llvm.nvvm.wmma.*` intrinsics (above)                                                          |
| MLIR    | `nvgpu.mma.sync`, `nvvm.mma.sync`; higher up, `linalg.matmul` lowered by a GPU pipeline                              |
| Triton  | Write `tl.dot(a, b)` on tiles; the compiler emits `mma` (or `wgmma` on Hopper)                                       |
| Mojo    | MAX kernels use `mma` helpers from the `layout` / `linalg` packages; plain `a * b` on SIMD does not use tensor cores |
| Apple   | No tensor cores in the NVIDIA sense; Metal has `simdgroup_matrix` operations                                         |

## ⚠️ Common confusion

- **You cannot reach tensor cores with scalar code.** A matmul written as
  three nested loops of `+=` uses regular FP units, however well the loops
  are optimized. It has to be written as tile-level operations.
- **Precision matters.** Inputs are low-precision, and the accumulator is
  usually f32 to limit rounding error. Using f16 accumulation is faster
  but less accurate.
- **Shapes must fit the tile.** A matrix size that is not a multiple of
  16 needs padding or masking. That is one reason ML models prefer
  dimensions that are multiples of 8, 16, 64.

## 🔗 Related

- [Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md)
- [Triton programming model](../05-ml-compilers/triton-programming-model.md)
- [PTX, ptxas and SASS](../07-codegen-runtime/ptx-ptxas-and-sass.md)

---

✅ Verified against: LLVM 23.1.1 (PTX for `sm_80`; not run on an NVIDIA
GPU). TFLOPS are NVIDIA's published A100 figures.
