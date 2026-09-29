# MAX and Mojo Kernels 🏎️

> **One line:** **MAX** is Modular's inference platform: a graph compiler
> and runtime whose kernels are written in Mojo. Its Mojo libraries
> (`layout`, `linalg`, `nn`, `max.gpu` …) are the "kernel standard library":
> tensor layouts, GPU launch, matmul and attention building blocks.

## 🌉 From frontend

If Mojo's `std` is like the JS standard library, the MAX packages are like a
UI framework built on it: higher-level, domain-specific building blocks
(layouts, tiled tensors, GPU helpers) so kernels don't start from
raw pointers every time.

## 🖼️ Picture

```
 model (PyTorch / ONNX / MAX graph API)
     │
     ▼
 MAX Graph compiler  ── fusion, layout, memory planning (graph level)
     │
     ▼
 Mojo kernels  ────────────── written with:
     │                          layout      Layout, LayoutTensor, tiling
     │                          linalg      matmul building blocks
     │                          nn          attention, conv, softmax ...
     │                          max.gpu     thread/block ids, DeviceContext,
     │                                      warp primitives, shared memory
     │                          std         SIMD, pointers, algorithms
     ▼
 CPU (x86, ARM)  /  NVIDIA GPU  /  AMD GPU  /  Apple GPU (Metal)
```

Packages actually installed by the `max` 26.6 conda package on this Mac
(from `.pixi/envs/default/lib/mojo/`):

```
std  max  layout  linalg  nn  algorithm  quantization  kv_cache  comm  shmem
state_space  structured_kernels  pipeline  machine  _cublas _cudnn _rocblas ...
```

## 🔧 In each tool

**`LayoutTensor`**: a pointer plus a compile-time layout, with tiling.
Real run of [samples/mojo_layout_tensor.mojo](../samples/mojo_layout_tensor.mojo):

```mojo
from std.collections import Array
from layout import Layout, LayoutTensor

comptime layout = Layout.row_major(4, 8)          # shape (4, 8), strides (8, 1)
var storage = Array[Float32, 32](fill=0)
var t = LayoutTensor[DType.float32, layout](storage)
for i in range(4):
    for j in range(8):
        t[i, j] = Float32(i * 10 + j)
var tile = t.tile[2, 4](1, 1)                      # a 2x4 view, no copy
print(tile)
```

```
tile (rows 2-3, cols 4-7):
24.0 25.0 26.0 27.0
34.0 35.0 36.0 37.0
```

**GPU kernels**: import paths in Mojo 1.1 + MAX 26.6, all verified by
compiling the samples in this guide:

```mojo
from max.gpu import block_dim, block_idx, thread_idx, barrier, WARP_SIZE
from max.gpu.host import DeviceContext
from max.gpu.memory import AddressSpace
from max.gpu.primitives import warp          # warp.sum(...) → shfl.sync.bfly
from std.memory import stack_allocation      # + address_space=AddressSpace.SHARED
```

Samples: [gpu_vadd.mojo](../samples/gpu_vadd.mojo),
[gpu_block_sum.mojo](../samples/gpu_block_sum.mojo),
[gpu_warp_and_coalescing.mojo](../samples/gpu_warp_and_coalescing.mojo).
Compile them to NVIDIA PTX with [scripts/mojo-ptx.sh](../scripts/mojo-ptx.sh).
That script uses `mojo build --emit asm --target-accelerator=sm_80`, which
works without an NVIDIA GPU.

**Running on this Mac's GPU** needs Xcode's Metal toolchain. Without it,
the real error is `cannot execute tool 'metal' due to missing Metal Toolchain;
use: xcodebuild -downloadComponent MetalToolchain`.

| Need                            | Where it lives (Mojo 1.1 / MAX 26.6)                                 |
| ------------------------------- | -------------------------------------------------------------------- |
| SIMD, pointers, List, time      | `std` (`std.sys`, `std.memory`, `std.time`, `std.collections`)       |
| Vectorize / parallelize helpers | `std.algorithm` (`vectorize`)                                        |
| GPU launch and ids              | `max.gpu`, `max.gpu.host`                                            |
| Shared memory                   | `std.memory.stack_allocation` + `max.gpu.memory.AddressSpace.SHARED` |
| Warp primitives                 | `max.gpu.primitives.warp`                                            |
| Tensor layouts and tiles        | `layout` (`Layout`, `LayoutTensor`)                                  |

## ⚠️ Common confusion

- **Import paths move between releases.** Older examples use
  `from gpu import ...` and `from gpu.host import ...`. In MAX 26.6 these
  live under `max.gpu`. Warp helpers moved to `max.gpu.primitives.warp`.
  This page's imports are the ones that compiled here.
- **`Int` is not device-passable.** Kernel arguments need fixed-width types.
  Real error: `Int and UInt do not conform to DevicePassable; use a
fixed-width type such as Int32 or Int64 instead`.
- **`out` is a keyword**, so you cannot name a kernel parameter `out`
  (real error: `expected argument name`). The samples use `result`.

## 🧪 Seen in my projects

- nano-dsp-mlir `mojo/nanodsp/`: CPU SIMD kernels mirroring each `dsp` op,
  tested against the same golden values as the MLIR pipeline

## 🔗 Related

- [Graph compiler vs kernel compiler](../05-ml-compilers/graph-vs-kernel-compiler.md)
- [GPU thread, warp, block, grid](../04-hardware/gpu-thread-warp-block-grid.md)
- [Mojo and MAX codebase tour](../real-world/mojo-and-max-tour.md)

---

✅ Verified against: Mojo 1.1.0 + MAX 26.6 (CPU samples run; GPU samples
compiled to PTX, not run)
