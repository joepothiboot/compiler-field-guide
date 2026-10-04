# Opcodes by Category 🧩

> **One line:** Every op in every IR is one of about six verbs: move, compute,
> compare, branch, group, or sync. Only the spelling changes.

The "Seen here" column counts occurrences in [samples/](../samples/) (`—`
means standard vocabulary, not in the samples).

## 1. 📦 Memory: where is the data?

| Idea              | LLVM IR                    | MLIR                             | PTX                 | Triton            | Seen here    |
| ----------------- | -------------------------- | -------------------------------- | ------------------- | ----------------- | ------------ |
| Read one element  | `load`                     | `memref.load`, `affine.load`     | `ld.global`         | `tl.load`         | 28, 8 (MLIR) |
| Write one element | `store`                    | `memref.store`, `affine.store`   | `st.global`         | `tl.store`        | 10, 3        |
| Address math      | `getelementptr`            | `memref.subview`, `affine.apply` | `add.s64`, `mad`    | `ptr + offs`      | 36, 6        |
| Allocate          | `alloca`                   | `memref.alloc`, `memref.alloca`  | `.shared`, `.local` | `tl.zeros` (regs) | 1 (alloc)    |
| Copy a region     | `llvm.memcpy`              | `memref.copy`                    | `cp.async`          | —                 | 1            |
| Size query        | —                          | `memref.dim`, `tensor.dim`       | —                   | `x.shape`         | 6            |
| Reinterpret       | `bitcast`, `addrspacecast` | `memref.cast`, `memref.view`     | `cvta`              | `.to(...)`        | 1            |

## 2. ➕ Compute: what is calculated?

| Idea               | LLVM IR                                    | MLIR                                          | PTX                  | Seen here (MLIR) |
| ------------------ | ------------------------------------------ | --------------------------------------------- | -------------------- | ---------------- |
| Integer add / mul  | `add`, `mul`                               | `arith.addi`, `arith.muli`                    | `add.s32`, `mul.lo`  | 13, 8            |
| Float add / mul    | `fadd`, `fmul`                             | `arith.addf`, `arith.mulf`                    | `add.f32`, `mul.f32` | 26, 13           |
| Fused multiply-add | `llvm.fma`, `fmuladd`                      | `math.fma`, `vector.fma`                      | `fma.rn.f32`         | —                |
| Max / min          | `llvm.maxnum`, `select`                    | `arith.maximumf`, `arith.maxsi`               | `max.f32`            | 3, 2             |
| Compare            | `icmp`, `fcmp`                             | `arith.cmpi`, `arith.cmpf`                    | `setp`               | 11               |
| Choose a value     | `select`                                   | `arith.select`                                | `selp`               | 2                |
| Constant           | literal operand                            | `arith.constant`                              | immediate            | 65               |
| Convert type       | `zext`, `sext`, `trunc`, `sitofp`, `fpext` | `arith.extsi`, `arith.sitofp`, `arith.truncf` | `cvt`                | —                |
| Transcendental     | `llvm.exp`, `llvm.sqrt`                    | `math.exp`, `math.sqrt`, `math.tanh`          | `ex2.approx`, `sqrt` | —                |
| Matrix multiply    | —                                          | `linalg.matmul`, `vector.contract`            | `mma.sync`, `wgmma`  | 6 (linalg)       |
| Matrix multiply    | `llvm.nvvm.mma...`                         | `nvgpu.mma.sync`, `tt.dot`                    | `mma.m16n8k16`       | 2 (nvvm), 1 (tt) |

## 3. 🔀 Control flow: in what order?

| Idea                | LLVM IR        | MLIR                              | Seen here        |
| ------------------- | -------------- | --------------------------------- | ---------------- |
| Jump                | `br`           | `cf.br`, `llvm.br`                | 50 (LLVM), 13, 3 |
| Conditional jump    | `br i1`        | `cf.cond_br`, `llvm.cond_br`      | 8, 1             |
| Merge value (φ)     | `phi`          | block arguments                   | 31 (LLVM)        |
| Structured loop     | (loop = CFG)   | `scf.for`, `affine.for`           | 19, 11           |
| Structured branch   | (CFG)          | `scf.if`                          | 4                |
| Loop result         | `phi`          | `scf.yield`                       | 11               |
| Parallel loop       | metadata       | `scf.parallel`, `affine.parallel` | 4                |
| Reduction in a loop | `phi` + `fadd` | `scf.reduce`                      | 2                |
| Call                | `call`         | `func.call`, `llvm.call`          | 5, 2             |
| Return              | `ret`          | `func.return`, `llvm.return`      | 3, 2             |

## 4. 🧮 Vectors and shapes: how wide, how arranged?

