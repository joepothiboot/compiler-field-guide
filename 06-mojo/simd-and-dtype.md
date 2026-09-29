# SIMD and DType 🧮

> **One line:** `SIMD[dtype, width]` is Mojo's core numeric type: a fixed-size
> vector of `width` elements of type `dtype`, mapped directly onto hardware
> SIMD registers. Every scalar is a width-1 SIMD (`Float32` is
> `SIMD[DType.float32, 1]`).

## 🌉 From frontend

`DType` is like the element type of a typed array (`Float32Array`,
`Int8Array`): it says how to interpret the bits. `SIMD[DType.float32, 4]` is
like a fixed-length `Float32Array(4)` where `a + b` adds all four elements
in one CPU instruction instead of a loop.

## 🖼️ Picture

```
 DType (element type)         SIMD[dtype, width]
 ────────────────────         ──────────────────
 DType.float32   4 bytes      SIMD[DType.float32, 4]   = one 128-bit NEON register
 DType.float16   2 bytes      SIMD[DType.float16, 8]   = one 128-bit register
 DType.bfloat16  2 bytes      SIMD[DType.float32, 16]  = four registers (the compiler splits it)
 DType.int8      1 byte       Float32 == SIMD[DType.float32, 1] == Scalar[DType.float32]
 DType.bool      1 bit*

 operations are lane-wise:          reductions go across lanes:
 [1, -2, 3, -4] + [10]*4            reduce_add([1, -2, 3, -4]) = -2
 = [11, 8, 13, 6]                   reduce_max(...) = 3
```

## 🔧 In each tool

Real run of [samples/simd_basics.mojo](../samples/simd_basics.mojo) on this M2:

```mojo
comptime f32_width = simd_width_of[DType.float32]()
var a = SIMD[DType.float32, 4](1.0, -2.0, 3.0, -4.0)
var b = SIMD[DType.float32, 4](10.0)          # splat
var zeros = SIMD[DType.float32, 4](0)
print("relu(a)=", a.lt(zeros).select(zeros, a))   # branch-free per-lane choice
```

```
native lanes  f32: 4  f16: 8  i8: 16
a      = [1.0, -2.0, 3.0, -4.0]
a + b  = [11.0, 8.0, 13.0, 6.0]
a * a  = [1.0, 4.0, 9.0, 16.0]
sum(a) = -2.0
max(a) = 3.0
relu(a)= [1.0, 0.0, 3.0, 0.0]
a[2]   = 3.0
```

And in a real kernel (nano-dsp-mlir's `mojo/nanodsp/kernels.mojo`), the
standard pattern: a SIMD body at native width, then a scalar tail:

```mojo
comptime width = simd_width_of[dtype]()
var i = 0
while i + width <= n:
    pr.unsafe_store(i, pa.unsafe_load[width=width](i) + pb.unsafe_load[width=width](i))
    i += width
while i < n:
    pr[unsafe_offset=i] = pa[unsafe_offset=i] + pb[unsafe_offset=i]
    i += 1
```

The register-blocked matmul in
[samples/matmul_cpu.mojo](../samples/matmul_cpu.mojo) uses
`SIMD[DType.float32, 16]` accumulators (4 NEON registers each), which is
what took it from 42 ms to 3 ms at 512×512.

| Concept     | Mojo                          | LLVM IR                   | MLIR                     | C++ (Clang)                                 |
| ----------- | ----------------------------- | ------------------------- | ------------------------ | ------------------------------------------- |
| Vector type | `SIMD[DType.float32, 4]`      | `<4 x float>`             | `vector<4xf32>`          | `float __attribute__((ext_vector_type(4)))` |
| Load vector | `ptr.unsafe_load[width=4](i)` | `load <4 x float>`        | `vector.load`            | intrinsics / `memcpy`                       |
| Lane select | `mask.select(a, b)`           | `select <4 x i1>`         | `arith.select`           | `? :` on vector types                       |
| Reduce      | `reduce_add()`                | `llvm.vector.reduce.fadd` | `vector.reduction <add>` | loops or intrinsics                         |

## ⚠️ Common confusion

- **`width` must be a power of two** and is a compile-time parameter.
  Widths larger than the hardware's are legal: the compiler splits them into
  several registers (as with the 16-wide accumulators above).
- **Comparisons return a SIMD of bools**, not a single `Bool`: `a.lt(b)`
  is a per-lane mask. Use `select`, or reduce it with `reduce_and()` /
  `reduce_or()`. Real output for `[1,2,3,4].lt(3)`:
  `[True, True, False, False] False True`.
- **`Float32` and `Float64` in Mojo are SIMD types**, so the same
  generic code handles scalars and vectors. This is one of the
  design choices that makes Mojo's stdlib generic.

## 🔗 Related

- [SIMD and vector width (hardware)](../04-hardware/simd-and-vector-width.md)
- [Vectorization](../03-transformations/vectorization.md)
- [Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md)

---

✅ Verified against: Mojo 1.1.0 (run locally) · nano-dsp-mlir `850be64`
