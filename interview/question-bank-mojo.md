# Question Bank: Mojo (Libraries Engineer) 🔥

Role-focused questions: language semantics, generic library design,
performance and testing. Everything below compiled or ran with Mojo 1.1.0.
Old syntax is noted where it changed.

---

### 1. What are Mojo's argument conventions?

<details><summary>Answer</summary>

`read` (default): borrowed, immutable. `mut`: borrowed, mutable, and the
caller sees the changes. `var`: the function owns its value (the caller
passes a copy with `.copy()` or transfers with `^`). `out`: the function
initializes the caller's uninitialized result slot (used by `__init__`).

→ [def, struct and argument conventions](../06-mojo/def-struct-and-argument-conventions.md)
</details>

### 2. What happens to `xs` after `consume(xs^)`?

<details><summary>Answer</summary>

Ownership is transferred. `xs` is uninitialized, and using it is a
**compile-time** error: `error: use of uninitialized value 'xs'`. Contrast
C++, where a moved-from object still exists and is usable.
</details>

### 3. When is a Mojo value destroyed?

<details><summary>Answer</summary>

Right after its last use ("as soon as possible"), not at the end of scope.
My lifecycle sample shows `a` destroyed inside `keep()`, and the last values
destroyed immediately after the `print` that used them.

→ [Ownership and transfer](../06-mojo/ownership-and-transfer.md)
</details>

### 4. Does `^` always call the move constructor?

<details><summary>Answer</summary>

No. Transferring into a `var` argument handed over the same storage, and no
move constructor ran. The move constructor ran only when the value had to
relocate, e.g. into a `List`'s buffer (`move c` in the sample output).
</details>

### 5. Name the lifecycle methods in Mojo 1.1.

<details><summary>Answer</summary>

`__init__(out self, ...)`, copy: `__init__(out self, *, copy: Self)`, move:
`__init__(out self, *, deinit move: Self)`, destructor:
`__deinit__(deinit self)`. The old `__copyinit__` / `__moveinit__` / `__del__`
names appear in older code. 1.1 warns: `'__del__' is deprecated; use '__deinit__'`.
</details>

### 6. Parameters vs arguments?

<details><summary>Answer</summary>

Parameters (`[...]`) are compile-time values: types, sizes, flags. Every
distinct set produces a specialized function. Arguments (`(...)`) are runtime
values. `SIMD[DType.float32, 4](1, 2, 3, 4)`: the dtype and width are
parameters, the lane values are arguments.

→ [Parameters vs arguments](../06-mojo/parameters-vs-arguments.md)
</details>

### 7. What does `comptime` do? What replaced `alias` and `@parameter`?

<details><summary>Answer</summary>

`comptime X = expr` evaluates at compile time and can run ordinary functions
(`comptime FIB_20 = fib(20)` → 6765). `comptime if` compiles only one branch,
and `comptime for` unrolls. In Mojo 1.1, `alias`, `@parameter if` and
`@parameter for` are **errors**, not just deprecated.

→ [comptime](../06-mojo/comptime.md)
</details>

### 8. How are traits different from TypeScript interfaces or C++ virtual bases?

<details><summary>Answer</summary>

A trait constrains a parameter (`[T: Shape]`), and the function is compiled
separately per concrete type. That is static dispatch with no vtable (like
C++ templates or concepts, and Rust generics). TypeScript erases generics and
dispatches at runtime. Traits compose: `T: Shape & Copyable`.

→ [Traits](../06-mojo/traits.md)
</details>

### 9. What is `SIMD[dtype, width]` and why is `Float32` a SIMD type?

<details><summary>Answer</summary>

A fixed-width vector mapped to hardware registers. `Float32` is
`SIMD[DType.float32, 1]`, so the same generic code works for scalars and
vectors. That uniformity is a core stdlib design choice. Widths above the
hardware width are split across registers (the 16-wide accumulators in my
matmul were 4 NEON registers each).

→ [SIMD and DType](../06-mojo/simd-and-dtype.md)
</details>

### 10. How do you write a SIMD kernel that works on any machine?

<details><summary>Answer</summary>

Use `comptime width = simd_width_of[dtype]()` (4 for f32 and 16 for i8 on
the M2), a SIMD body with `unsafe_load[width=width]` / `unsafe_store`, and a
scalar tail for the remainder, as in nano-dsp's `kernels.mojo`. Or use
`vectorize` from `std.algorithm`, which packages the same pattern.
</details>

### 11. Write branch-free relu on SIMD.

<details><summary>Answer</summary>

