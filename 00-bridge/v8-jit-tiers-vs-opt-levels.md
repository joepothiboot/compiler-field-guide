# V8 JIT Tiers vs Optimization Levels 🚦

> **One line:** V8 starts fast and optimizes hot code later, at runtime. An
> ahead-of-time compiler picks one optimization level (`-O0` … `-O3`) before
> the program ever runs.

## 🌉 From frontend

Your JS goes through tiers inside V8: the **Ignition** interpreter starts it
immediately, then **Sparkplug**, **Maglev** and **TurboFan** compile hot
functions to better and better machine code as they get called more. TurboFan
can also _deoptimize_ if its assumptions about types turn out wrong.

Clang and LLVM choose the tradeoff up front, with a flag:

```
 V8 (decides at runtime)              clang / LLVM (decides at build time)
 ───────────────────────              ───────────────────────────────────
 Ignition    interpret, start now     -O0   no optimization, easy to debug
 Sparkplug   quick baseline code      -O1   cheap optimizations
 Maglev      mid-tier optimizer       -O2   the usual release setting
 TurboFan    full optimizer,          -O3   more aggressive (bigger code)
             may deoptimize           -Os/-Oz  optimize for size
```

The difference: V8 knows which functions are _actually_ hot, but has to
guess types. An AOT compiler knows the types exactly, but has to guess which
code is hot. (Profile-guided optimization, PGO, gives it a real profile.)

## 🖼️ Picture

What `-O2` does to [samples/vadd.c](../samples/vadd.c), in real numbers:

```
                 -O0                           -O2
 instructions    37 lines of IR                85 lines of IR
 per step        1 float                       4 × <4 x float> = 16 floats
 shape           one simple loop               vector loop + scalar
                                               remainder loop + checks

 more code is not slower: most of the extra code is the vector loop,
 which processes 16 elements per iteration instead of 1
```

Real compiler remark (`clang -O2 -Rpass=loop-vectorize`):

```
vadd.c:2:3: remark: vectorized loop (vectorization width: 4, interleaved count: 4)
```

Width 4 means 4 floats per SIMD register (128-bit NEON on Apple
Silicon). Interleaved count 4 means 4 of those registers per iteration.

## 🔧 In each tool

| Tool                    | When it compiles                                                                                       | How you choose the level                                |
| ----------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| V8                      | At runtime, by tier, per function                                                                      | Automatic                                               |
| Clang / LLVM            | Before running (AOT)                                                                                   | `-O0` … `-O3`, `-Os`                                    |
| MLIR                    | Whenever the tool that embeds it runs                                                                  | You list the passes yourself                            |
| Triton                  | JIT: the first time a kernel is called with new argument types/`constexpr` values; then cached on disk | Fixed pipeline; you tune `num_warps`, `num_stages`      |
| Mojo                    | `mojo run` compiles then runs (JIT); `mojo build` produces a binary (AOT)                              | `-O0` … `-O3` on `mojo build`; `-O3` is the default     |
| PyTorch `torch.compile` | JIT, on the first call with new input shapes                                                           | `mode="default"`, `"reduce-overhead"`, `"max-autotune"` |

## ⚠️ Common confusion

- **"JIT is slower than AOT."** Not necessarily. Triton and `torch.compile`
  are JITs so that they can specialize on the _actual_ shapes and GPU at
  runtime, which an AOT compiler cannot know.
- **"Deoptimization" has no AOT equivalent.** AOT code never falls back.
  If a value can be anything, the compiled code has to handle anything.
- **`-O0` IR is not in SSA form for local variables.** It uses
  `alloca`/`load`/`store`. See [SSA](../01-foundations/ssa.md) for how
  `mem2reg` fixes that.

## 🔗 Related

- [JIT vs AOT](../07-codegen-runtime/jit-vs-aot.md)
- [Vectorization](../03-transformations/vectorization.md)
- [Pass and pass manager](../03-transformations/pass-and-pass-manager.md)

---

✅ Verified against: LLVM 23.1.1 (Apple M2)
