# Parameters vs Arguments 🎚️

> **One line:** In Mojo, **parameters** go in square brackets `[...]` and are
> known at **compile time**. **Arguments** go in parentheses `(...)` and are
> known at **runtime**. Each distinct set of parameter values produces a
> separately compiled, specialized version of the function or type.

## 🖼️ Picture

```
      compile time            runtime
      ┌──────────┐            ┌────────┐
 repeat[3]                   ("hello")
 SIMD[DType.float32, 4]      (1, 2, 3, 4)
 matmul_regblock[N, KC]      (a, b, c)
      │
      └─► compiler generates one version per distinct parameter set:
            repeat[3]   → body unrolled 3 times
            repeat[5]   → a different function, unrolled 5 times

 types can be parameters too:  Vec[dtype: DType, size: Int]
 parameters can have defaults computed at compile time:
   width: Int = simd_width_of[dtype]()     → 4 for f32, 16 for i8 on this M2
```

## 🔧 In each tool

Real run of [samples/mojo_parameters.mojo](../samples/mojo_parameters.mojo):

```mojo
def repeat[count: Int](msg: String):
    comptime for i in range(count):          # unrolled `count` times
        print("  ", i, msg)

@fieldwise_init
struct Vec[dtype: DType, size: Int](Copyable):   # a parametric struct
    var data: SIMD[Self.dtype, Self.size]
    def dot(self, other: Self) -> Scalar[Self.dtype]:
        return (self.data * other.data).reduce_add()

def sum_simd[dtype: DType, width: Int = simd_width_of[dtype]()](
    x: SIMD[dtype, width]
) -> Scalar[dtype]:
    return x.reduce_add()
```

```
   0 hello
   1 hello
   2 hello
  dot = 100.0
  sum f32 x native: 4.0        ← 4 lanes of 1.0
  sum i8  x native: 16         ← 16 lanes of 1
```

Parameters are also how the matmul benchmark in
[samples/matmul_cpu.mojo](../samples/matmul_cpu.mojo) sweeps tile sizes:
`matmul_tiled[N, T]` is a new compiled function for every `(N, T)`.

| Language   | Compile-time inputs                            | Example                          |
| ---------- | ---------------------------------------------- | -------------------------------- |
| Mojo       | Parameters `[...]`                             | `SIMD[DType.float32, 4]`         |
| C++        | Template parameters `<...>` (types and values) | `std::array<float, 4>`           |
| Rust       | Generics + const generics                      | `[f32; N]` with `const N: usize` |
| Triton     | `tl.constexpr` arguments                       | `BLOCK: tl.constexpr`            |
| MLIR       | Attributes (compile-time constants on ops)     | `arith.constant 4 : index`       |
| TypeScript | Generics (types only, erased)                  | `Array<number>`                  |

## ⚠️ Common confusion

- **Parameters must be known when compiling.** You cannot pass a runtime
  value like `len(list)` as a parameter. If a size is only known at
  runtime, it is an argument, and the code cannot unroll on it.
- **Struct parameters are accessed through `Self`**: `Self.dtype`,
  `Self.size`, even in field declarations. Real error without it:
  `unqualified access to struct parameter 'dtype'; use 'Self.dtype' instead`.
- **Specialization is the performance feature and the cost.** Every
  parameter combination is compiled separately: fast code, bigger binary.

## 🔗 Related

- [comptime](comptime.md)
- [SIMD and DType](simd-and-dtype.md)
- [Attributes and properties (MLIR)](../02-ir-design/attributes-and-properties.md)
- [Autotuning](../05-ml-compilers/autotuning.md): sweeping parameters

---

✅ Verified against: Mojo 1.1.0 (run locally)
