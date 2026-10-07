# Triton Programming Model 🔱

> **One line:** In Triton you write a kernel for **one program**, which
> handles one **block** (tile) of data using whole-block operations
> (`tl.load`, `+`, `tl.dot`, `tl.sum`). The compiler decides how the block
> is spread across the GPU's threads, and handles coalescing and shared memory.

## 🖼️ Picture

```
 CUDA mindset: one THREAD, one element     Triton mindset: one PROGRAM, one BLOCK
 ─────────────────────────────────────     ──────────────────────────────────────
 i = blockIdx.x*blockDim.x + threadIdx.x   pid  = tl.program_id(0)
 if i < n:                                 offs = pid*BLOCK + tl.arange(0, BLOCK)
     c[i] = a[i] + b[i]                    mask = offs < n
                                           a = tl.load(a_ptr + offs, mask=mask)
                                           b = tl.load(b_ptr + offs, mask=mask)
                                           tl.store(c_ptr + offs, a + b, mask=mask)

 grid = number of programs = cdiv(n, BLOCK)

 program 0          program 1          program 2          program 3
 [■■■■■■■■]         [■■■■■■■■]         [■■■■■■■■]         [■■■■····]  ← mask
   offs = 0..7        offs = 8..15       ...                 hides 4 slots

 inside one program, Triton picks: num_warps × 32 threads,
 which thread holds which elements, vector widths, shared memory
```

## 🔧 In each tool

Triton's matmul core (the pattern from the official matmul tutorial). Not
run locally, because Triton has no macOS build and this Mac has no NVIDIA GPU:

```python
@triton.jit
def matmul_kernel(a_ptr, b_ptr, c_ptr, M, N, K,
                  stride_am, stride_ak, stride_bk, stride_bn, stride_cm, stride_cn,
                  BLOCK_M: tl.constexpr, BLOCK_N: tl.constexpr, BLOCK_K: tl.constexpr):
    pid_m = tl.program_id(0)
    pid_n = tl.program_id(1)
    rm = pid_m * BLOCK_M + tl.arange(0, BLOCK_M)
    rn = pid_n * BLOCK_N + tl.arange(0, BLOCK_N)
    rk = tl.arange(0, BLOCK_K)
    a_ptrs = a_ptr + rm[:, None] * stride_am + rk[None, :] * stride_ak
    b_ptrs = b_ptr + rk[:, None] * stride_bk + rn[None, :] * stride_bn
    acc = tl.zeros((BLOCK_M, BLOCK_N), dtype=tl.float32)
    for k in range(0, K, BLOCK_K):
        a = tl.load(a_ptrs, mask=rk[None, :] < K - k, other=0.0)
        b = tl.load(b_ptrs, mask=rk[:, None] < K - k, other=0.0)
        acc += tl.dot(a, b)                      # → tensor cores (mma) on NVIDIA
        a_ptrs += BLOCK_K * stride_ak
        b_ptrs += BLOCK_K * stride_bk
    c = acc.to(tl.float16)
    c_ptrs = c_ptr + rm[:, None] * stride_cm + rn[None, :] * stride_cn
    tl.store(c_ptrs, c, mask=(rm[:, None] < M) & (rn[None, :] < N))
```

Compare it with the Mojo CPU register-blocked matmul in
[Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md): the
same structure (an output tile, an accumulator, a loop over K in blocks), at a
higher level.

The compile pipeline, per the Triton source (NVIDIA backend):

```
 Python AST ──► ttir  (tt dialect: tile ops)
            ──► ttgir (ttg dialect: tiles + layouts, pipelining, mma selection)
            ──► llir  (LLVM IR)  ──► ptx ──► cubin (via ptxas)
```

| Concept      | Triton                                       | CUDA / Mojo equivalent        |
| ------------ | -------------------------------------------- | ----------------------------- |
| Program      | `tl.program_id(axis)`                        | Thread block, `block_idx`     |
| Block / tile | `tl.arange(0, BLOCK)`, `BLOCK: tl.constexpr` | Hand-written per-thread loops |
| Mask         | `mask=` on load/store                        | `if i < n`                    |
| Threads      | `num_warps` (launch option)                  | `block_dim`                   |
| Pipelining   | `num_stages`                                 | Hand-written double buffering |
| Matmul unit  | `tl.dot`                                     | `mma` / `wgmma` instructions  |
| Reduction    | `tl.sum(x, axis=0)`                          | Shared memory + warp shuffles |

## ⚠️ Common confusion

- **`BLOCK` is a data size, not a thread count.** `BLOCK=1024` with
  `num_warps=4` means 128 threads handle 1024 elements, 8 each.
- **`tl.constexpr` is a compile-time parameter.** Each new value compiles a
  new kernel, like a Mojo parameter. That is what lets the compiler fully
  unroll and pick layouts.
- **Shapes in `tl.arange` must be powers of two.** Pad with masks for
  other sizes.

## 🔗 Related

- [GPU thread, warp, block, grid](../04-hardware/gpu-thread-warp-block-grid.md)
- [Tensor cores](../04-hardware/tensor-cores.md)
- [Autotuning](autotuning.md)
- [Triton codebase tour](../real-world/triton-tour.md)

---

✅ Verified against: Triton's official tutorials and source layout; **not
run locally** (no NVIDIA GPU, no macOS build)
