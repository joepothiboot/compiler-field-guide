# Question Bank: GPU and ML Compilers 🖥️

Answer out loud, then open the fold.

---

### 1. Explain thread, warp, block, grid.

<details><summary>Answer</summary>

A thread runs one instance of the kernel. A warp is 32 threads executing in
lockstep (NVIDIA; Apple SIMD-groups are also 32; AMD wavefronts are 32 or 64).
A block is up to 1024 threads that share shared memory and can `barrier()`.
A grid is all blocks of a launch, with no synchronization between blocks
inside a kernel. Global index = `block_idx.x * block_dim.x + thread_idx.x`,
which is literally `mad.lo.s32 %r5, %ctaid, %ntid, %tid` in PTX.

→ [GPU thread, warp, block, grid](../04-hardware/gpu-thread-warp-block-grid.md)
</details>

### 2. What is warp divergence?

<details><summary>Answer</summary>

When threads of one warp take different sides of a branch, the warp executes
both paths, masking threads off on each. Throughput drops in proportion to
the number of distinct paths.
</details>

### 3. What is memory coalescing? Show it.

<details><summary>Answer</summary>

When a warp's 32 threads access consecutive addresses, the hardware merges
them into a few wide transactions. Scattered addresses need one transaction
each. In my PTX, the only difference between the coalesced and the strided
copy kernel is `shl.b64 ..., 2` (×4 bytes) vs `shl.b64 ..., 7` (×128 bytes).
Same instruction, very different cost at runtime.

→ [Memory coalescing](../04-hardware/memory-coalescing.md)
</details>

### 4. What is shared memory and why use it?

<details><summary>Answer</summary>

Fast, on-chip, per-block scratchpad (32 KB per block on the M2 here, up to
164 KB per SM on A100) that you manage explicitly: load a tile once from
global memory, `barrier()`, reuse it many times. It is used for reductions and
matmul tiles, and to fix uncoalesced patterns such as transposes. Watch for
bank conflicts.

→ [Shared memory and registers](../04-hardware/shared-memory-and-registers.md)
</details>

### 5. Why do you need `barrier()` in a shared-memory reduction?

<details><summary>Answer</summary>

Without it, a thread can read `shared[t + stride]` before the owning thread
has written it. The result is a data race that is wrong only sometimes. In
PTX it is `bar.sync 0`.
</details>

### 6. How does a warp-level reduction work without shared memory?

<details><summary>Answer</summary>

Shuffle instructions exchange registers between lanes. A butterfly pattern
halves the distance each step: 16, 8, 4, 2, 1, which is 5 steps for 32
values. My Mojo `warp.sum` compiles to `shfl.sync.bfly.b32` with offsets
16, 8, 4, 2, 1, each followed by `add.f32`.
</details>

### 7. What is occupancy? Is higher always better?

<details><summary>Answer</summary>

Resident warps per SM divided by the maximum. It is limited by registers per
thread, shared memory per block and block size (A100: 65,536 registers /
2,048 threads = 32 registers per thread for 100%). It is not always better:
matmul kernels deliberately use many registers per thread for large tiles
and run at lower occupancy, because data reuse matters more.

→ [Occupancy](../04-hardware/occupancy.md)
</details>

### 8. What are tensor cores? How do you reach them?

<details><summary>Answer</summary>

Matrix-multiply units: one warp-wide instruction computes e.g.
m16n8k16 = 2,048 multiply-adds in low precision with f32 accumulation. You
reach them through `mma`/`wgmma` intrinsics, Triton's `tl.dot`, or library
kernels, never through scalar loops. Real PTX from LLVM:
`mma.sync.aligned.m16n8k16.row.col.f32.f16.f16.f32`.

→ [Tensor cores](../04-hardware/tensor-cores.md)
</details>

### 9. PTX vs SASS?

<details><summary>Answer</summary>

