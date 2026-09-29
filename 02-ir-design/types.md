# Types in MLIR 🧮

> **One line:** Every SSA value has a type, and the type says **what kind of
> data** it is: a scalar (`i32`, `f32`), a SIMD vector (`vector<4xf32>`), an
> immutable array value (`tensor`) or a buffer in memory (`memref`).

## 🌉 From frontend

In JS, `Float32Array` (a buffer you can write to) and a frozen array of
numbers (a value) are different things, even though they hold the same
data. MLIR makes the same distinction at the type level: `tensor` is the
value, and `memref` is the buffer.

## 🖼️ Picture

```
 SCALARS          i1  i8  i32  i64      index (target-sized integer, for sizes/loops)
                  f16  bf16  f32  f64

 VECTOR           vector<4xf32>           fixed size, lives in SIMD registers
                  ┌────┬────┬────┬────┐
                  │ f32│ f32│ f32│ f32│   one register, one instruction for all 4
                  └────┴────┴────┴────┘

 TENSOR           tensor<4x?xf32>         a VALUE: immutable, no address
                                          ? = size known only at runtime
                  "a 4-by-something grid of numbers"
                  operations return NEW tensors (like immutable JS updates)

 MEMREF           memref<4x8xf32>         a BUFFER: has an address, can be stored to
                  ┌─────────────────┐     memref<4x8xf32, strided<[1, 4]>>
                  │ base pointer    │       = same shape, column-major: the next
                  │ offset          │         row (dim 0) is 1 element away, the
                  │ sizes   [4, 8]  │         next column (dim 1) is 4 away
                  │ strides [8, 1]  │     (default layout: row-major, strides [8, 1])
                  └─────────────────┘
```

Real, verified: all of these parse in [samples/types.mlir](../samples/types.mlir):

```mlir
func.func @types(%arg0: i32, %arg1: index, %arg2: f32, %arg3: f16, %arg4: bf16,
                 %arg5: vector<4xf32>, %arg6: tensor<4x?xf32>,
                 %arg7: memref<4x8xf32>,
                 %arg8: memref<4x8xf32, strided<[1, 4]>>)
```

## 🔧 In each tool

| Idea         | LLVM IR                   | MLIR                 | Triton                                     | Mojo                                                |
| ------------ | ------------------------- | -------------------- | ------------------------------------------ | --------------------------------------------------- |
| Scalar int   | `i32`                     | `i32`, `index`       | `tl.int32`                                 | `Int32`, `Int` (64-bit)                             |
| Scalar float | `float`, `half`, `bfloat` | `f32`, `f16`, `bf16` | `tl.float32`, `tl.bfloat16`                | `Float32`, `Float16`, `BFloat16`                    |
| SIMD vector  | `<4 x float>`             | `vector<4xf32>`      | Implicit (tiles are spread across threads) | `SIMD[DType.float32, 4]`                            |
| Array value  | —                         | `tensor<...>`        | A block of values (`tl.load` result)       | —                                                   |
| Buffer       | `ptr` (no shape at all)   | `memref<...>`        | Pointer + offsets                          | `UnsafePointer` / `Pointer`, `List`, `LayoutTensor` |

LLVM's `ptr` is the lowest level: an address with no element type and no
shape. When `memref` is lowered to LLVM, it becomes a small struct
(pointer, offset, sizes, strides), called a _memref descriptor_.

## ⚠️ Common confusion

- **`tensor` is not "on the GPU".** It is just an immutable value in the
  IR. Where it ends up is decided later, by bufferization.
- **`vector` is not a variable-length list.** It is fixed-size and meant
  for SIMD registers. A long array is a `tensor` or `memref`.
- **`?` vs static sizes.** `tensor<4x8xf32>` lets the compiler fully unroll
  and pick exact tile sizes. `tensor<?x?xf32>` needs runtime checks. Static
  shapes are faster, which is why JIT compilers specialize on shapes.

## 🔗 Related

- [TypeScript types vs IR types](../00-bridge/typescript-types-vs-ir-types.md)
- [Tensor and shape](../05-ml-compilers/tensor-and-shape.md)
- [Layout and strides](../05-ml-compilers/layout-and-strides.md)
- [Bufferization](../03-transformations/bufferization.md)

---

✅ Verified against: MLIR 23.1.1
