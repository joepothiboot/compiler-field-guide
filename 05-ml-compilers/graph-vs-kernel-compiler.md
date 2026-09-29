# Graph Compiler vs Kernel Compiler 🗺️

> **One line:** A **graph compiler** optimizes the whole model: which ops to
> fuse, which layouts to use, when to allocate memory. A **kernel compiler**
> generates fast code for one (possibly fused) operation. Modern stacks use
> both, one on top of the other.

## 🌉 From frontend

A graph compiler is like a bundler looking at your whole dependency graph:
deciding code splitting, which modules to merge, what to tree-shake. A kernel
compiler is like the minifier or V8 optimizing one function. Same pipeline,
different scope: whole program vs one function.

## 🖼️ Picture

```
 model graph (what the graph compiler sees)
 ┌────────┐   ┌─────┐   ┌──────┐   ┌─────────┐   ┌─────┐
 │ matmul │──►│ add │──►│ relu │──►│ softmax │──►│ ... │
 └────────┘   └─────┘   └──────┘   └─────────┘   └─────┘
      │           └────┬────┘            │
      │   GRAPH COMPILER decides:        │
      │   - fuse add+relu into matmul's epilogue
      │   - keep softmax separate (needs a reduction)
      │   - choose layouts, plan memory, order launches
      ▼                                  ▼
 ┌──────────────────────┐        ┌──────────────┐
 │ fused_matmul_add_relu│        │ softmax      │    ← kernels
 └──────────┬───────────┘        └──────┬───────┘
            │ KERNEL COMPILER decides:  │
            │ - tile sizes, vector width, thread mapping,
            │   shared memory, tensor cores, unrolling
            ▼                           ▼
        PTX / machine code          PTX / machine code
```

## 🔧 In each tool

| System                  | Graph level                                                           | Kernel level                                                                        |
| ----------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| PyTorch `torch.compile` | TorchDynamo captures an FX graph; **Inductor** fuses and schedules it | Inductor writes **Triton** kernels (GPU) or C++ (CPU); Triton compiles them         |
| Triton alone            | None: you are the graph compiler                                      | Triton                                                                              |
| Modular MAX             | MAX Graph compiler                                                    | Kernels written in **Mojo**                                                         |
| XLA (JAX, TensorFlow)   | HLO graph optimizations                                               | XLA's own codegen, or Triton for some GPU ops                                       |
| Upstream MLIR           | `linalg` on tensors: fusion, tiling decisions                         | Lowering to `scf`/`vector`/`gpu`/`llvm`                                             |
| nano-dsp-mlir           | `dsp` dialect (whole program of `dsp` ops)                            | `linalg` → loops → LLVM, and hand-written Mojo kernels as the second implementation |

## ⚠️ Common confusion

- **The line is blurry.** Tile-and-fuse in MLIR is a graph decision
  implemented with kernel-level transformations. What matters is the
  question being answered: _which ops go together_ vs _how to run one of them fast_.
- **Library kernels still matter.** Graph compilers often call vendor
  libraries (cuBLAS, cuDNN) for big matmuls instead of generating them,
  and only generate the fused elementwise code around them.
- **Mojo's pitch** is that you write kernel-level code yourself, in one
  language, with the same control as CUDA, rather than relying on a graph
  compiler to generate it. That makes Mojo library skills (SIMD, tiling,
  parameters) the core of the Mojo Libraries role.

## 🔗 Related

- [Kernel](kernel.md)
- [Fusion](../03-transformations/fusion.md)
- [torch.compile](torch-compile.md)
- [The whole stack](../maps/the-whole-stack.md)

---

✅ Verified against: concept page; system descriptions from each project's
documentation
