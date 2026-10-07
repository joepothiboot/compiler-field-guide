# Inlining 📥

> **One line:** Inlining replaces a function call with a copy of the
> function's body. It removes call overhead and, more importantly, lets
> every other optimization see through the call.

## 🖼️ Picture

Real `mlir-opt --inline` on [samples/inline.mlir](../samples/inline.mlir):

```
 BEFORE                                         AFTER --inline
 ──────                                         ──────────────
 func.func private @square(%v: f32) -> f32 {
   %r = arith.mulf %v, %v : f32                  (removed: private and now unused)
   return %r : f32
 }

 func.func @sum_of_squares(%a, %b) -> f32 {     func.func @sum_of_squares(%arg0, %arg1) -> f32 {
   %x = func.call @square(%a) ────────────────►   %0 = arith.mulf %arg0, %arg0 : f32
   %y = func.call @square(%b) ────────────────►   %1 = arith.mulf %arg1, %arg1 : f32
   %s = arith.addf %x, %y                          %2 = arith.addf %0, %1 : f32
   return %s                                       return %2 : f32
 }                                               }
```

The MLIR inliner also deleted `@square`: it is `private` (nothing outside
the module can call it), and after inlining it has no callers left.

**Why this matters beyond saving a call:** after inlining, `%0` and `%1`
sit next to `%2` in one function. CSE, fusion and vectorization can now
work across what used to be a function boundary.

## 🔧 In each tool

| Tool   | Inlining                                                                                                                             |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| LLVM   | `inline` pass with a cost model (size vs benefit); `alwaysinline`, `noinline` attributes                                             |
| MLIR   | `--inline`; dialects opt in through `DialectInlinerInterface` (which ops can be inlined, how to handle terminators)                  |
| Triton | Functions called from a `@triton.jit` kernel are inlined into it by default; the kernel is compiled as one function                  |
| Mojo   | `@always_inline` decorator forces it; used heavily in the stdlib for small helpers (nano-dsp's `Tensor.rank()` and `numel()` use it) |

## ⚠️ Common confusion

- **More inlining is not always better.** Each copy grows the code. Too
  much can overflow the instruction cache and slow things down, and it
  increases compile time. Compilers use a cost model to decide.
- **Recursive functions** cannot be fully inlined.
- **GPU kernels are almost always fully inlined**, because function calls
  on GPUs are expensive (they use stack memory and limit optimizations).

## 🧪 Seen in my projects

- nano-dsp-mlir: `mojo/nanodsp/tensor.mojo` marks `rank`, `numel` and
  `__getitem__` with `@always_inline`

## 🔗 Related

- [CSE and DCE](cse-and-dce.md)
- [Fusion](fusion.md)
- [ABI and calling conventions](../07-codegen-runtime/abi-and-calling-conventions.md): the cost that inlining removes

---

✅ Verified against: MLIR 23.1.1
