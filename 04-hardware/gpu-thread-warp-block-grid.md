# GPU Thread, Warp, Block, Grid 🔲

> **One line:** A GPU kernel runs as a **grid** of **blocks**; each block
> is a group of **threads** that can share fast memory; threads execute in
> lockstep groups of 32 called **warps**.

## 🌉 From frontend

Picture launching one Web Worker per array element, a million of them, all
running the same function with a different index. That is a GPU kernel. The
hardware groups them: workers in the same **block** can share a scratchpad
and wait for each other. Workers in different blocks cannot talk
during the kernel.

## 🖼️ Picture

```
 GRID (the whole launch: grid_dim blocks)
 ┌────────────────────────────────────────────────────────────┐
 │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
 │ │ block 0     │ │ block 1     │ │ block 2     │   ...      │
 │ │ ┌─────────┐ │ │             │ │             │            │
 │ │ │ warp 0  │ │ │  runs on    │ │  blocks run │            │
 │ │ │ t0..t31 │ │ │  any free   │ │  in any     │            │
 │ │ ├─────────┤ │ │  SM (core)  │ │  order      │            │
 │ │ │ warp 1  │ │ │             │ │             │            │
 │ │ │ t32..63 │ │ │             │ │             │            │
 │ │ ├─────────┤ │ │             │ │             │            │
 │ │ │  ...    │ │ │             │ │             │            │
 │ │ └─────────┘ │ │             │ │             │            │
 │ │ shared mem  │ │ shared mem  │ │ shared mem  │            │
 │ └─────────────┘ └─────────────┘ └─────────────┘            │
 └────────────────────────────────────────────────────────────┘

 my global index = block_idx.x * block_dim.x + thread_idx.x

 thread : one instance of the kernel, with its own registers
 warp   : 32 threads that execute the same instruction together (NVIDIA)
 block  : up to 1024 threads; share shared memory; can barrier()
 grid   : all blocks; no sync between blocks inside one kernel
```

## 🔧 In each tool

**Mojo** (compiled to PTX for `sm_80` with
[scripts/mojo-ptx.sh](../scripts/mojo-ptx.sh), from
[samples/gpu_vadd.mojo](../samples/gpu_vadd.mojo)):

```mojo
def vadd_kernel(a: Pointer[Float32, MutAnyOrigin], b: ..., c: ..., n: Int32):
    var i = Int(block_idx.x * block_dim.x + thread_idx.x)
    if i < Int(n):
        c[unsafe_offset=i] = a[unsafe_offset=i] + b[unsafe_offset=i]

# launch: 1000 elements, 256 threads per block → 4 blocks (the last one is partly idle)
ctx.enqueue_function[vadd_kernel](a, b, c, Int32(N), grid_dim=4, block_dim=256)
```

The resulting PTX reads the three indices from special registers:

```
mov.u32     %r1, %ctaid.x;      ← block_idx.x   (CTA = "cooperative thread array" = block)
mov.u32     %r2, %ntid.x;       ← block_dim.x
mul.wide.u32 %rd11, %r1, %r2;
mov.u32     %r3, %tid.x;        ← thread_idx.x
add.s64     %rd13, %rd11, %rd12;
setp.ge.s64 %p1, %rd13, %rd10;  ← i >= n ?  then skip
```

| Concept | CUDA / PTX                    | Mojo (`max.gpu`)           | Triton                              | Apple Metal (this Mac's GPU)  |
| ------- | ----------------------------- | -------------------------- | ----------------------------------- | ----------------------------- |
| Thread  | thread, `%tid`                | `thread_idx`               | Hidden: you write per-block code    | thread                        |
| Warp    | warp (32)                     | `warp` module, `WARP_SIZE` | Hidden; `num_warps` per program     | SIMD-group (32)               |
| Block   | block / CTA, `%ctaid`         | `block_idx`, `block_dim`   | **program**, `tl.program_id`        | threadgroup                   |
| Grid    | grid                          | `grid_dim`                 | the launch grid `kernel[grid](...)` | grid                          |
| Core    | SM (streaming multiprocessor) | —                          | —                                   | GPU core (the M2 here has 10) |

Local facts from `gpu-query` (ships with MAX) on this Mac: Apple M2 GPU,
10 cores, max 1024 threads per block, 32 KB shared memory per block.

## ⚠️ Common confusion

- **A Triton "block" is not a CUDA block of threads.** In Triton,
  `BLOCK_SIZE` is the size of the **data tile** one program handles. The
  number of threads is `num_warps × 32`, chosen separately.
- **Warp divergence.** If threads in one warp take different sides of an
  `if`, the warp runs **both** sides, masking off threads. Branches that
  split warps are slow.
- **No global sync inside a kernel.** Blocks cannot wait for each other.
  To combine results across blocks, launch a second kernel or use atomics.

## 🔗 Related

- [Shared memory and registers](shared-memory-and-registers.md)
- [Triton programming model](../05-ml-compilers/triton-programming-model.md)
- [Vector add in 5 IRs](../rosetta/vector-add-in-5-irs.md)

---

✅ Verified against: Mojo 1.1.0 + MAX 26.6 (PTX cross-compiled for `sm_80`;
not run on an NVIDIA GPU) · Triton: from its docs, not run locally
