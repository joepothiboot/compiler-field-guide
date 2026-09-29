# Memory Coalescing 🚚

> **One line:** When the 32 threads of a warp load from **neighboring
> addresses**, the hardware combines them into a few wide memory
> transactions. When they load from scattered addresses, each needs its
> own transaction, and the memory bandwidth drops sharply.

## 🌉 From frontend

Batching API requests: 32 `GET /item/:id` calls for items 1..32 are slow;
one `GET /items?ids=1..32` is fast. The GPU memory system does that
batching automatically, but **only** when the addresses are contiguous.

## 🖼️ Picture

```
 COALESCED: thread t reads src[t]           STRIDED: thread t reads src[t * 32]
 ────────────────────────────────           ──────────────────────────────────
 t0 t1 t2 ... t31                           t0          t1          t2
 │  │  │      │                             │           │           │
 ▼  ▼  ▼      ▼                             ▼           ▼           ▼
 [f][f][f]...[f]   ← one 128-byte chunk     [f.........][f.........][f....  ...
                                             128 B apart: every thread's
 1 memory transaction for the warp           float is in a different chunk

                                            32 transactions; 31/32 of each
                                            fetched chunk is wasted
```

## 🔧 In each tool

Two Mojo kernels in
[samples/gpu_warp_and_coalescing.mojo](../samples/gpu_warp_and_coalescing.mojo)
differ by one expression:

```mojo
def copy_coalesced(src: ..., dst: ...):
    var i = Int(block_idx.x * block_dim.x + thread_idx.x)
    dst[unsafe_offset=i] = src[unsafe_offset=i]

def copy_strided(src: ..., dst: ...):
    var i = Int(block_idx.x * block_dim.x + thread_idx.x)
    dst[unsafe_offset=i] = src[unsafe_offset=i * 32]
```

In the real PTX (`sm_80`) the only difference is the shift that turns the
index into a byte offset:

```
copy_coalesced:                       copy_strided:
  shl.b64  %rd8, %rd7, 2;               shl.b64  %rd8, %rd7, 2;    (dst offset)
  add.s64  %rd10, %rd4, %rd8;           shl.b64  %rd10, %rd7, 7;   (src offset)
  ld.global.b32 %r4, [%rd10];           add.s64  %rd11, %rd4, %rd10;
                                        ld.global.b32 %r4, [%rd11];

  shl 2 = × 4 bytes                     shl 7 = × 128 bytes
  (neighbors: 4 B apart)                (neighbors: 128 B apart)
```

The instruction is identical. The cost difference comes entirely from the
memory system at runtime, so it does not show in the code. You have to
know the rule, or profile (NVIDIA Nsight Compute reports "sectors per
request").

| Tool        | Who handles coalescing                                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------ |
| CUDA / Mojo | You: index with `thread_idx.x` on the contiguous dimension                                                                     |
| Triton      | Mostly the compiler: its layouts (`#blocked` in `ttg`) assign contiguous elements to neighboring threads and emit vector loads |
| MLIR        | GPU mapping passes choose which loop dimension becomes `thread_idx.x`                                                          |

## ⚠️ Common confusion

- **The "fast dimension" must map to `thread_idx.x`.** For a row-major
  matrix, consecutive threads should walk along a row (the last index),
  not down a column.
- **Transposes are the classic hard case**: reading rows means writing
  columns. The standard fix is to go through
  [shared memory](shared-memory-and-registers.md): load a tile coalesced,
  then write it out coalesced in the other order.
- **CPU caches have the same rule**, as the
  [cache page](cache-and-memory-hierarchy.md) benchmark shows. GPUs are
  just much more sensitive to it.

## 🔗 Related

- [Cache and memory hierarchy](cache-and-memory-hierarchy.md)
- [Layout and strides](../05-ml-compilers/layout-and-strides.md)
- [GPU thread, warp, block, grid](gpu-thread-warp-block-grid.md)

---

✅ Verified against: Mojo 1.1.0 + MAX 26.6 (PTX cross-compiled for `sm_80`;
performance behavior from NVIDIA's documentation, not measured here)