| Idea                | LLVM IR                           | MLIR                                  | Mojo             | Seen here |
| ------------------- | --------------------------------- | ------------------------------------- | ---------------- | --------- |
| Vector load / store | `load <4 x float>`                | `vector.load`, `vector.transfer_read` | `SIMD[...]` load | 2, 1      |
| Fill all lanes      | `insertelement` + `shufflevector` | `vector.broadcast`, `vector.splat`    | `SIMD[...](x)`   | —         |
| Horizontal reduce   | `llvm.vector.reduce.fadd`         | `vector.reduction`                    | `.reduce_add()`  | 13, 2     |
| Masked access       | `llvm.masked.load`                | `vector.maskedload`, `vector.mask`    | `mask=` argument | —         |
| Tensor element      | —                                 | `tensor.extract`, `tensor.insert`     | —                | 2, 2      |
| New tensor          | —                                 | `tensor.empty`                        | —                | 4         |
| Generic loop nest   | —                                 | `linalg.generic`, `linalg.yield`      | —                | 8, 4      |

## 5. 🎛️ GPU: who does it in parallel?

| Idea            | CUDA              | MLIR `gpu`                      | PTX special reg | Mojo                                  | Seen here |
| --------------- | ----------------- | ------------------------------- | --------------- | ------------------------------------- | --------- |
| Thread index    | `threadIdx.x`     | `gpu.thread_id x`               | `%tid.x`        | `thread_idx.x`                        | 3, 8      |
| Block index     | `blockIdx.x`      | `gpu.block_id x`                | `%ctaid.x`      | `block_idx.x`                         | 5, 8      |
| Block size      | `blockDim.x`      | `gpu.block_dim x`               | `%ntid.x`       | `block_dim.x`                         | 3, 14     |
| Grid size       | `gridDim.x`       | `gpu.grid_dim x`                | `%nctaid.x`     | `grid_dim.x`                          | 3         |
| Launch          | `<<<g, b>>>`      | `gpu.launch`, `gpu.launch_func` | —               | `ctx.enqueue_function`                | 5, 3      |
| Barrier         | `__syncthreads()` | `gpu.barrier`                   | `bar.sync`      | `barrier()`                           | 3 (Mojo)  |
| Kernel function | `__global__`      | `gpu.func`, `gpu.module`        | `.entry`        | `fn kernel(...)`                      | 3, 5      |
| Shared memory   | `__shared__`      | `memref<..., 3>`                | `.shared`       | `stack_allocation[address_space=...]` | 2         |
| Warp shuffle    | `__shfl_sync`     | `gpu.shuffle`                   | `shfl.sync`     | `warp.shuffle_*`                      | —         |

## 6. 🧱 Structure: containers

| Idea         | LLVM IR          | MLIR                                | Seen here     |
| ------------ | ---------------- | ----------------------------------- | ------------- |
| Function     | `define`         | `func.func`, `llvm.func`            | 48, 4         |
| Module       | `module`         | `builtin.module`, `gpu.module`      | 5 (gpu)       |
| Global       | `@name = global` | `memref.global`, `llvm.mlir.global` | —             |
| Pointer type | `ptr`            | `llvm.ptr`, `!tt.ptr<f32>`          | 14 (llvm.ptr) |

## 🧠 The pattern

`<dialect>.<verb>` is how every MLIR name is built:

| Dialect prefix       | Domain                  | Verbs you will meet                                |
| -------------------- | ----------------------- | -------------------------------------------------- |
| `arith.`             | scalar math             | `add` `mul` `cmp` `select` `constant`              |
| `math.`              | scalar functions        | `exp` `sqrt` `fma` `tanh`                          |
| `memref.`            | memory buffers          | `load` `store` `alloc` `dim` `subview` `copy`      |
| `tensor.`            | immutable values        | `empty` `extract` `insert` `collapse_shape`        |
| `vector.`            | SIMD                    | `broadcast` `reduction` `contract` `transfer_read` |
| `scf.`               | structured control flow | `for` `if` `while` `yield`                         |
| `affine.`            | analyzable loops        | `for` `load` `store` `apply`                       |
| `linalg.`            | tensor algebra          | `matmul` `generic` `fill` `yield`                  |
| `cf.`                | unstructured branches   | `br` `cond_br`                                     |
| `gpu.`               | GPU abstraction         | `launch` `thread_id` `barrier`                     |
| `nvvm.`/`llvm.nvvm.` | NVIDIA intrinsics       | `read.ptx.sreg.tid.x` `mma...`                     |
| `tt.`                | Triton IR               | `load` `store` `dot` `make_range`                  |
| `func.`              | functions               | `func` `call` `return`                             |

If you see a new op, split it at the dot: dialect tells you the domain, the
verb is nearly always one of the words above.

## ⚠️ Common confusion

- **`load` is not one thing.** `memref.load` reads one element; `tl.load`
  reads a whole block of pointers; `vector.load` reads N contiguous lanes.
- **`phi` and block arguments are the same idea** with different spelling.
  See [ssa](../01-foundations/ssa.md).
- **`scf.for` and `affine.for` look identical** but `affine.for` bounds must
  be affine expressions, which unlocks analysis.

## 🔗 Related

[value-names](value-names.md) · [operation](../02-ir-design/operation.md) ·
[dialect](../02-ir-design/dialect.md) ·
[vector-add in 5 IRs](../rosetta/vector-add-in-5-irs.md)
