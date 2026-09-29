# A Tensor's Journey: `linalg.matmul` to PTX 🧳

> **One op, followed through every level of upstream MLIR down to NVIDIA
> PTX.** Every listing is real `mlir-opt` output (LLVM/MLIR 23.1.1), run on
> [samples/journey_matmul.mlir](../samples/journey_matmul.mlir).

## 🗺️ The route

```
 ① linalg.matmul                       "multiply these two 64×64 buffers"
        │ --convert-linalg-to-parallel-loops
 ② scf.parallel (i, j) + scf.for k     "the i, j iterations are independent"
        │ --gpu-map-parallel-loops --convert-parallel-loops-to-gpu
 ③ gpu.launch blocks(...) threads(...)  "run each (i, j) on the GPU"
        │ --lower-affine --gpu-kernel-outlining
 ④ gpu.module { gpu.func ... kernel }   host code and device code separated
        │ --gpu-lower-to-nvvm-pipeline="cubin-format=isa cubin-chip=sm_80"
 ⑤ llvm.func (host) + gpu.binary        device code compiled to PTX, embedded as a string
        │ (on a CUDA machine: ptxas / the driver)
 ⑥ SASS on the GPU
```

## ① The highest level

```mlir
func.func @matmul(%A: memref<64x64xf32>, %B: memref<64x64xf32>, %C: memref<64x64xf32>) {
  linalg.matmul ins(%A, %B : memref<64x64xf32>, memref<64x64xf32>)
                outs(%C : memref<64x64xf32>)
  return
}
```

One op. No loops, no indices. The compiler knows it is a matmul, which is
the most useful fact for optimizing it. Every lowering step below gives
some of that knowledge away.

## ② Loops, with parallelism marked

```mlir
scf.parallel (%arg3, %arg4) = (%c0, %c0) to (%c64, %c64) step (%c1, %c1) {
  scf.for %arg5 = %c0 to %c64 step %c1 {                  ← k: a reduction, stays sequential
    %0 = memref.load %arg0[%arg3, %arg5] : memref<64x64xf32>
    %1 = memref.load %arg1[%arg5, %arg4] : memref<64x64xf32>
    %2 = memref.load %arg2[%arg3, %arg4] : memref<64x64xf32>
    %3 = arith.mulf %0, %1 : f32
    %4 = arith.addf %2, %3 : f32
    memref.store %4, %arg2[%arg3, %arg4] : memref<64x64xf32>
  }
  scf.reduce
}
```

`scf.parallel` records that the `(i, j)` iterations are independent. The `k`
loop is a reduction into `C[i][j]`, so it stays an ordinary `scf.for`.

## ③ Mapped onto the GPU

```mlir
gpu.launch blocks(%arg3, %arg4, %arg5) in (%arg9 = %0, %arg10 = %1, %arg11 = %c1_0)
           threads(%arg6, %arg7, %arg8) in (%arg12 = %c1_0, %arg13 = %c1_0, %arg14 = %c1_0) {
  %2 = affine.apply #map1(%arg3)[%c1, %c0]
  %3 = affine.apply #map1(%arg4)[%c1, %c0]
  scf.for %arg15 = %c0 to %c64 step %c1 { ... }
  gpu.terminator
}
```

Read the sizes: **64 × 64 blocks of 1 thread each**. The default mapping
turned each `(i, j)` into its own block. That is correct but very slow:
a warp holds 32 threads, and every block here uses only one of them. A real
pipeline tiles first (so a block computes a tile of `C` with many threads),
which is exactly what [Triton](../05-ml-compilers/triton-programming-model.md)
makes you write explicitly.

## ④ Host and device split

```mlir
gpu.module @matmul_kernel {
  gpu.func @matmul_kernel(%arg0: index, %arg1: index, %arg2: memref<64x64xf32>, ...)
      kernel attributes {known_block_size = array<i32: 1, 1, 1>,
                         known_grid_size = array<i32: 64, 64, 1>} {
    %block_id_x = gpu.block_id x
    %block_id_y = gpu.block_id y
    ...
    scf.for %arg6 = %arg1 to %arg5 step %arg0 {
      %4 = memref.load %arg2[%1, %arg6] : memref<64x64xf32>
      ...
```

Kernel _outlining_ moved the launch body into its own function inside a
`gpu.module`, the device side. What remains in `@matmul` is the host side.

## ⑤ Host LLVM + embedded PTX

The host function now has **21 arguments** for 3 memrefs: each 2-D memref
expanded into 7 scalars (allocated pointer, aligned pointer, offset,
2 sizes, 2 strides). This is the memref ABI described in
[ABI and calling conventions](../07-codegen-runtime/abi-and-calling-conventions.md):

```mlir
llvm.func @matmul(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, ... %arg20: i64) {
  gpu.launch_func @matmul_kernel::@matmul_kernel blocks in (%1, %1, %2) threads in (%2, %2, %2) ...
```

The device side is a `gpu.binary` holding PTX. Decoded, the kernel's inner
loop:

```
.maxntid 1, 1, 1                        ← "at most 1 thread per block": the naive mapping
...
$L__BB0_2:                              ← the k loop
	ld.global.b32 	%r3, [%rd27];        A[i][k]
	ld.global.b32 	%r4, [%rd26];        B[k][j]
	mul.rn.f32 	%r5, %r3, %r4;
	add.rn.f32 	%r6, %r6, %r5;          ← C[i][j] kept in a register across k
	st.global.b32 	[%rd6], %r6;         ← ...but still stored every iteration
	add.s64 	%rd28, %rd28, %rd9;
	add.s64 	%rd27, %rd27, %rd7;
	add.s64 	%rd26, %rd26, %rd8;
	setp.lt.s64 	%p2, %rd28, %rd10;
	@%p2 bra 	$L__BB0_2;
```

Note `mul.rn` + `add.rn` stay separate (no `fma`): without a fast-math or
contraction flag, the compiler keeps IEEE rounding after each step.

## 🧭 What was lost, level by level

| Level      | Knows                                       | Forgot                              |
| ---------- | ------------------------------------------- | ----------------------------------- |
| `linalg`   | "this is a matmul", shapes, iteration kinds | —                                   |
| `scf`      | Loop bounds, which loops are parallel       | That it is a matmul                 |
| `gpu`      | Block/thread mapping                        | Which loops were parallel (now ids) |
| `llvm`/PTX | Instructions, addresses                     | Loops as structure (now branches)   |

This is why optimizations like tiling and tensor-core use are applied
**high** in the stack: once the IR is PTX, "this is a matmul" is gone.

## 🔗 Related

- [The whole stack](the-whole-stack.md)
- [Dialect](../02-ir-design/dialect.md)
- [Tiling](../03-transformations/tiling.md)
- [PTX, ptxas and SASS](../07-codegen-runtime/ptx-ptxas-and-sass.md)

---

✅ Verified against: MLIR 23.1.1 (`mlir-opt`, NVPTX target `sm_80`; PTX not run)
