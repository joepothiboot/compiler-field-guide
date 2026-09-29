# Tensor and Shape 📦

> **One line:** A tensor is an n-dimensional array of one element type. Its
> **shape** lists the size of each dimension. Whether those sizes are known
> at compile time (_static_) or only at runtime (_dynamic_) changes what a
> compiler can do with it.

## 🌉 From frontend

A tensor is like a typed, multi-dimensional `Float32Array` with a
`shape` field: `[3, 4]` means 3 rows of 4 numbers. Image data in a
`<canvas>` (`ImageData`) is a real example: shape `[height, width, 4]`
(RGBA), stored flat in one buffer.

## 🖼️ Picture

```
 rank 0   scalar        shape []          5.0
 rank 1   vector        shape [4]         [1, 2, 3, 4]
 rank 2   matrix        shape [3, 4]      ┌ 0  1  2  3 ┐
                                          │ 4  5  6  7 │
                                          └ 8  9 10 11 ┘
 rank 4   image batch   shape [N, C, H, W]   e.g. [32, 3, 224, 224]
                                             32 images, 3 channels (RGB), 224×224

 STATIC vs DYNAMIC shape (MLIR notation)
   tensor<3x4xf32>     all sizes known when compiling → exact loop bounds,
                       full unrolling, no bounds checks
   tensor<?x4xf32>     first size known only at runtime (e.g. batch size)
   tensor<*xf32>       even the rank is unknown (rare, avoided by compilers)
```

## 🔧 In each tool

| Tool            | Tensor type                                                 | Shape info                                                                             |
| --------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| PyTorch         | `torch.Tensor`                                              | `x.shape`, `x.dtype`, `x.device`; eager tensors always have concrete shapes            |
| `torch.compile` | FX graph nodes annotated `f32[1024]`                        | Specializes on the shapes it sees; recompiles, or marks dims dynamic, when they change |
| MLIR            | `tensor<3x?xf32>` (value), `memref<...>` (buffer)           | `?` for dynamic dims; `tensor.dim` reads one at runtime                                |
| Triton          | No tensor type in the kernel: pointers + a block of offsets | Sizes passed as arguments; block sizes are `tl.constexpr`                              |
| Mojo/MAX        | `LayoutTensor` (kernels), `max` graph tensors               | Layout can be static (compile-time parameters) or partly dynamic                       |

Real `torch.compile` output ([samples/torch_compile_demo.py](../samples/torch_compile_demo.py))
shows the shape and stride in each graph node's annotation:

```python
def forward(self, L_a_: "f32[1024][1]cpu", L_b_: "f32[1024][1]cpu"):
    add: "f32[1024][1]cpu" = l_a_ + l_b_
#          ─┬─ ──┬─ ─┬─ ─┬─
#      dtype  shape  stride  device
```

## ⚠️ Common confusion

- **"Tensor" in ML ≠ the physics/math tensor.** In ML it just means
  n-dimensional array.
- **Shape vs layout.** Shape is the logical size. Layout is how the elements
  are placed in memory. Two tensors can share a shape and have different
  layouts. See [Layout and strides](layout-and-strides.md).
- **Dynamic shapes cost performance**, which is why JIT compilers like
  `torch.compile` and Triton specialize on the actual shapes, and
  recompile when shapes change.

## 🔗 Related

- [Types in MLIR](../02-ir-design/types.md)
- [Layout and strides](layout-and-strides.md)
- [Bufferization](../03-transformations/bufferization.md)

---

✅ Verified against: PyTorch 2.5.1 (CPU) · MLIR 23.1.1
