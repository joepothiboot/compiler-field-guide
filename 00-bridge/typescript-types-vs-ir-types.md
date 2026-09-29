# TypeScript Types vs IR Types 🏷️

> **One line:** TypeScript types are checked and then _erased_. IR types are
> never erased, because they decide which machine instruction runs.

## 🌉 From frontend

In TypeScript, `a + b` compiles to the same JS whether `a` is `number` or
`string`. The type only exists to catch mistakes, and the JS engine works out
the real type at runtime.

In an IR it is the other way round. `add i32` and `fadd float` are
**different instructions**, and they run on different hardware units
(the integer ALU and the floating-point unit). The type is part of the
operation.

## 🖼️ Picture

```
 TypeScript                          IR
 ──────────                          ──
 function add(a: number,             add_int   : add  i32   ── integer ALU
              b: number)             add_float : fadd float ── FP unit
   { return a + b }                  add_long  : add  i64   ── 64-bit ALU
        │
        │ tsc (types erased)         one source "+", three different
        ▼                            instructions, chosen from the types
 function add(a, b)
   { return a + b }                  the type also fixes the size:
        │                            i32 = 4 bytes, i64 = 8, float = 4
        ▼
 V8 guesses types at runtime
```

## 🔧 In each tool

Real LLVM IR for [samples/types.c](../samples/types.c) (`clang -O1`):

```llvm
define i32 @add_int(i32 noundef %0, i32 noundef %1) {
  %3 = add nsw i32 %1, %0
  ret i32 %3

define noundef float @add_float(float noundef %0, float noundef %1) {
  %3 = fadd float %0, %1
  ret float %3

define i64 @add_long(i64 noundef %0, i64 noundef %1) {
  %3 = add nsw i64 %1, %0
  ret i64 %3
```

`nsw` means "no signed wrap". C says signed overflow is undefined, so the
compiler is allowed to assume it never happens. TypeScript has no equivalent.

| Concept            | TypeScript            | LLVM IR                                     | MLIR                                                     | Triton                        | Mojo                                          |
| ------------------ | --------------------- | ------------------------------------------- | -------------------------------------------------------- | ----------------------------- | --------------------------------------------- |
| Integer            | `number` / `bigint`   | `i1`, `i8`, `i32`, `i64`                    | `i32`, `index`, `si8`/`ui8`                              | `tl.int32`                    | `Int`, `Int32`, `UInt8`                       |
| Float              | `number` (always f64) | `half`, `float`, `double`                   | `f16`, `bf16`, `f32`, `f64`                              | `tl.float16`, `tl.float32`    | `Float32`, `BFloat16`                         |
| Array / buffer     | `number[]`            | `ptr` + `load`/`store`                      | `memref<4xf32>`, `tensor<4xf32>`                         | pointer + block               | `List[T]`, pointers                           |
| Vector (SIMD)      | —                     | `<4 x float>`                               | `vector<4xf32>`                                          | a tile is implicitly a vector | `SIMD[DType.float32, 4]`                      |
| Generic `T`        | `<T>` (erased)        | No generics, only concrete types            | Types are concrete; the dialect can be generic           | `tl.constexpr` specialization | Parameters `[T: Trait]`, specialized per type |
| Signed vs unsigned | —                     | In the **op** (`sdiv`/`udiv`), not the type | Either, depending on dialect (`arith` puts it in the op) | Both                          | In the type (`Int` vs `UInt`)                 |

## ⚠️ Common confusion

- **LLVM `i32` has no sign.** The instruction decides: `sdiv` vs `udiv`,
  `icmp sgt` vs `icmp ugt`. That is why the SSA page shows
  `icmp sgt` (signed greater-than).
- **Generics are not erased either.** Mojo's `add[dtype: DType]` produces a
  separate compiled copy for every `dtype` you use. This is called
  _monomorphization_: the same idea as C++ templates, and the opposite of
  TypeScript generics.
- **`index`** in MLIR is an integer whose width depends on the target
  (64-bit on your Mac). It is used for loop counters and sizes.

## 🔗 Related

- [Types (MLIR)](../02-ir-design/types.md)
- [Parameters vs arguments (Mojo)](../06-mojo/parameters-vs-arguments.md)
- [SIMD and DType](../06-mojo/simd-and-dtype.md)

---

✅ Verified against: LLVM 23.1.1
