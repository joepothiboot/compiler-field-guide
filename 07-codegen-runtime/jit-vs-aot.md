# JIT vs AOT ⚡

> **One line:** **AOT** (ahead-of-time) compiles before the program runs and
> ships a binary. A **JIT** (just-in-time) compiles while the program runs,
> so it can specialize on the actual inputs and hardware, at the cost of
> compiling during execution.

## 🌉 From frontend

AOT is `vite build`: you produce the bundle once and ship it. A JIT is V8
compiling your hot functions while the page runs, using types it actually
observed. ML compilers lean JIT because the facts that matter most (tensor
shapes, the exact GPU model) are only known at runtime.

## 🖼️ Picture

```
 AOT                                        JIT
 ───                                        ───
 source ─► compile ─► binary ─► run         source ─► run ─┬─► first call with new inputs:
          (once, on the build machine)                     │     compile specialized code,
                                                           │     cache it
 + no compile time at runtime                              └─► later calls: use the cache
 + one binary to test and ship
 - must handle every possible input         + specialize on real shapes, dtypes, GPU
                                            - first call is slow ("warm-up")
                                            - needs the compiler present at runtime
```

## 🔧 In each tool

**LLVM's JIT runs IR directly.** Real run of `lli` on
[samples/jit_hello.ll](../samples/jit_hello.ll), with no compile or link step:

```
$ lli jit_hello.ll
JIT says: 6 * 7 = 42
```

**Mojo does both:**

```bash
pixi run mojo run samples/simd_basics.mojo     # JIT: compile in memory, run
pixi run mojo build samples/simd_basics.mojo   # AOT: write an executable
```

**GPU kernels in Mojo** are compiled for the device when
`ctx.enqueue_function[kernel](...)` is first reached. On this Mac, that is
exactly where the missing Metal toolchain was reported (`cannot execute tool
'metal' due to missing Metal Toolchain`): the JIT step needs the device
compiler at runtime.

| Tool            | Mode                                                                                              |
| --------------- | ------------------------------------------------------------------------------------------------- |
| Clang / `llc`   | AOT                                                                                               |
| `lli`, LLVM ORC | JIT (ORC is the library that JIT-compiling systems embed)                                         |
| Mojo            | `mojo run` (JIT) and `mojo build` (AOT); GPU kernels JIT per device                               |
| Triton          | JIT on first call per (argument types, `constexpr` values); cached on disk in `~/.triton/cache`   |
| `torch.compile` | JIT on first call, with guards; recompiles when guards fail. `torch.export` / AOTInductor for AOT |
| CUDA            | `nvcc` AOT to SASS, plus PTX that the driver can JIT for newer GPUs                               |
| V8              | Tiered JIT (see [V8 tiers vs opt levels](../00-bridge/v8-jit-tiers-vs-opt-levels.md))             |

## ⚠️ Common confusion

- **Benchmarks must skip the first call** for JIT systems. The first call
  includes compile time. (`mojo run` compiles the whole program before
  `main` starts, so the Mojo timings in this guide don't include compile
  time. The cache and reduction samples also time a second, warm round.)
- **JIT caches are keyed on specializations.** Change a shape and you may
  recompile. With `torch.compile`, watch `TORCH_LOGS="recompiles"`.
- **PTX is a JIT format too.** A binary that ships PTX can be compiled by
  the NVIDIA driver for a GPU that did not exist when it was built.

## 🔗 Related

- [V8 JIT tiers vs optimization levels](../00-bridge/v8-jit-tiers-vs-opt-levels.md)
- [torch.compile](../05-ml-compilers/torch-compile.md)
- [PTX, ptxas and SASS](ptx-ptxas-and-sass.md)

---

✅ Verified against: LLVM 23.1.1 (`lli`) · Mojo 1.1.0
