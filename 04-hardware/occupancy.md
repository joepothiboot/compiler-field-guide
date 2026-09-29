# Occupancy 📈

> **One line:** Occupancy is how many warps are actually resident on a GPU
> core, compared with the maximum it could hold. More resident warps give
> the core more work to switch to while other warps wait for memory.

## 🌉 From frontend

The Node.js event loop stays busy because while one request waits for the
database, it runs another. A GPU core (SM) does the same with warps: when a
warp stalls on a memory load, the scheduler switches to a ready warp at
no cost. If only a few warps fit, there is nothing to switch to, and
the core sits idle.

## 🖼️ Picture

What limits how many warps fit: each SM has fixed **budgets**, and every
resident block takes a share of each.

```
 One SM on an NVIDIA A100 (sm_80), published limits:
 ┌──────────────────────────────────────────────────────────┐
 │ registers       65,536 × 32-bit                           │
 │ shared memory   up to 164 KB                              │
 │ threads         up to 2,048 (= 64 warps)                  │
 │ blocks          up to 32                                  │
 └──────────────────────────────────────────────────────────┘

 register math:  65,536 registers / 2,048 threads = 32 registers per thread
                 for 100% occupancy

 kernel uses 32 regs/thread → 2,048 threads fit → 64 warps  (100%)
 kernel uses 64 regs/thread → 1,024 threads fit → 32 warps  ( 50%)
 kernel uses 128 regs/thread →  512 threads fit → 16 warps  ( 25%)

 same for shared memory: a block using 64 KB → at most 2 blocks per SM
```

## 🔧 In each tool

The PTX from the Mojo kernels in this guide declares **virtual**
registers, for example in
[shared memory and registers](shared-memory-and-registers.md):

```
.reg .pred  %p<4>;     ← virtual registers: unlimited in PTX
.reg .b32   %r<15>;
.reg .b64   %rd<14>;
```

These are not the real counts. `ptxas` (NVIDIA's assembler, not installed
here) does the real register allocation and reports it with
`-v`/`--resource-usage`, e.g. "Used 18 registers". That number, the block
size and the shared memory size together determine occupancy.

| Tool     | How you influence occupancy                                                                                                          |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| CUDA     | `__launch_bounds__`, `-maxrregcount`, block size, shared memory size                                                                 |
| Triton   | `num_warps` (threads per program), `num_stages` (more stages = more shared memory), block sizes                                      |
| Mojo     | `block_dim`, `shared_mem_bytes`, and launch attributes on `enqueue_function`; `_ptxas_info_verbose=True` prints ptxas resource usage |
| Profiler | Nsight Compute shows "achieved occupancy" and which limit was hit                                                                    |

## ⚠️ Common confusion

- **100% occupancy is not the goal.** Many of the fastest kernels (matmul)
  run at low occupancy on purpose: they use lots of registers to keep a
  large tile per thread, which saves memory traffic. Occupancy only has to
  be high enough to hide latency.
- **Fusion and CSE can lower occupancy** by keeping more values alive at
  once. That is the main case where "fewer operations" is not faster.
- **Occupancy is per SM, not per GPU.** A launch with fewer blocks than
  SMs leaves whole SMs idle, no matter the occupancy per SM.

## 🔗 Related

- [Shared memory and registers](shared-memory-and-registers.md)
- [Register allocation](../07-codegen-runtime/register-allocation.md)
- [Autotuning](../05-ml-compilers/autotuning.md)

---

✅ Verified against: Mojo 1.1.0 + MAX 26.6 (PTX) · A100 limits from NVIDIA's
published specifications; `ptxas` not available on macOS
