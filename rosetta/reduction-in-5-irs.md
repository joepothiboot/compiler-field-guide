# Reduction (Sum) in 5 IRs ➕

> **One program, `s = x[0] + x[1] + ... + x[n-1]`, shown at each level.**
> A reduction is harder than vector add because every step depends on the
> previous one, unless you are allowed to reorder the additions. Reordering
> float additions changes the result, and every tool has to decide what it
> is allowed to do.

## 🖼️ The core problem

```
 IN ORDER (what the source says)          TREE / LANES (what's fast)
 ────────────────────────────────         ──────────────────────────
 s = ((((x0 + x1) + x2) + x3) + ...)      lane sums: (x0+x4+x8..) (x1+x5+x9..) ...
      one long dependency chain:          then combine the lanes
      each add waits for the previous     → many adds in flight at once

 float addition is NOT associative:  (a + b) + c  ≠  a + (b + c)  in general
 so the two orders give DIFFERENT results, and a compiler may not switch
 between them unless you allow it (fast-math, reassoc) or write it yourself
```

---

## 1️⃣ Triton: `tl.sum` over a block

Not run locally (no NVIDIA GPU). The pattern follows Triton's documentation:

```python
@triton.jit
def sum_kernel(x_ptr, out_ptr, n, BLOCK: tl.constexpr):
    pid = tl.program_id(0)
    offs = pid * BLOCK + tl.arange(0, BLOCK)
    x = tl.load(x_ptr + offs, mask=offs < n, other=0.0)   # masked lanes contribute 0
    tl.atomic_add(out_ptr, tl.sum(x, axis=0))              # one block sum per program
```

Each program reduces its block with `tl.sum`. Triton lowers that to
in-thread adds, warp shuffles and shared memory. The partial sums are then
combined with an atomic add, whose order across programs is **not
deterministic**, so results can vary slightly between runs.

## 2️⃣ Mojo: explicit SIMD accumulators (CPU)

Real run of [samples/reduce_sum.mojo](../samples/reduce_sum.mojo): 16.7 M
float32 values of `0.1`, three ways:

```mojo
def sum_scalar(x: List[Float32]) -> Float32:
    var s: Float32 = 0
    for i in range(N):
        s += p[unsafe_offset=i]              # in order: one dependency chain

def sum_simd(x: List[Float32]) -> Float32:
    var acc = SIMD[DType.float32, 16](0)     # 16 independent partial sums
    for i in range(0, N, 16):
        acc += p.unsafe_load[width=16](i)
    return acc.reduce_add()                  # combine lanes once at the end
```

```
scalar f32: 1935089.0    14 ms
simd   f32: 1694269.5     1 ms
float64   : 1677721.625             ← reference
```

- The SIMD version is **over 10× faster**: 16 independent chains instead of 1.
- It is also **more accurate** here (1% error vs 15%). Each lane's
  partial sum stays smaller, so less precision is lost per addition. The
  in-order float32 sum drifts badly once `s` is large compared with `0.1`.
- Mojo did not reorder the scalar loop for you. You chose the order.

On the GPU, the same pattern appears as a tree in shared memory
([samples/gpu_block_sum.mojo](../samples/gpu_block_sum.mojo)) and as warp
shuffles ([samples/gpu_warp_and_coalescing.mojo](../samples/gpu_warp_and_coalescing.mojo)).
Real PTX for `warp.sum`:

```
shfl.sync.bfly.b32 	%r4, %r3, 16, 31, -1;    ← swap with the thread 16 lanes away
add.f32 	%r5, %r3, %r4;
shfl.sync.bfly.b32 	%r6, %r5, 8, 31, -1;     ← then 8, 4, 2, 1: 5 steps for 32 values
add.f32 	%r7, %r5, %r6;
...
```

## 3️⃣ MLIR: a loop-carried value

[samples/reduce_sum.mlir](../samples/reduce_sum.mlir): `scf.for` carries the
running sum with `iter_args`:

```mlir
%s = scf.for %i = %c0 to %n step %c1 iter_args(%acc = %zero) -> (f32) {
  %v = memref.load %x[%i] : memref<?xf32>
  %next = arith.addf %acc, %v : f32
  scf.yield %next : f32                       ← becomes %acc in the next iteration
}
```

