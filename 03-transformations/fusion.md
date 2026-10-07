# Fusion 🔗

> **One line:** Fusion merges several operations into one loop or kernel,
> so intermediate results stay in registers instead of being written to
> memory and read back. It is the single most important ML compiler
> optimization.

## 🖼️ Picture

`y = relu(a + b)` on 1024 floats:

```
 UNFUSED: 2 loops, 1 temporary                FUSED: 1 loop, no temporary
 ─────────────────────────────                ───────────────────────────
 loop 1: tmp[i] = a[i] + b[i]                 loop: y[i] = max(a[i] + b[i], 0)
 loop 2: y[i]   = max(tmp[i], 0)

 memory traffic (floats):                     memory traffic:
   read a, b      2048                          read a, b    2048
   write tmp      1024                          write y      1024
   read tmp       1024                                      ─────
   write y        1024                                       3072
                 ─────
                  5120      ── 40% less memory traffic ──►

 on modern hardware, arithmetic is cheap and memory is slow,
 so elementwise ops are limited by memory traffic ("memory-bound")
```

## 🔧 In each tool

Real output of `mlir-opt --linalg-fuse-elementwise-ops` on
[samples/fusion.mlir](../samples/fusion.mlir):

```mlir
// BEFORE: two linalg.generic ops; %sum is a full temporary tensor
%sum = linalg.generic ... ins(%a, %b) outs(%e0) {
  %s = arith.addf %x, %y : f32
  linalg.yield %s : f32
}
%out = linalg.generic ... ins(%sum) outs(%e1) {
  %r = arith.maximumf %x, %zero : f32
  linalg.yield %r : f32
}

// AFTER: one linalg.generic; both computations in one body
%1 = linalg.generic {indexing_maps = [#map, #map, #map], iterator_types = ["parallel"]}
     ins(%arg0, %arg1 : tensor<1024xf32>, tensor<1024xf32>) outs(%0 : tensor<1024xf32>) {
^bb0(%in: f32, %in_0: f32, %out: f32):
  %2 = arith.addf %in, %in_0 : f32
  %3 = arith.maximumf %2, %cst : f32
  linalg.yield %3 : f32
} -> tensor<1024xf32>
```

| Tool             | How fusion happens                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------------------------- |
| LLVM             | Loop fusion exists (`loop-fusion`) but is rarely the main tool; ML fusion happens before LLVM                 |
| MLIR             | `linalg` elementwise fusion, and tile-and-fuse (fuse producers into the tiles of a consumer)                  |
| Triton           | **You** fuse by hand: write `relu(x + y)` in one kernel. Triton does not fuse across kernels                  |
| PyTorch Inductor | Automatically fuses pointwise and reduction ops from the graph, then writes one Triton kernel per fused group |
| Mojo / MAX       | MAX's graph compiler fuses ops; in plain Mojo you fuse by writing the combined kernel                         |

## ⚠️ Common confusion

- **Elementwise fusion is easy; the rest is harder.** Fusing a matmul with
  a following `relu` (an _epilogue_) is common and valuable. Fusing two
  matmuls, or ops needing different loop orders, often is not possible or
  not profitable.
- **Fusion can hurt.** A fused kernel uses more registers. If it uses too
  many, fewer threads fit on the GPU (see [Occupancy](../04-hardware/occupancy.md)).
- **Fusion vs inlining.** Inlining merges _function calls_. Fusion merges
  _loops_. They often happen together.

## 🧪 Seen in my projects

- nano-dsp-mlir: `dsp` ops lower to `linalg.generic`, which makes them
  candidates for exactly this pass

## 🔗 Related

- [Tiling](tiling.md)
- [Graph compiler vs kernel compiler](../05-ml-compilers/graph-vs-kernel-compiler.md)
- [torch.compile](../05-ml-compilers/torch-compile.md): a real fused kernel from Inductor
- [Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md)

---

✅ Verified against: MLIR 23.1.1
