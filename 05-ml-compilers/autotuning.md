# Autotuning 🎛️

> **One line:** Autotuning means compiling several versions of a kernel with
> different settings (tile sizes, warps, stages), timing each one on the
> real hardware and input shapes, and keeping the fastest. It is used
> because the best settings are too hard to predict.

## 🖼️ Picture

```
  candidate configs                 benchmark on THIS hardware        pick
  ─────────────────                 ──────────────────────────        ────
  BLOCK=16  ───► compile ───► run ───►  51.9 ms
  BLOCK=32  ───► compile ───► run ───►  46.9 ms
  BLOCK=64  ───► compile ───► run ───►  42.6 ms   ◄── fastest ───►  cache the
  BLOCK=128 ───► compile ───► run ───►  49.9 ms                     choice per
                                                                    (shape, GPU)
  a U-shaped curve is typical: too small = overhead, too big = doesn't fit
```

## 🔧 In each tool

**Real measurements** from [samples/matmul_cpu.mojo](../samples/matmul_cpu.mojo)
on this Apple M2: a compile-time sweep of the tile size `T` and the
k-block size `KC`, 512×512 and 2048×2048 float32 matmul:

```
--- N = 512
3  cache-tiled T = 16       51.948 ms
3  cache-tiled T = 32       46.934 ms
3  cache-tiled T = 64       42.631 ms       ← best tile, but no faster than untiled (42.2 ms)
3  cache-tiled T = 128      49.931 ms
5  reg-blocked, KC = 64     3.574 ms
5  reg-blocked, KC = 128    3.244 ms
5  reg-blocked, KC = 256    2.999 ms        ← best KC at this size
--- N = 2048
5  reg-blocked, KC = 64     307.91 ms
5  reg-blocked, KC = 128    263.144 ms
5  reg-blocked, KC = 256    243.519 ms      ← best, and 2.3× faster than no k-blocking (567 ms)
```

Two lessons that only measuring reveals:

1. The textbook cache tiling barely helped on this CPU: its hardware
   prefetcher already streams rows well. The winner was a _different_
   strategy (register blocking). No amount of tile-size tuning would have
   found that. Autotuning chooses among the candidates you give it.
2. `KC = 256` wins at both sizes here, but the gap between candidates
   changes with `N`. Real autotuners key their cache on shape.

The sweep uses `comptime for`, so each `T` / `KC` is a separate,
fully specialized compiled function, just like an autotuner compiling one
kernel per config:

```mojo
comptime for t in range(3):  # KC = 64, 128, 256
    comptime KC = 64 << t
    matmul_regblock[N, KC](a, b, c)
```

**Triton** (from its docs, not run locally):

```python
@triton.autotune(
    configs=[
        triton.Config({"BLOCK_M": 128, "BLOCK_N": 256, "BLOCK_K": 64}, num_stages=3, num_warps=8),
        triton.Config({"BLOCK_M": 64,  "BLOCK_N": 256, "BLOCK_K": 32}, num_stages=4, num_warps=4),
    ],
    key=["M", "N", "K"],          # re-tune when these argument values change
)
@triton.jit
def matmul_kernel(...): ...
```

| Tool            | Autotuning                                                                                                                      |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Triton          | `@triton.autotune(configs=[...], key=[...])`                                                                                    |
| `torch.compile` | `mode="max-autotune"` benchmarks Triton configs and library kernels                                                             |
| Mojo / MAX      | Kernels are parameterized (`[T: Int]`); MAX selects tuned configurations per target; you can sweep with `comptime for` as above |
| TVM / Ansor     | Search-based autotuning with a learned cost model                                                                               |
| LLVM            | Mostly static cost models (no measuring)                                                                                        |

## ⚠️ Common confusion

- **Benchmark correctly.** Warm up first (the first run pays JIT compile
  and cold caches), repeat, and use the median. The sample prints one run
  per config to stay short, so treat small differences as noise.
- **Tuning is per hardware and per shape.** A config tuned on an A100 can
  be poor on an H100 or on another shape.
- **The search space is the real design work.** Autotuning only picks the
  best of the candidates you list.

## 🔗 Related

- [Tiling](../03-transformations/tiling.md)
- [Occupancy](../04-hardware/occupancy.md)
- [Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md)

---

✅ Verified against: Mojo 1.1.0 on Apple M2 (measured) · Triton: from its
docs, not run locally
