# Kernel 🌰

> **One line:** A kernel is one compiled function that performs one tensor
> operation (or a fused group of them) on an accelerator or a CPU. An ML
> model runs as a sequence of kernel launches.

## 🖼️ Picture

```
 Python / host program                          device (GPU or CPU cores)
 ─────────────────────                          ─────────────────────────
 y = relu(x @ W + b)
     │
     ├─ launch matmul kernel (x, W) ───────────►  [ thousands of threads ]
     ├─ launch add kernel (tmp, b) ────────────►  [ thousands of threads ]
     └─ launch relu kernel (tmp2) ─────────────►  [ thousands of threads ]

 each launch has overhead (microseconds on a GPU) and each kernel reads
 and writes global memory → FUSION turns 3 launches into 1:

     └─ launch fused_matmul_add_relu (x, W, b) ─►  [ one kernel ]
```

## 🔧 In each tool

| Tool             | What a kernel is                                                                  | Example in this guide                               |
| ---------------- | --------------------------------------------------------------------------------- | --------------------------------------------------- |
| CUDA             | A `__global__` function launched as `kernel<<<grid, block>>>(...)`                | —                                                   |
| PTX              | A `.visible .entry` function                                                      | [vector add PTX](../rosetta/vector-add-in-5-irs.md) |
| Triton           | A `@triton.jit` Python function launched as `kernel[grid](...)`                   | [Triton model](triton-programming-model.md)         |
| Mojo             | A `def` launched with `ctx.enqueue_function[kernel](..., grid_dim=, block_dim=)`  | [samples/gpu_vadd.mojo](../samples/gpu_vadd.mojo)   |
| PyTorch eager    | Each op (`torch.add`) dispatches to a prebuilt kernel (ATen / cuBLAS / cuDNN)     | —                                                   |
| PyTorch Inductor | Generates new fused kernels: Triton on GPU, C++ on CPU                            | [torch.compile](torch-compile.md)                   |
| MLIR             | A `gpu.func` marked `kernel` inside a `gpu.module`, launched by `gpu.launch_func` | —                                                   |

A real generated kernel, from Inductor on this Mac (CPU, C++, one fused
kernel for `relu(a + b) * 2`):

```cpp
extern "C"  void kernel(const float* in_ptr0,
                       const float* in_ptr1,
                       float* out_ptr0)
{
    for(int64_t x0=static_cast<int64_t>(0LL); x0<static_cast<int64_t>(1024LL); x0+=static_cast<int64_t>(8LL))
    {
        auto tmp0 = at::vec::Vectorized<float>::loadu(in_ptr0 + static_cast<int64_t>(x0), static_cast<int64_t>(8));
        auto tmp1 = at::vec::Vectorized<float>::loadu(in_ptr1 + static_cast<int64_t>(x0), static_cast<int64_t>(8));
        auto tmp2 = tmp0 + tmp1;
        auto tmp3 = at::vec::clamp_min(tmp2, decltype(tmp2)(0));
        ...
```

## ⚠️ Common confusion

- **"Kernel" is overloaded.** Here it means a compute function. It is
  unrelated to the OS kernel, and to a _convolution_ kernel (the filter
  weights), which ML papers also call a kernel.
- **Kernel vs op.** An _op_ is the logical operation in the graph
  (`aten.add`). A _kernel_ is one concrete implementation for one device
  and dtype. One op can have many kernels.
- **Launch overhead matters for small tensors.** For tiny ops the launch
  can cost more than the math. CUDA Graphs and fusion both address that.

## 🔗 Related

- [Graph compiler vs kernel compiler](graph-vs-kernel-compiler.md)
- [GPU thread, warp, block, grid](../04-hardware/gpu-thread-warp-block-grid.md)
- [Fusion](../03-transformations/fusion.md)

---

✅ Verified against: PyTorch 2.5.1 (CPU) · Mojo 1.1.0 + MAX 26.6