`x.lt(zeros).select(zeros, x)`. Comparisons return a per-lane bool mask, and
`select` picks per lane. For NaN: `x < 0` is false for NaN, so NaN passes
through (NumPy semantics). That is why nano-dsp writes it this way and lowers
`dsp.relu` to `arith.maximumf`, not `maxnumf`.
</details>

### 12. Why was your 16-lane SIMD sum more accurate than the scalar loop?

<details><summary>Answer</summary>

Each lane accumulates about 1/16 of the values, so partial sums stay smaller,
and adding `0.1` to a smaller number loses less precision. Scalar: 1,935,089.
SIMD: 1,694,270. Reference: 1,677,722. It's still a different result from the
in-order sum, so a library must document its reduction order.

→ [Reduction in 5 IRs](../rosetta/reduction-in-5-irs.md)
</details>

### 13. How would you make a matmul fast on CPU in Mojo?

<details><summary>Answer</summary>

In the order my measurements support: fix the loop order (3.3×), then
register-block a tile of C in SIMD accumulators across the whole k loop
(13×), then k-block so the reused B panel stays in cache (2.3× more at
N=2048). Sweep sizes with `comptime for`, and check bit-exactness against a
reference. Next steps would be packing B into a contiguous panel,
parallelizing over cores, and using FMA.

→ [Matmul: naive, tiled, fused](../rosetta/matmul-naive-tiled-fused.md)
</details>

### 14. How do you launch a GPU kernel in Mojo 1.1 + MAX?

<details><summary>Answer</summary>

`var ctx = DeviceContext()`, buffers from `ctx.enqueue_create_buffer[dtype](n)`,
fill them via `map_to_host()`, then
`ctx.enqueue_function[kernel](args..., grid_dim=..., block_dim=...)`. Import
from `max.gpu` / `max.gpu.host`. Arguments must be device-passable: `Int` is
rejected with a message to use `Int32`/`Int64`.

→ [MAX and Mojo kernels](../06-mojo/max-and-mojo-kernels.md)
</details>

### 15. How do you inspect what your Mojo GPU code compiles to without that GPU?

<details><summary>Answer</summary>

`mojo build --emit asm --target-accelerator=sm_80 file.mojo` writes a `.ptx`
per kernel next to the host assembly. The guide's `scripts/mojo-ptx.sh`
wraps it. `--emit llvm` gives LLVM IR.
</details>

### 16. What is `LayoutTensor`?

<details><summary>Answer</summary>

A view (pointer + compile-time `Layout` of shape and strides) from MAX's
`layout` package. It supports indexing and tiling without copying:
`t.tile[2, 4](1, 1)` returned the 2×4 block `24..27 / 34..37` in my sample.
It is the building block for tiled kernels.
</details>

### 17. How would you design a new stdlib function, e.g. `argmax` over SIMD data?

<details><summary>Answer</summary>

Make it generic over `dtype` (and `width` with a native-width default).
Take inputs as `read` borrows or a `Span`, not owned copies. Define edge
cases explicitly: empty input, NaN (does NaN win or lose?), ties (first
index?). Implement a SIMD body with a scalar tail. Test against a naive
reference, including NaN, ±0.0 and non-multiple-of-width lengths. Benchmark
against the naive version at several sizes. Document the complexity and
semantics.
</details>

### 18. What testing and benchmarking habits matter for library code?

<details><summary>Answer</summary>

Differential tests against a simple reference (bit-exact where the order is
preserved, an explicit tolerance otherwise). Edge cases: NaN, infinities,
denormals, empty, tails. Warm-up runs and repeated timing. Test across
dtypes and widths via parameters. nano-dsp tests the Mojo kernels and the
MLIR pipeline against the same golden values, so each checks the other.
</details>

### 19. Why is `out` a problem as a parameter name?

<details><summary>Answer</summary>

It is a keyword (the `out` argument convention), so `out: Pointer[...]` fails
with `expected argument name`. A small thing, but it is the kind of
detail you only know from compiling real code.
</details>

### 20. What changed from the Mojo you'd see in older tutorials?

<details><summary>Answer</summary>

`fn` removed (use `def`, with explicit `raises`). `alias` → `comptime`.
`@parameter if/for` → `comptime if/for`. `__del__` → `__deinit__`. The move
constructor spelled `__init__(out self, *, deinit move: Self)`. `InlineArray`
→ `Array`. GPU imports under `max.gpu.*`, with warp helpers in
`max.gpu.primitives.warp`. Struct parameters accessed as `Self.dtype`. All
confirmed by compiler errors or warnings in this guide.
</details>