After `--convert-scf-to-cf` (real output), `iter_args` becomes a **block
argument** of the loop header, which is SSA's way of saying "this value
changes every iteration":

```mlir
    cf.br ^bb1(%c0, %cst : index, f32)             ← i = 0, acc = 0.0
  ^bb1(%0: index, %1: f32):  // 2 preds: ^bb0, ^bb2
    %2 = arith.cmpi slt, %0, %dim : index
    cf.cond_br %2, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1
    %3 = memref.load %arg0[%0] : memref<?xf32>
    %4 = arith.addf %1, %3 : f32
    %5 = arith.addi %0, %c1 : index
    cf.br ^bb1(%5, %4 : index, f32)                ← i + 1, acc + x[i]
  ^bb3:  // pred: ^bb1
    return %1 : f32
```

## 4️⃣ LLVM IR: what the vectorizer is allowed to do

[samples/reduce_sum.c](../samples/reduce_sum.c) at `-O2`. LLVM 23 **does**
vectorize the loop (`remark: vectorized loop (vectorization width: 4,
interleaved count: 4)`), but it keeps the additions **in order**, using
ordered reductions:

```llvm
%14 = phi float [ 0.000000e+00, %9 ], [ %26, %12 ]      ← ONE scalar running sum
%23 = tail call float @llvm.vector.reduce.fadd.v4f32(float %14, <4 x float> %19)
%24 = tail call float @llvm.vector.reduce.fadd.v4f32(float %23, <4 x float> %20)
%25 = tail call float @llvm.vector.reduce.fadd.v4f32(float %24, <4 x float> %21)
%26 = tail call float @llvm.vector.reduce.fadd.v4f32(float %25, <4 x float> %22)
```

The loads are vectorized, but each `reduce.fadd` (without a `reassoc`
flag) adds its 4 lanes into the running sum **sequentially**. The result
is bit-identical to the scalar loop.

With `-ffast-math`, LLVM may reassociate, and the loop changes shape: four
**vector** accumulators, like the Mojo SIMD version:

```llvm
%14 = phi <4 x float> [ zeroinitializer, %9 ], [ %26, %12 ]   ← 4 vector accumulators
%15 = phi <4 x float> [ zeroinitializer, %9 ], [ %27, %12 ]
%16 = phi <4 x float> [ zeroinitializer, %9 ], [ %28, %12 ]
%17 = phi <4 x float> [ zeroinitializer, %9 ], [ %29, %12 ]
%26 = fadd fast <4 x float> %22, %14
...
```

## 5️⃣ PTX: the warp-level tree

Shown in section 2 (`shfl.sync.bfly` + `add.f32`). A full GPU sum is three
levels: each thread sums its elements, the warp combines with shuffles, then
blocks combine through shared memory and/or atomics.

---

## 🔁 The same idea at each level

| Idea                  | Triton                    | Mojo                       | MLIR                     | LLVM IR                        | PTX               |
| --------------------- | ------------------------- | -------------------------- | ------------------------ | ------------------------------ | ----------------- |
| Running value         | implicit in `tl.sum`      | `var acc`                  | `iter_args` / block arg  | `phi`                          | register          |
| Parallel partial sums | per thread, per warp      | `SIMD[f32, 16]` lanes      | `vector.reduction`       | `<4 x float>` phis (fast-math) | per thread        |
| Combine               | `tl.sum`, `tl.atomic_add` | `reduce_add()`, `warp.sum` | `vector.reduction <add>` | `llvm.vector.reduce.fadd`      | `shfl.sync.bfly`  |
| Who picks the order   | Triton                    | **you**                    | the pass pipeline        | flags (`reassoc`/fast-math)    | the kernel author |

## 🔗 Related

- [Vectorization](../03-transformations/vectorization.md)
- [Shared memory and registers](../04-hardware/shared-memory-and-registers.md)
- [Loops in IR](../01-foundations/loops-in-ir.md): loop-carried values

---

✅ Verified against: LLVM/MLIR 23.1.1 · Mojo 1.1.0 (CPU run on Apple M2;
GPU PTX cross-compiled) · Triton: documentation, not run
