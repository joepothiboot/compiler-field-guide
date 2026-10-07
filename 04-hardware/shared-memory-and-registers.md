# Shared Memory and Registers 🗄️

> **One line:** Each GPU thread has private **registers** (fastest). Threads
> in one block share a small, fast, manually managed scratchpad called
> **shared memory**. Everything else lives in slow **global memory**.

## 🖼️ Picture

```
 per THREAD        registers            fastest; private; limited count
                        │
 per BLOCK         shared memory        ~100× faster than global; you manage it;
                   (32 KB on this M2,    visible to all threads of the block
                    up to 164 KB/SM on A100)
                        │
 per GPU           L2 cache             automatic
                        │
                   global memory (HBM / DRAM)   large, slow; kernel arguments live here

 tree reduction of 256 values in shared memory:

 step 1: t0..t127 add shared[t] + shared[t+128]   ─┐
         barrier()                                 │ each step halves the
 step 2: t0..t63  add shared[t] + shared[t+64]    │ number of active threads
         barrier()                                 │
 ...                                               │
 step 8: t0       add shared[0] + shared[1]      ─┘ → shared[0] = total
```

## 🔧 In each tool

Real Mojo kernel ([samples/gpu_block_sum.mojo](../samples/gpu_block_sum.mojo)):

```mojo
var shared = stack_allocation[
    TPB, Float32, address_space = AddressSpace.SHARED   # 256 floats, per block
]()
var tid = Int(thread_idx.x)
shared[tid] = data[unsafe_offset=Int(block_idx.x) * TPB + tid]   # global → shared
barrier()                                    # everyone has written

var stride = TPB // 2
while stride > 0:
    if tid < stride:
        shared[tid] += shared[tid + stride]
    barrier()
    stride //= 2
```

PTX it compiles to (`sm_80`, trimmed):

```
.shared .align 4 .b8 ..._gpu_shared_mem[1024];   ← 256 × 4 bytes, one per block
ld.global.b32   %r6, [%rd11];                   ← read from global memory
st.shared.b32   [%r1], %r6;                     ← write into shared memory
bar.sync        0;                              ← barrier()
...
ld.shared.b32   %r7, [%r1];
ld.shared.b32   %r8, [%r14];
add.f32         %r9, %r7, %r8;
st.shared.b32   [%r1], %r9;
```

The address space is part of the instruction: `ld.global`, `ld.shared`,
`st.shared`. The hardware needs to know which memory it is.

| Tool   | Registers          | Shared memory                                                                                      |
| ------ | ------------------ | -------------------------------------------------------------------------------------------------- |
| CUDA   | Local variables    | `__shared__ float buf[256];`, `__syncthreads()`                                                    |
| MLIR   | SSA values         | `memref<256xf32, #gpu.address_space<workgroup>>`, `gpu.barrier`                                    |
| Triton | Tiles in registers | Managed **by the compiler**: it decides when a tile goes through shared memory (e.g. for `tl.dot`) |
| Mojo   | Local `var`s       | `stack_allocation[..., address_space=AddressSpace.SHARED]`, `barrier()`                            |

## ⚠️ Common confusion

- **Forgetting `barrier()`** is the classic bug. Without it, a thread may
  read `shared[t + stride]` before another thread has written it. Results
  are then wrong only sometimes, which makes it hard to find.
- **Bank conflicts.** Shared memory is split into 32 banks. If several
  threads of a warp hit different addresses in the same bank at once, the
  accesses are serialized. Padding arrays (e.g. 33 columns instead of 32)
  is a common fix.
- **Registers are a shared budget.** A kernel that uses many registers per
  thread leaves room for fewer threads. See [Occupancy](occupancy.md).
  Too many and values _spill_ to slow "local" memory.

## 🔗 Related

- [GPU thread, warp, block, grid](gpu-thread-warp-block-grid.md)
- [Memory coalescing](memory-coalescing.md)
- [Reduction in 5 IRs](../rosetta/reduction-in-5-irs.md)

---

✅ Verified against: Mojo 1.1.0 + MAX 26.6 (PTX cross-compiled for `sm_80`,
not run on an NVIDIA GPU)
