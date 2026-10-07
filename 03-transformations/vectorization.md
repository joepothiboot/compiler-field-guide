# Vectorization ➡️

> **One line:** Vectorization rewrites a loop that handles one element per
> step into one that handles several elements per step with SIMD
> instructions, plus a leftover (_remainder_ or _tail_) loop for the end.

## 🖼️ Picture

```
 SCALAR: 1 add per instruction          SIMD (NEON, 128-bit): 4 adds per instruction
 ┌────┐   ┌────┐   ┌────┐               ┌────┬────┬────┬────┐
 │ a0 │ + │ b0 │ = │ c0 │               │ a0 │ a1 │ a2 │ a3 │  v0
 └────┘   └────┘   └────┘               └────┴────┴────┴────┘
 ┌────┐   ┌────┐   ┌────┐                        +
 │ a1 │ + │ b1 │ = │ c1 │               ┌────┬────┬────┬────┐
 └────┘   └────┘   └────┘               │ b0 │ b1 │ b2 │ b3 │  v1
   ... 4 instructions                   └────┴────┴────┴────┘
                                                 = fadd.4s v0, v0, v1
                                        ┌────┬────┬────┬────┐
                                        │ c0 │ c1 │ c2 │ c3 │  1 instruction
                                        └────┴────┴────┴────┘
```

## 🔧 In each tool

**LLVM's loop vectorizer** on [samples/vadd.c](../samples/vadd.c) at `-O2`.
It reports `vectorized loop (vectorization width: 4, interleaved count: 4)`.
The real Apple M2 assembly contains **three** versions of the loop:

```asm
LBB0_10:                          ; main loop: 16 floats per iteration
	ldp	q0, q1, [x11, #-32]       ;   (4 registers × 4 floats)
	ldp	q2, q3, [x11], #64
	ldp	q4, q5, [x12, #-32]
	ldp	q6, q7, [x12], #64
	fadd.4s	v0, v0, v4
	fadd.4s	v1, v1, v5
	fadd.4s	v2, v2, v6
	fadd.4s	v3, v3, v7
	stp	q0, q1, [x13, #-32]
	stp	q2, q3, [x13], #64
	subs	x14, x14, #16
	b.ne	LBB0_10

LBB0_14:                          ; epilogue: 4 floats per iteration
	ldr	q0, [x13], #16
	ldr	q1, [x12], #16
	fadd.4s	v0, v0, v1
	str	q0, [x11], #16
	...

LBB0_5:                           ; scalar remainder: 1 float per iteration
	ldr	s0, [x12], #4
	ldr	s1, [x11], #4
	fadd	s0, s0, s1
	str	s0, [x10], #4
```

Before the vector loops, the function also checks at runtime whether `c`
overlaps `a` or `b` (the `sub`, `cmn` and `ccmp` instructions). In C, the
pointers might alias, and if they do, only the scalar loop is correct.

**MLIR's vectorizer**. Real `mlir-opt --affine-super-vectorize="virtual-vector-size=4"`
on [samples/vadd_affine.mlir](../samples/vadd_affine.mlir):

```mlir
affine.for %arg3 = 0 to 1024 step 4 {
  %1 = vector.transfer_read %arg0[%arg3], %0 {in_bounds = [true]} : memref<1024xf32>, vector<4xf32>
  %3 = vector.transfer_read %arg1[%arg3], %2 {in_bounds = [true]} : memref<1024xf32>, vector<4xf32>
  %4 = arith.addf %1, %3 : vector<4xf32>
  vector.transfer_write %4, %arg2[%arg3] {in_bounds = [true]} : vector<4xf32>, memref<1024xf32>
}
```

No remainder loop is needed here, because 1024 is a multiple of 4 and the
size is static. That is one benefit of static shapes.

| Tool   | Vectorization                                                                                                           |
| ------ | ----------------------------------------------------------------------------------------------------------------------- |
| LLVM   | Automatic: loop vectorizer and SLP vectorizer (merges independent scalar ops)                                           |
| MLIR   | `vector` dialect; `linalg` vectorization via the transform dialect; affine super-vectorizer                             |
| Triton | Implicit: tiles are spread across threads, and each thread's elements become vector loads when addresses are contiguous |
| Mojo   | **Explicit**: `SIMD[dtype, width]`, `load[width=...]`, plus `vectorize` in `std.algorithm`. You decide, not a heuristic |

## ⚠️ Common confusion

- **Auto-vectorization is fragile.** Aliasing, unknown trip counts, function
  calls or branches in the loop can stop it. Mojo's explicit SIMD avoids
  depending on the heuristic, which is one reason Mojo kernels are written
  that way.
- **Vector width is a hardware property.** NEON (Apple M-series) is 128-bit
  = 4 floats. AVX-512 is 512-bit = 16 floats. Mojo's
  `simd_width_of[DType.float32]()` returns the right number per machine.
- **"Interleaved count 4"** means the vectorizer also unrolled the vector
  loop 4 times, to keep more independent operations in flight.

## 🔗 Related

- [SIMD and vector width](../04-hardware/simd-and-vector-width.md)
- [SIMD and DType (Mojo)](../06-mojo/simd-and-dtype.md)

---

✅ Verified against: LLVM/MLIR 23.1.1 (Apple M2)
