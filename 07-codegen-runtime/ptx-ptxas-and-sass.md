# PTX, ptxas and SASS 🟢

> **One line:** **PTX** is NVIDIA's _virtual_ GPU assembly: stable,
> documented and what compilers emit. **`ptxas`** compiles PTX into **SASS**,
> the real machine code of one GPU generation. The NVIDIA driver can also
> do that step at runtime.

## 🌉 From frontend

PTX is to SASS what JavaScript is to the machine code V8 produces: a
portable format you ship, compiled by the platform to whatever the actual
hardware needs. Like JS, PTX runs on GPUs newer than the one you built for.

## 🖼️ Picture

```
 Mojo / Triton / CUDA C++ / MLIR
            │
            ▼
       LLVM IR  (+ nvvm intrinsics)
            │  LLVM NVPTX backend (llc, or inside mojo / triton)
            ▼
 PTX  .target sm_80        virtual ISA: unlimited virtual registers (%r<15>),
            │              portable across GPU generations
            │  ptxas  (NVIDIA, closed source; offline or inside the driver)
            ▼
 SASS  (cubin)             real ISA for ONE architecture (e.g. sm_80 = A100):
                           physical registers, scheduling, instruction encoding
```

## 🔧 In each tool

PTX produced in this guide. All real output, cross-compiled on a Mac
with no NVIDIA GPU:

| Source                                                                          | Produced by                                        | Shows                                       |
| ------------------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------- |
| [samples/vadd_gpu.ll](../samples/vadd_gpu.ll)                                   | `llc -mcpu=sm_80`                                  | `%ctaid.x`, `%tid.x`, `ld.global`, `.entry` |
| [samples/gpu_vadd.mojo](../samples/gpu_vadd.mojo)                               | `mojo build --emit asm --target-accelerator=sm_80` | the same kernel from Mojo                   |
| [samples/gpu_block_sum.mojo](../samples/gpu_block_sum.mojo)                     | same                                               | `.shared`, `st.shared`, `bar.sync`          |
| [samples/gpu_warp_and_coalescing.mojo](../samples/gpu_warp_and_coalescing.mojo) | same                                               | `shfl.sync.bfly`, address strides           |
| [samples/tensor_core_mma.ll](../samples/tensor_core_mma.ll)                     | `llc -mcpu=sm_80`                                  | `mma.sync.aligned.m16n8k16`                 |

Reading a PTX kernel header, from the Mojo vector add:

```
.version 8.1                          ← PTX ISA version
.target sm_80                         ← minimum GPU architecture
.address_size 64
.visible .entry gpu_vadd_vadd_kernel_...(      ← .entry = a kernel the host can launch
	.param .u64 .ptr .align 1 ..._param_0,     ← kernel arguments live in .param space
	...
)
{
	.reg .pred 	%p<2>;                ← virtual registers: 2 predicates,
	.reg .b32 	%r<7>;                   7 × 32-bit, 15 × 64-bit.
	.reg .b64 	%rd<15>;                 ptxas assigns the physical ones
```

Useful PTX vocabulary from these samples:

| PTX                             | Meaning                                             |
| ------------------------------- | --------------------------------------------------- |
| `%tid.x`, `%ntid.x`, `%ctaid.x` | thread index, block size, block index               |
| `ld.global` / `st.global`       | global memory access                                |
| `ld.shared` / `st.shared`       | shared memory access                                |
| `ld.param`                      | read a kernel argument                              |
| `cvta.to.global`                | convert a generic address to a global-space address |
| `setp.ge.s32 %p1, a, b`         | set predicate: `p1 = (a >= b)`                      |
| `@%p1 bra L`                    | branch if predicate true                            |
| `bar.sync 0`                    | block-wide barrier                                  |
| `shfl.sync.bfly`                | warp shuffle (butterfly pattern)                    |
| `mma.sync.aligned...`           | tensor core matrix multiply-accumulate              |
| `mad.lo.s32`                    | integer multiply-add                                |

**SASS is not shown** because `ptxas`, `cuobjdump` and `nvdisasm` come
with the CUDA toolkit, which does not run on macOS. On a Linux machine
with CUDA, `ptxas -arch=sm_80 kernel.ptx -o kernel.cubin` followed by
`cuobjdump -sass kernel.cubin` shows it, and `ptxas -v` prints the real
register count used for [occupancy](../04-hardware/occupancy.md).

## ⚠️ Common confusion

- **PTX register counts are not real.** `%r<7>` is a declaration of
  virtual registers. Only `ptxas` knows the physical count.
- **`.target sm_80` is a minimum.** PTX for `sm_80` can be JIT-compiled by
  the driver for `sm_90`, but not for `sm_70`.
- **AMD and Apple have their own paths.** AMD GPUs use LLVM's AMDGPU
  backend straight to machine code (no PTX-like layer). Apple GPUs go
  through Metal's toolchain (the `.ll` sidecar mentioned by `mojo build --help`).

## 🔗 Related

- [Vector add in 5 IRs](../rosetta/vector-add-in-5-irs.md)
- [JIT vs AOT](jit-vs-aot.md)
- [Tensor cores](../04-hardware/tensor-cores.md)

---

✅ Verified against: LLVM 23.1.1 NVPTX backend · Mojo 1.1.0 + MAX 26.6
(PTX only; SASS needs the CUDA toolkit, not available on macOS)
