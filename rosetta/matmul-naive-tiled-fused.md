# Matmul: Naive, Tiled, Fused 🧮

> **One benchmark, many optimizations, real numbers.**
> [samples/matmul_cpu.mojo](../samples/matmul_cpu.mojo) computes
> `C = A × B` for float32 matrices on this Apple M2, from a textbook triple
> loop to a register-blocked SIMD kernel, and checks every version against
> the reference (`diff: 0.0` means bit-identical).

## 📊 Results

Real output (Mojo 1.1.0, `mojo run`, one timed run per config):

```
--- N = 512                                   (3 × 1 MiB: fits in the 16 MiB L2)
1  naive (i,j,k)            137.228 ms
2  interchanged (i,k,j)     42.188 ms    diff: 0.0
3  cache-tiled T = 16       51.948 ms    diff: 0.0
3  cache-tiled T = 32       46.934 ms    diff: 0.0
3  cache-tiled T = 64       42.631 ms    diff: 0.0
3  cache-tiled T = 128      49.931 ms    diff: 0.0
4  register-blocked         3.157 ms     diff: 0.0
5  reg-blocked, KC = 64     3.574 ms     diff: 0.0
5  reg-blocked, KC = 128    3.244 ms     diff: 0.0
5  reg-blocked, KC = 256    2.999 ms     diff: 0.0
6a reg-blocked + relu pass  3.02 ms
6b reg-blocked, fused relu  3.027 ms     diff vs 6a: 0.0
--- N = 2048                                  (3 × 16 MiB: does not fit)
2  interchanged (i,k,j)     2721.185 ms  diff: 0.0
3  cache-tiled T = 16       3879.0 ms    diff: 0.0
3  cache-tiled T = 32       3026.037 ms  diff: 0.0
3  cache-tiled T = 64       2899.955 ms  diff: 0.0
3  cache-tiled T = 128      3198.056 ms  diff: 0.0
4  register-blocked         567.469 ms   diff: 0.0
5  reg-blocked, KC = 64     307.91 ms    diff: 0.0
5  reg-blocked, KC = 128    263.144 ms   diff: 0.0
5  reg-blocked, KC = 256    243.519 ms   diff: 0.0
6a reg-blocked + relu pass  556.118 ms
6b reg-blocked, fused relu  550.377 ms   diff vs 6a: 0.0
```

Throughput of the best versions (2·N³ floating-point operations ÷ time):
**≈ 89 GFLOP/s** at N = 512, **≈ 70 GFLOP/s** at N = 2048, on one core.

## 🪜 The steps, and what each one teaches

```
 1 naive (i,j,k)      acc += A[i][k] * B[k][j]
                      └─ B is walked DOWN a column: every step jumps 2 KiB (N=512)
                         → cache-unfriendly, not vectorizable            137 ms
        │ loop interchange (i,k,j)
 2      C[i][j] += A[i][k] * B[k][j] with j innermost
                      └─ B and C walked ALONG rows: contiguous → the
                         compiler can vectorize it                           42 ms  (3.3×)
        │ cache tiling (textbook)
 3      same math on T×T blocks
                      └─ no gain here: the M2's prefetcher already streams
                         rows well, and short inner loops hurt           42-52 ms
        │ register blocking (the real win)
 4      a 4×16 block of C lives in 4 SIMD registers for the WHOLE k loop
                      └─ each loaded B row (16 floats) is reused 4 times;
                         C is loaded/stored once instead of N times       3.2 ms (13×)
        │ + k-blocking (KC)
 5      split k so the B panel being reused stays in L1/L2
                      └─ matters only when data outgrows the cache:
                         N=2048: 567 → 244 ms (2.3×); N=512: no change    3.0 ms
        │ epilogue fusion
 6      apply relu to the accumulators before the single store
                      └─ saves one pass over C: 0.25 M floats at N=512;
                         negligible next to N³ work, so no visible gain here
```

The register-blocked kernel (step 4), from the sample:

```mojo
for j0 in range(0, N, NR):                 # NR = 16 columns
    for i0 in range(0, N, MR):             # MR = 4 rows
        var acc0 = pc.unsafe_load[width=NR]((i0 + 0) * N + j0)
        ...                                # acc1..acc3: 4 × SIMD[f32, 16] = 16 NEON registers
        for k in range(kk, kk + KC):
            var bv = pb.unsafe_load[width=NR](k * N + j0)          # 1 load of B ...
            acc0 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 0) * N + k]) * bv
            acc1 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 1) * N + k]) * bv
            acc2 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 2) * N + k]) * bv
            acc3 += SIMD[DType.float32, NR](pa[unsafe_offset=(i0 + 3) * N + k]) * bv
        pc.unsafe_store((i0 + 0) * N + j0, acc0)                    # ... reused 4 times
        ...
```

## 🧠 Lessons that only measurement showed

1. **Access order beats clever tiling at first.** One loop interchange gave
   3.3×. The textbook cache tiling gave nothing on this CPU.
2. **Registers are the most important "cache".** The 13× jump came from
   keeping `C` in registers across the entire `k` loop. This is the idea
   behind every fast matmul: BLAS micro-kernels, Triton's `acc` tile,
   tensor-core fragments.
3. **Cache blocking pays when data outgrows the cache.** `KC` did nothing at
   512 (everything fits in L2) and gave 2.3× at 2048.
4. **Fusion's value depends on the ratio of memory to math.** A relu over
   `C` is O(N²) next to O(N³) math, so fusing it saves little here. For
   memory-bound chains of elementwise ops, fusion is the main win
   (see [Fusion](../03-transformations/fusion.md)).
5. **Results stayed bit-identical** because every version keeps the same
   `k` order for each `C[i][j]`. Reordering `k` (e.g. splitting it across
   threads) would change the float result slightly, as the
   [reduction page](reduction-in-5-irs.md) shows.

## 🔁 The same structure in other tools

| Idea                        | Mojo (this sample)          | Triton                                         | GPU hardware                |
| --------------------------- | --------------------------- | ---------------------------------------------- | --------------------------- |
| Output tile                 | 4×16 block of `C`           | `BLOCK_M × BLOCK_N` per program                | per-warp fragment           |
| Accumulator in registers    | `acc0..acc3: SIMD[f32, 16]` | `acc = tl.zeros((BM, BN))`                     | `mma` D registers           |
| Loop over K in blocks       | `KC`                        | `for k in range(0, K, BLOCK_K)`                | `k16` per `mma` instruction |
| Stage operands near compute | B panel in L1               | shared memory (compiler-managed, `num_stages`) | shared memory → registers   |
| Epilogue                    | relu before store (6b)      | apply ops to `acc` before `tl.store`           | fused epilogue              |
| Choose sizes                | `comptime for` sweep        | `@triton.autotune`                             | —                           |

MLIR equivalent: [Tiling](../03-transformations/tiling.md) shows
`affine-loop-tile` on the same loop nest, and
[A tensor's journey](../maps/tensor-journey-matmul-to-ptx.md) shows what
happens without tiling on a GPU (one thread per block).

## 🔗 Related

- [Autotuning](../05-ml-compilers/autotuning.md)
- [Cache and memory hierarchy](../04-hardware/cache-and-memory-hierarchy.md)
- [SIMD and DType](../06-mojo/simd-and-dtype.md)
- [Tensor cores](../04-hardware/tensor-cores.md)

---

✅ Verified against: Mojo 1.1.0 on Apple M2 (measured locally; single runs,
so small differences are noise)
