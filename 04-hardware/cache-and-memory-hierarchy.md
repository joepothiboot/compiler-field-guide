# Cache and Memory Hierarchy 🏔️

> **One line:** Memory is a pyramid: a few very fast, tiny levels near the
> core (registers, L1, L2) and a large slow level far away (DRAM). Data
> moves between levels in fixed-size chunks called **cache lines**, so
> _how_ you walk through memory decides how fast your code runs.

## 🖼️ Picture

Real numbers for this Apple M2 (from `sysctl`), with typical latencies:

```
                 size (M2 performance core)       approx. latency
             ┌────────────────────────────┐
             │ registers   ~ hundreds of B │        0 cycles
             ├────────────────────────────┤
             │ L1 data     128 KiB / core  │        ~3-4 cycles
             ├────────────────────────────┤
             │ L2          16 MiB, shared  │        ~15-20 cycles
             │             by 4 P-cores    │
             ├────────────────────────────┤
             │ DRAM        8 GiB           │        ~100+ ns (hundreds of cycles)
             └────────────────────────────┘

 cache line on M2: 128 bytes (32 floats). Touch 1 float → the whole line is loaded.
```

Walking a row-major matrix two ways:

```
 row by row (stride 4 B)                 column by column (stride 16 KiB)
 ┌───────────────────────┐               ┌───────────────────────┐
 │→→→→→→→→→→→→→→→→→→→→→→→│               │↓                      │
 │→→→→→→→→→→→→→→→→→→→→→→→│               │↓   each step jumps     │
 │                       │               │↓   to a different      │
 └───────────────────────┘               │↓   cache line          │
 1 cache line load feeds 32 floats       └───────────────────────┘
                                         1 cache line load feeds 1 float
```

## 🔧 In each tool

Real benchmark: [samples/cache_walk.mojo](../samples/cache_walk.mojo) sums
the same 4096×4096 `float32` matrix (64 MiB, larger than every cache) both
ways. Output on this M2, second (warm) round:

```
rows: 15 ms   cols: 62 ms   sums: 16777216.0 16777216.0
```

Same data, same additions, same result. The column walk is **about 4× slower**
only because of the access order. (Hardware prefetchers limit the gap. On
many other CPUs it is larger.)

| Tool   | How memory hierarchy shows up                                                                                                                  |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM   | Mostly invisible; `-O2` does not reorder your loops to fix access order                                                                        |
| MLIR   | Loop interchange and [tiling](../03-transformations/tiling.md) in `affine`/`linalg`; `memref` layouts make strides explicit                    |
| Triton | Loads a whole tile at once; the compiler stages tiles through shared memory (`num_stages` for pipelining)                                      |
| Mojo   | You control loop order, tiling and prefetch explicitly; `LayoutTensor` layouts describe the memory order                                       |
| GPUs   | Same idea, different levels: registers → shared memory / L1 → L2 → HBM/DRAM. See [Shared memory and registers](shared-memory-and-registers.md) |

## ⚠️ Common confusion

- **"Memory-bound" vs "compute-bound".** If a kernel spends its time
  waiting for data, faster math will not help. Most elementwise ML ops are
  memory-bound, which is why [fusion](../03-transformations/fusion.md)
  (fewer memory trips) is so effective.
- **Bandwidth vs latency.** Latency is how long one access takes.
  Bandwidth is how many bytes per second you can stream. Sequential access
  is fast because hardware can overlap many requests.
- **Row-major vs column-major** is a convention (C and PyTorch: row-major;
  Fortran and some BLAS: column-major). The fast loop order depends on it.
  See [Layout and strides](../05-ml-compilers/layout-and-strides.md).

## 🔗 Related

- [Tiling](../03-transformations/tiling.md)
- [Memory coalescing](memory-coalescing.md): the GPU version of this page
- [Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md)

---

✅ Verified against: Mojo 1.1.0 (Apple M2, macOS 27). Latencies are typical
published values, not measured here.
