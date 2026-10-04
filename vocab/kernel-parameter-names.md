# Kernel Parameter Names 📛

> **One line:** Names a human picks in kernel code (`pid`, `offs`, `mask`,
> `BLOCK_SIZE`, `M N K`) are consistent only because everybody copies the
> same tutorials. They map one-to-one onto the five physics questions.

"Seen here" counts occurrences in [samples/](../samples/), [rosetta/](../rosetta/),
[real-world/](../real-world/), [maps/](../maps/) and
[05-ml-compilers/](../05-ml-compilers/). `—` means conventional but absent here.

## 🔢 Dimensions: what shape?

| Name                                     | Meaning                              | Used in                                           |
| ---------------------------------------- | ------------------------------------ | ------------------------------------------------- |
| `M`, `N`, `K`                            | Matmul: C is M×N, A is M×K, B is K×N | BLAS, CUTLASS, Triton, Mojo, MLIR `linalg.matmul` |
| `B` / `batch`                            | Batch dimension                      | PyTorch, attention kernels                        |
| `H`, `W`, `C`                            | Height, width, channels              | Vision models, NCHW/NHWC                          |
| `S` / `seq_len`                          | Sequence length                      | Attention                                         |
| `D` / `head_dim`                         | Per-head feature size                | Attention                                         |
| `n`, `n_elements`, `size`, `numel`       | Total element count                  | CUDA, Triton (`n_elements`), PyTorch (`numel`)    |
| `stride_am`, `stride_ak`, `stride_bk`... | Stride of matrix.dim                 | Triton matmul tutorial                            |
| `shape`, `strides`, `offset`             | Layout description                   | PyTorch, MLIR `memref`                            |

## 🧵 Parallel indices: who am I?

| Name                     | Meaning                                      | Seen here     |
| ------------------------ | -------------------------------------------- | ------------- |
| `pid`                    | Triton program id (`tl.program_id(axis=0)`)  | 7             |
| `tid`, `tx`              | Thread index inside a block                  | 13 (`%tid`)   |
| `bid`, `bx`, `ctaid`     | Block index in the grid                      | 13 (`%ctaid`) |
| `gid`, `global_idx`, `i` | Global thread index = block × blockDim + tid | —             |
| `lane`, `laneid`         | Position within a warp (0–31)                | —             |
| `warp`, `warp_id`        | Which warp inside the block                  | —             |
| `ntid`, `block_dim`      | Threads per block                            | 7, 14         |
| `nctaid`, `grid_dim`     | Blocks per grid                              | —, 3          |

The universal formula, in every language:

```
global_index = block_index * block_size + thread_index
Triton:  pid * BLOCK_SIZE + tl.arange(0, BLOCK_SIZE)      → offs
CUDA:    blockIdx.x * blockDim.x + threadIdx.x
Mojo:    block_idx.x * block_dim.x + thread_idx.x
PTX:     mad.lo.s32 %r, %ctaid.x, %ntid.x, %tid.x
```

## 📍 Addresses and bounds: where, and is it legal?

| Name                         | Meaning                                   | Seen here |
| ---------------------------- | ----------------------------------------- | --------- |
| `offs`, `offsets`            | Vector of element offsets for this block  | 15        |
| `offs_m`, `offs_n`, `offs_k` | Offsets along M, N, K                     | —         |
| `ptr`, `x_ptr`, `in_ptr0`    | Base pointer to a tensor                  | 4         |
| `a_ptrs`, `b_ptrs`           | Pointer blocks (`base + offsets`)         | —         |
| `mask`, `xmask`              | Boolean vector: which lanes are in bounds | —         |
| `other`                      | Fill value for masked-off lanes           | —         |
| `idx`, `i`, `j`, `k`         | Loop or element index                     | many      |
| `iv`, `indvars.iv`           | Induction variable                        | —         |

## 🧱 Block sizes and tuning knobs: how big a tile?

| Name                        | Meaning                                          | Seen here |
| --------------------------- | ------------------------------------------------ | --------- |
| `BLOCK_SIZE`, `BLOCK_M/N/K` | Tile edge, a `tl.constexpr`                      | —         |
| `XBLOCK`, `RBLOCK`          | Inductor's tile for elementwise / reduction axes | —         |
| `TILE`, `tile_size`         | Same idea in MLIR / Mojo                         | —         |
| `num_warps`, `num_stages`   | Triton tuning: warps per block, pipeline depth   | —         |
| `simd_width`, `width`       | Lane count of a vector                           | —         |
| `dtype`, `T`, `DType`       | Element type                                     | many      |
| `GROUP_SIZE_M`              | Program-id swizzle for L2 reuse                  | —         |

## 🧮 Values: accumulators and temporaries

| Name                        | Meaning                              | Seen here  |
| --------------------------- | ------------------------------------ | ---------- |
| `acc`, `accumulator`, `sum` | Running reduction / matmul tile      | 8 (`%acc`) |
| `a`, `b`, `c`               | Operands and result of a binary op   | 30, 26, 18 |
| `x`, `y`, `z`               | Input vectors / elementwise operands | 46, 28, 6  |
| `out`, `output`, `res`      | Result buffer                        | —          |
| `tmp0`, `tmp1`              | Inductor scalar temporaries          | 4          |
| `zero`, `one`, `cst`        | Named constants                      | 10, —, 8   |
| `x0`, `r1`                  | Inductor index variables             | 13         |

## 🔧 Triton vector-add, annotated

The tutorial kernel in five lines shows the whole table at work:

```python
@triton.jit
def add_kernel(x_ptr, y_ptr, out_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid  = tl.program_id(axis=0)                     # who am I?
    offs = pid * BLOCK_SIZE + tl.arange(0, BLOCK_SIZE)  # which elements?
    mask = offs < n_elements                         # in bounds?
    x = tl.load(x_ptr + offs, mask=mask)             # move in
    tl.store(out_ptr + offs, tl.load(y_ptr + offs, mask=mask) + x, mask=mask)  # move out
```

Questions answered: `pid` = parallelism, `offs` and `mask` = shape and
memory, `load`/`store` = memory, `+` = compute. See the full lowering in
[vector-add-in-5-irs](../rosetta/vector-add-in-5-irs.md).

## ⚠️ Common confusion

- **`M N K` order differs by library.** BLAS and Triton use C(M×N) = A(M×K)·B(K×N).
  Some papers rename K as the contraction axis; check the first comment.
- **`i`, `j`, `k` are loop order, not dimension names.** In `for i, j, k` the
  innermost loop is the last one, regardless of what the arrays call it.
- **`mask` means in-bounds in Triton, but "keep" in attention.** Attention's
  causal mask is a different thing with the same name.

## 🔗 Related

[gpu-thread-warp-block-grid](../04-hardware/gpu-thread-warp-block-grid.md) ·
[triton-programming-model](../05-ml-compilers/triton-programming-model.md) ·
[tiling](../03-transformations/tiling.md) ·
[memory-coalescing](../04-hardware/memory-coalescing.md)
