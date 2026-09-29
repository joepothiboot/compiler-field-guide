# SIMD and Vector Width 🧵

> **One line:** SIMD (single instruction, multiple data) registers hold
> several values side by side, called _lanes_. One instruction operates on
> all lanes at once. The number of lanes is the _vector width_, and it
> depends on the CPU and on the element size.

## 🌉 From frontend

CSS applies one rule to every matching element at once, not one element at a
time in a loop. A SIMD instruction applies one operation to every lane of a
register at once. The catch: every lane gets the **same** operation.

## 🖼️ Picture

A register has a fixed number of **bits**. Smaller types fit more lanes:

```
 Apple M2 NEON register: 128 bits
 ┌──────────────────────────────────────────────────────────────┐
 │ f32        │ f32        │ f32        │ f32        │   4 lanes │
 ├──────┬─────┴┬──────┬────┴─┬──────┬─────┴┬──────┬──────┤      │
 │ f16  │ f16  │ f16  │ f16  │ f16  │ f16  │ f16  │ f16  │ 8 lanes
 ├──┬──┬┴─┬──┬─┴┬──┬──┬┴─┬──┬┴─┬──┬─┴┬──┬──┬┴─┬──┬┴─┬──┤      │
 │i8│i8│i8│i8│i8│i8│i8│i8│i8│i8│i8│i8│i8│i8│i8│i8│    16 lanes │
 └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴─────────────┘

 x86 AVX2:    256 bits → 8 × f32        x86 AVX-512: 512 bits → 16 × f32
```

This is why lower precision (f16, int8) is faster for ML: the same
instruction processes 2× or 4× more values.

## 🔧 In each tool

Real output of [samples/simd_basics.mojo](../samples/simd_basics.mojo) on
this Apple M2:

```
native lanes  f32: 4  f16: 8  i8: 16
a      = [1.0, -2.0, 3.0, -4.0]
a + b  = [11.0, 8.0, 13.0, 6.0]        ← b = SIMD(10.0), a "splat" to all lanes
a * a  = [1.0, 4.0, 9.0, 16.0]
sum(a) = -2.0                          ← reduce_add: across lanes, horizontal
max(a) = 3.0
relu(a)= [1.0, 0.0, 3.0, 0.0]          ← lt(zeros).select(zeros, a): no branch
a[2]   = 3.0
```

The `relu` line matters: SIMD code avoids `if`. A comparison produces a
**mask** of true/false per lane, and `select` picks per lane. Both
sides are computed and the mask chooses, so there is no branch.

And in real machine code, from [Vectorization](../03-transformations/vectorization.md):

```asm
ldp     q0, q1, [x11, #-32]    ; q = a 128-bit register (4 floats)
fadd.4s v0, v0, v4             ; .4s = "4 single-precision lanes"
```

| Tool    | How you express SIMD                                                                                                      |
| ------- | ------------------------------------------------------------------------------------------------------------------------- |
| LLVM IR | Vector types `<4 x float>`; the backend maps them to NEON/AVX registers                                                   |
| MLIR    | `vector<4xf32>` and the `vector` dialect (`vector.reduction`, `vector.fma` …)                                             |
| Triton  | Implicit. Each thread's contiguous elements become vector loads (`ld.global.v4.f32` in PTX)                               |
| Mojo    | Explicit and first-class: `SIMD[DType.float32, 4]`. Every scalar is a width-1 SIMD: `Float32` is `SIMD[DType.float32, 1]` |

## ⚠️ Common confusion

- **CPU SIMD vs GPU SIMT.** A CPU SIMD instruction works on lanes of one
  register in one thread. A GPU runs 32 _threads_ in lockstep (a warp),
  each with its own registers. The effect is similar, the programming model
  is not. See [GPU thread / warp / block / grid](gpu-thread-warp-block-grid.md).
- **Horizontal operations are slower.** Lane-wise ops (`a + b`) are one
  instruction. Reductions across lanes (`reduce_add`) take several steps.
  Good kernels keep a SIMD accumulator in the loop and reduce once at the end.
- **Alignment and tails.** When the length is not a multiple of the width,
  a scalar tail loop handles the rest (see the Mojo code in
  [Vector add in 5 IRs](../rosetta/vector-add-in-5-irs.md)).

## 🔗 Related

- [Vectorization](../03-transformations/vectorization.md)
- [SIMD and DType (Mojo)](../06-mojo/simd-and-dtype.md)
- [Cache and memory hierarchy](cache-and-memory-hierarchy.md)

---

✅ Verified against: Mojo 1.1.0 · LLVM 23.1.1 (Apple M2)