PTX is NVIDIA's virtual ISA, with unlimited virtual registers, portable
across GPU generations, and the thing compilers emit. `ptxas` (or the
driver's JIT) compiles it to SASS, the real machine code for one
architecture, and does the real register allocation.

→ [PTX, ptxas and SASS](../07-codegen-runtime/ptx-ptxas-and-sass.md)
</details>

### 10. Graph compiler vs kernel compiler?

<details><summary>Answer</summary>

A graph compiler optimizes the whole model: fusion decisions, layouts,
memory planning, launch order (Inductor's scheduler, XLA, MAX Graph). A kernel
compiler generates fast code for one (fused) op: tiling, vectorization,
thread mapping (Triton, Mojo kernels). `torch.compile` = Inductor (graph)
writing Triton (kernel).

→ [Graph vs kernel compiler](../05-ml-compilers/graph-vs-kernel-compiler.md)
</details>

### 11. Explain Triton's programming model vs CUDA's.

<details><summary>Answer</summary>

CUDA: you write code for one thread. Triton: you write code for one
**program** that processes a whole **block** of data with block-level ops
(`tl.load`, `tl.dot`, `tl.sum`), masks out-of-range lanes, and lets the
compiler choose the thread mapping, coalescing and shared memory. `BLOCK` is
a data size, and threads = `num_warps × 32`.

→ [Triton programming model](../05-ml-compilers/triton-programming-model.md)
</details>

### 12. What happens when you call `torch.compile(fn)`?

<details><summary>Answer</summary>

Dynamo traces Python bytecode into an FX graph with guards. AOTAutograd
builds forward/backward graphs. Inductor decomposes, lowers, fuses
(scheduler) and generates code: Triton on GPU, C++ on CPU. On my Mac,
`relu(a+b)*2` became one `cpp_fused_add_mul_relu_0` kernel with 8-wide
`Vectorized<float>` and no intermediate buffers. It recompiles when guards
fail (e.g. a new shape).

→ [torch.compile](../05-ml-compilers/torch-compile.md)
</details>

### 13. What's a graph break and why does it matter?

<details><summary>Answer</summary>

Code Dynamo can't trace splits the graph, and the gap runs eagerly. Smaller
graphs mean fewer fusion opportunities and more launches.
`TORCH_LOGS="graph_breaks"` shows them.
</details>

### 14. What are strides? What is a non-contiguous tensor?

<details><summary>Answer</summary>

Strides give the element distance per dimension. Transposing swaps strides
without copying: `(4, 1)` → `(1, 4)`, and the result is not contiguous.
`expand` uses stride 0 to broadcast without allocating. `.contiguous()`
copies into row-major order. All of this is real PyTorch output in the guide.

→ [Layout and strides](../05-ml-compilers/layout-and-strides.md)
</details>

### 15. NCHW vs NHWC?

<details><summary>Answer</summary>

The same 4-D shape with different memory order: channels outermost (NCHW)
or innermost (NHWC, "channels last"). NHWC keeps a pixel's channels
together, which often suits convolutions on GPUs and tensor cores. Real
strides: `(12, 4, 2, 1)` vs `(12, 1, 6, 3)`.
</details>

### 16. Why do ML compilers prefer static shapes and JIT?

<details><summary>Answer</summary>

Static shapes give exact loop bounds, full unrolling and fewer bounds
checks, and let the compiler pick exact tile sizes (the MLIR vectorizer needed
no remainder loop for 1024 elements). The real shapes are only known at
runtime, so JITs (Triton, `torch.compile`) specialize on them and cache the
result.

→ [JIT vs AOT](../07-codegen-runtime/jit-vs-aot.md)
</details>

### 17. What is autotuning and what are its pitfalls?

<details><summary>Answer</summary>

Compile several configs, time each on real hardware and shapes, keep the
fastest (e.g. `@triton.autotune(configs, key=[M, N, K])`). Pitfalls: timing
without warm-up, single noisy runs, tuning on a different GPU or shape, and a
search space that doesn't contain the good strategy. My tile-size sweep
never found the register-blocking win.

→ [Autotuning](../05-ml-compilers/autotuning.md)
</details>

### 18. Walk a matmul from `linalg.matmul` to PTX. What's lost at each level?

<details><summary>Answer</summary>

`linalg.matmul` (knows it's a matmul) → `scf.parallel` + `scf.for` (knows
which loops are parallel) → `gpu.launch` (thread mapping) → outlined
`gpu.func` → `llvm` + PTX (only instructions). Real upstream output shows the
naive mapping `.maxntid 1, 1, 1`: 4,096 blocks of 1 thread. That is why
tiling and tensor-core decisions happen high up.

→ [A tensor's journey](../maps/tensor-journey-matmul-to-ptx.md)
</details>

### 19. How do you make a kernel's results reproducible?

<details><summary>Answer</summary>

Fix the reduction order: avoid atomics for float sums, use deterministic tree
reductions, and don't let the compiler reassociate (no fast-math). Test
against a reference with an explicit tolerance, or bit-exactly when the order
is preserved, as all my matmul variants are (`diff: 0.0`).
</details>

### 20. Why is Mojo interesting from a compiler perspective?

<details><summary>Answer</summary>

It is a language built on MLIR, so library code (SIMD, layouts, GPU kernels)
is written with compile-time parameters and `comptime`, specialized per
type and target, and lowered through MLIR/LLVM to CPU and GPU. Kernel-level
control like CUDA, generic library code like C++ templates, with Python-like
syntax.
</details>
