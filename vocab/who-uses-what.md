# Who Uses What 🗺️

> **One line:** A matrix of tool × name family. Read across a row to know
> what vocabulary to expect when you open a codebase.

## Tool by name family

| Tool / language        | Created by                          | Printer names                    | Op spelling                              | Parallel index names                                      | Shape names                          |
| ---------------------- | ----------------------------------- | -------------------------------- | ---------------------------------------- | --------------------------------------------------------- | ------------------------------------ |
| LLVM IR                | LLVM community (Apple, Google, ...) | `%0`, `%arrayidx`, `%i.0`        | `add`, `load`, `getelementptr`, `phi`    | (intrinsics) `llvm.nvvm.read.ptx.sreg.*`                  | `<4 x float>`                        |
| MLIR core dialects     | Google, now LLVM                    | `%arg0`, `%c0`, `%cst`, `%alloc` | `arith.addf`, `memref.load`, `scf.for`   | `gpu.thread_id`, `gpu.block_id`                           | `memref<?x?xf32>`, `tensor<4x8xf32>` |
| Triton IR (`tt.`)      | OpenAI                              | `%0`, `%1`                       | `tt.load`, `tt.dot`, `tt.make_range`     | `tt.get_program_id`                                       | `tensor<128xf32>`                    |
| PTX                    | NVIDIA                              | `%r`, `%rd`, `%p`, `%f`          | `ld.global`, `mad.lo`, `setp`, `bra`     | `%tid.x`, `%ctaid.x`                                      | —                                    |
| CUDA C++               | NVIDIA                              | user names                       | `__syncthreads`, `__shfl_sync`           | `threadIdx`, `blockIdx`                                   | `dim3`, `M N K`                      |
| Triton Python          | OpenAI                              | user names                       | `tl.load`, `tl.dot`                      | `tl.program_id`, `tl.arange`                              | `BLOCK_SIZE`, `M N K`                |
| Mojo / MAX             | Modular                             | user names                       | `SIMD[...]`, `LayoutTensor`              | `thread_idx`, `block_idx`                                 | `Layout`, `simd_width`               |
| PyTorch Inductor       | Meta                                | `buf0`, `tmp0`, `arg0_1`         | (generates Triton)                       | `xindex`, `pid`                                           | `XBLOCK`, `RBLOCK`                   |
| torch.fx / ATen        | Meta                                | `add`, `mm_1`, `relu`            | `aten.add`, `aten.mm`                    | —                                                         | `size`, `stride`                     |
| StableHLO / XLA        | Google                              | `%0`, `%arg0`                    | `stablehlo.dot_general`, `stablehlo.add` | —                                                         | `tensor<2x3xf32>`                    |
| IREE                   | Google                              | `%0`, `%c0`                      | `flow.dispatch`, `hal.executable`        | `workgroup_id`, `workgroup_size`                          | `tensor<...>`                        |
| SPIR-V / Vulkan        | Khronos                             | `%12`, `%gl_`                    | `OpLoad`, `OpFAdd`, `OpBranch`           | `GlobalInvocationId`, `LocalInvocationId`                 | `OpTypeVector`                       |
| Metal Shading Language | Apple                               | user names                       | `threadgroup`, `simdgroup_matrix`        | `thread_position_in_grid`, `threadgroup_position_in_grid` | `uint2`, `half4`                     |
| TVM / Relay            | Apache (originated at UW)           | `%x`, `%0`                       | `nn.conv2d`, `add`, `T.grid`             | `threadIdx.x`, `blockIdx.x`                               | `T.Buffer`                           |
| JAX / jaxpr            | Google                              | `a`, `b`, `c` (letters)          | `add`, `dot_general`, `scan`             | —                                                         | `f32[3,4]`                           |

Rows after Mojo (JAX, Metal, SPIR-V, StableHLO, IREE, TVM) are included for
orientation and are **not** reproduced in this repo's samples. They come from
each project's public documentation, so confirm spellings before quoting.

## Vocabulary shared by almost everyone

| Concept                   | Common name(s)                                                               |
| ------------------------- | ---------------------------------------------------------------------------- |
| The unit of parallel work | thread, program (Triton), work-item (OpenCL/SPIR-V), invocation (Vulkan)     |
| Group that shares memory  | block (CUDA), CTA (PTX), workgroup (OpenCL/Vulkan/IREE), threadgroup (Metal) |
| Lockstep group            | warp (NVIDIA, 32), wavefront (AMD, 32 or 64), simdgroup (Apple, 32)          |
| Fast on-chip memory       | shared (CUDA/PTX), local (OpenCL), threadgroup (Metal), LDS (AMD)            |
| Matrix hardware           | tensor core (NVIDIA), matrix core (AMD), simdgroup matrix / AMX (Apple)      |
| Loop tile                 | tile, block, chunk, strip                                                    |
| Unit of IR                | operation / instruction / node / equation                                    |

A line worth memorizing: **thread / block / warp** (NVIDIA) =
**work-item / workgroup / wavefront** (AMD, OpenCL) =
**thread / threadgroup / simdgroup** (Apple). Same hardware, three vocabularies.

## ⚠️ Common confusion

- **Tool names are not company secrets.** Triton is OpenAI, but it lowers into
  LLVM and NVVM from NVIDIA's ecosystem. The vocabulary is borrowed layer
  after layer.
- **"Block" has three meanings:** a basic block (control flow), a GPU thread
  block (parallelism), and a Triton tile (`BLOCK_SIZE`). Context decides.
- **"Kernel" has two:** a GPU function you launch, and a compiled tile
  routine inside a graph compiler.

## 🔗 Related

[the whole stack](../maps/the-whole-stack.md) ·
[GLOSSARY](../GLOSSARY.md) · [value-names](value-names.md) ·
[opcodes](opcodes.md) · [kernel-parameter-names](kernel-parameter-names.md)
