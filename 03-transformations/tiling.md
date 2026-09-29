# Tiling 🧱

> **One line:** Tiling splits a big loop nest into small blocks (tiles) that
> fit in fast memory (cache, shared memory, registers), then processes one
> tile at a time. It reorders the work; it does not change the result.

## 🌉 From frontend

Virtualized lists (`react-window`) render only the rows that fit on the
screen, one window at a time, instead of all 100,000 rows. Tiling is the
same idea for data: work on a window small enough to fit in the fast
memory, finish with it, then move on.

## 🖼️ Picture

Matmul `C = A × B`, 256×256, tiled by 32:

```
 UNTILED: for each C[i][j], walk a full row of A and a full column of B
          → B's columns are 256 floats apart; the cache keeps getting evicted

        B                              TILED: work on 32×32 blocks
   ┌─┬─────────┐                            B
   │▓│         │ column j                ┌────┬────┬───┐
   │▓│         │ (256 values,            │ B00│ B01│   │
   │▓│         │  each 1 KB apart)       ├────┼────┼───┤
   └─┴─────────┘                         │ B10│ B11│   │
   A                                     └────┴────┴───┘
 ┌─────────┐ ┌───────┐              A                 C
 │▓▓▓▓▓▓▓▓▓│ │  C    │         ┌────┬────┐   ┌────┬────┐
 └─────────┘ └───────┘         │ A00│ A01│   │ C00│    │  C00 += A00×B00
  row i                        ├────┼────┤   ├────┼────┤       += A01×B10 ...
                               │ A10│ A11│   │    │    │
                               └────┴────┘   └────┴────┘
                               three 32×32 tiles = 3 × 4 KB = 12 KB
                               → fits in L1 cache; each value is reused 32 times
```

## 🔧 In each tool

Real output of `mlir-opt --affine-loop-tile="tile-size=32"` on
[samples/matmul_affine.mlir](../samples/matmul_affine.mlir):

```mlir
affine.for %arg3 = 0 to 256 step 32 {             ← tile loops (which block)
  affine.for %arg4 = 0 to 256 step 32 {
    affine.for %arg5 = 0 to 256 step 32 {
      affine.for %arg6 = #map(%arg3) to #map1(%arg3) {     ← point loops (inside
        affine.for %arg7 = #map(%arg4) to #map1(%arg4) {      the block): from
          affine.for %arg8 = #map(%arg5) to #map1(%arg5) {    x to x + 32
            %0 = affine.load %arg0[%arg6, %arg8] : memref<256x256xf32>
            %1 = affine.load %arg1[%arg8, %arg7] : memref<256x256xf32>
            ...
// #map = affine_map<(d0) -> (d0)>      #map1 = affine_map<(d0) -> (d0 + 32)>
```

Three loops became six. The body is unchanged. Only the order in which
`(i, j, k)` are visited changed.

| Tool   | Tiling                                                                                                                                     |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| LLVM   | Little automatic tiling; by the time code is LLVM IR, loop structure is hard to reason about                                               |
| MLIR   | `affine-loop-tile`, and `linalg` tiling through the **transform dialect** (`transform.structured.tile_using_for`), used for real schedules |
| Triton | Tiling **is** the programming model: `BLOCK_M`, `BLOCK_N`, `BLOCK_K` are your tile sizes                                                   |
| Mojo   | Written by hand in the kernel (`LayoutTensor.tile[...]` in MAX kernels), or with `vectorize`/`tile` helpers in `std.algorithm`             |
| GPUs   | Two levels: a thread block computes a tile of C in shared memory; each thread computes a smaller tile in registers                         |

## ⚠️ Common confusion

- **The right tile size depends on the hardware**: cache size, shared memory
  size, number of registers. That is why Triton kernels are autotuned
  over block sizes (see [Autotuning](../05-ml-compilers/autotuning.md)).
- **Tiling alone may not help** if the tile loops are ordered badly.
  Tiling is usually combined with loop interchange, vectorization of the
  innermost loop and fusion into the tile.
- **Edge tiles.** When 32 does not divide the size, the last tile is
  partial and needs bounds checks or padding. Triton uses masks for this.

## 🔗 Related

- [Cache and memory hierarchy](../04-hardware/cache-and-memory-hierarchy.md): why tiling works
- [Shared memory and registers](../04-hardware/shared-memory-and-registers.md)
- [Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md): real timings

---

✅ Verified against: MLIR 23.1.1
