# Layout and Strides 📐

> **One line:** Memory is one long line, so a multi-dimensional tensor must
> be flattened. **Strides** say how many elements you skip to move one
> step along each dimension. Changing strides changes the layout without
> copying any data.

## 🌉 From frontend

CSS Grid lays out a 2-D grid of items in one DOM order. `grid-auto-flow:
row` vs `column` changes which neighbor comes next without changing the
items. Strides do the same for tensors: same numbers, different order in
memory, or a different _view_ of the same memory.

## 🖼️ Picture

```
 x = arange(12).reshape(3, 4)          memory (one line):
                                        [0][1][2][3][4][5][6][7][8][9][10][11]
   ┌ 0  1  2  3 ┐                        address of x[i][j] = i*4 + j*1
   │ 4  5  6  7 │   stride (4, 1)                             │     │
   └ 8  9 10 11 ┘                             row stride ─────┘     └─ column stride

 x.t()  (transpose: NO copy)            same memory, strides swapped:
   ┌ 0 4  8 ┐                            address of t[i][j] = i*1 + j*4
   │ 1 5  9 │   shape (4, 3)
   │ 2 6 10 │   stride (1, 4)            walking a row of t jumps 4 elements
   └ 3 7 11 ┘                            each time → not contiguous

 x[:, 1]  (a column: NO copy)           offset 1, stride (4,): [1, 5, 9]

 expand(3, 4) of [a b c d]  (NO copy)   stride (0, 1): every row re-reads the
                                        same 4 values ("broadcast")
```

## 🔧 In each tool

Real output of [samples/torch_strides.py](../samples/torch_strides.py)
(PyTorch 2.5.1):

```
x.shape       (3, 4)  x.stride() (4, 1)  contiguous: True
x.t().shape   (4, 3)  stride     (1, 4)  contiguous: False
same storage: True
t.contiguous() (4, 3)  stride     (3, 1)  same storage: False    ← .contiguous() copies
x[:, 1]       (3,)  stride     (4,)  offset: 1
expand(3,4)   (3, 4)  stride     (0, 1)  (0 = broadcast, no copy)
NCHW stride   (12, 4, 2, 1)   channels_last stride (12, 1, 6, 3)
```

The last line: an image batch of shape `[1, 3, 2, 2]` can be stored
**NCHW** (all red values, then all green, then all blue) or **NHWC**
("channels last", each pixel's R, G, B together). Same shape, different
strides. Convolutions on GPUs are often faster in NHWC.

| Tool          | How layout is expressed                                                                                                                                             |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PyTorch       | `stride()`, `storage_offset()`, `is_contiguous()`, `memory_format=`                                                                                                 |
| MLIR          | `memref<4x3xf32, strided<[1, 4]>>`, or an `affine_map` layout; `tensor` has no layout until bufferization                                                           |
| Triton        | You compute addresses yourself: `ptr + rows[:, None] * stride_m + cols[None, :] * stride_n`; `ttg` layouts (`#blocked`, `#mma`) describe how a tile maps to threads |
| Mojo/MAX      | `Layout` / `LayoutTensor` in the `layout` package: shape + stride as compile-time parameters, tiled layouts for kernels                                             |
| nano-dsp-mlir | Fixed layouts per op: `conv2d` is NHWC input × HWCF filter, documented in `DSPOps.td`                                                                               |

## ⚠️ Common confusion

- **"Contiguous" means row-major with no gaps**, i.e. strides are
  `(product of later sizes ..., 1)`. Views (transpose, slices, expand)
  are usually not contiguous, and many kernels need a copy first.
- **Stride 0 is legal** and means "repeat". That is how broadcasting
  works without allocating the bigger tensor.
- **Layout decides speed.** The fast loop must walk the stride-1
  dimension (see [Cache](../04-hardware/cache-and-memory-hierarchy.md) and
  [Memory coalescing](../04-hardware/memory-coalescing.md)).

## 🔗 Related

- [Tensor and shape](tensor-and-shape.md)
- [Types in MLIR](../02-ir-design/types.md): `strided<[...]>` memrefs
- [Memory coalescing](../04-hardware/memory-coalescing.md)

---

✅ Verified against: PyTorch 2.5.1 (CPU) · MLIR 23.1.1
