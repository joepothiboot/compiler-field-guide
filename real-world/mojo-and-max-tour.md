# Mojo and MAX Codebase Tour 🏎️

> **Where the Mojo standard library and MAX kernels live in
> `modular/modular`.** This is the code a Mojo Libraries Engineer works
> in, and reading it is the best preparation for that role. Paths were
> checked on GitHub in September 2026. They match the import paths that
> compiled in this guide (`std.*`, `max.gpu.*`, `layout`).

## 🗺️ The top level

```
modular/
├── Mojo/
│   ├── stdlib/
│   │   ├── std/                  the `std` package: `from std.sys import ...`
│   │   │   ├── simd.mojo         SIMD[dtype, width]: the core numeric type
│   │   │   ├── builtin/          Int, Bool, DType (dtype.mojo), range, device_passable.mojo ...
│   │   │   ├── collections/      list.mojo, array.mojo (Array, was InlineArray), dict.mojo, span.mojo ...
│   │   │   ├── memory/           pointer.mojo, unsafe_pointer.mojo, stack_allocation.mojo, address_space.mojo
│   │   │   ├── algorithm/        functional.mojo (vectorize, parallelize ...)
│   │   │   ├── sys/              simd_width_of, CompilationTarget, has_accelerator ...
│   │   │   └── utils/            variant.mojo, index.mojo, static_tuple.mojo ...
│   │   ├── benchmarks/           stdlib benchmarks, by module
│   │   └── test/                 stdlib tests
│   └── proposals/                design documents for language changes
└── max/
    ├── mojo/max/gpu/             `from max.gpu import ...`
    │   ├── primitives/           id.mojo (thread_idx, block_idx ...), warp.mojo, block.mojo
    │   ├── host/                 device_context.mojo (DeviceContext), _metal.mojo, _nvidia_cuda.mojo ...
    │   └── memory/, sync/, intrinsics.mojo
    └── kernels/src/              the kernel library
        ├── layout/               layout.mojo, layout_tensor.mojo, tensor_core.mojo, swizzle.mojo ...
        ├── linalg/               matmul/ (cpu, gpu, vendor), gemv.mojo, packing.mojo, transpose.mojo ...
        └── nn/                   softmax.mojo, normalization.mojo, attention/, conv/, topk.mojo ...
```

## 🔎 Concept → file

| Concept (guide page)                                           | File in `modular/modular`                                                   |
| -------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [SIMD and DType](../06-mojo/simd-and-dtype.md)                 | `Mojo/stdlib/std/simd.mojo`, `Mojo/stdlib/std/builtin/dtype.mojo`           |
| [Ownership](../06-mojo/ownership-and-transfer.md), pointers    | `Mojo/stdlib/std/memory/`                                                   |
| `List`, `Array`, `Span`                                        | `Mojo/stdlib/std/collections/`                                              |
| `vectorize`                                                    | `Mojo/stdlib/std/algorithm/functional.mojo`                                 |
| [Shared memory](../04-hardware/shared-memory-and-registers.md) | `Mojo/stdlib/std/memory/stack_allocation.mojo`, `address_space.mojo`        |
| [Device-passable types](../06-mojo/max-and-mojo-kernels.md)    | `Mojo/stdlib/std/builtin/device_passable.mojo` (the `Int32` vs `Int` error) |
| [GPU ids, warps](../04-hardware/gpu-thread-warp-block-grid.md) | `max/mojo/max/gpu/primitives/id.mojo`, `warp.mojo`                          |
| `DeviceContext`, kernel launch                                 | `max/mojo/max/gpu/host/device_context.mojo`                                 |
| [LayoutTensor](../06-mojo/max-and-mojo-kernels.md)             | `max/kernels/src/layout/layout_tensor.mojo`, `layout.mojo`                  |
| [Tensor cores](../04-hardware/tensor-cores.md)                 | `max/kernels/src/layout/tensor_core.mojo`                                   |
| [Matmul](../rosetta/matmul-naive-tiled-fused.md)               | `max/kernels/src/linalg/matmul/` (`cpu/` for CPU micro-kernels, `gpu/`)     |
| Softmax (a reduction)                                          | `max/kernels/src/nn/softmax.mojo`                                           |

## 📖 How to read it (role-focused)

1. **`simd.mojo` first.** Almost everything in the stdlib is generic over
   `dtype` and `width`. Notice how parameters, `comptime` and traits are
   used: this is the style the role expects.
2. **Then `algorithm/functional.mojo`.** `vectorize` is the stdlib version
   of the SIMD-body + scalar-tail loop written by hand in
   [samples/vadd.mojo](../samples/vadd.mojo).
3. **Then a CPU matmul** in `max/kernels/src/linalg/matmul/cpu/`. Compare
   its micro-kernel with the register-blocked kernel in
   [samples/matmul_cpu.mojo](../samples/matmul_cpu.mojo).
4. **Benchmarks and tests next to the code** (`Mojo/stdlib/benchmarks/`,
   `Mojo/stdlib/test/`) show how the stdlib team measures and verifies
   changes. The same habit is used throughout this guide.

## 🔗 Related

- [MAX and Mojo kernels](../06-mojo/max-and-mojo-kernels.md)
- [Mojo interview questions](../interview/question-bank-mojo.md)

---

✅ Paths verified on GitHub (`modular/modular`, default branch, 2026-09);
import paths verified by compiling with Mojo 1.1.0 + MAX 26.6
