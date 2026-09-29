# SSA (Static Single Assignment) 🏷️

> **One line:** Every value is assigned **exactly once**. If a variable
> changes, the compiler makes a new, differently named value instead of
> overwriting the old one.

## 🌉 From frontend

It is like writing everything with `const`, the way immutable updates work
in Redux:

```js
// mutable (source code)       // SSA style
let x = 1;
const x1 = 1;
x = x + 2;
const x2 = x1 + 2;
x = x * 3;
const x3 = x2 * 3;
```

Because nothing is reassigned, "where does this value come from?" always has
one answer. That makes most optimizations much simpler. For example, it is
easy to prove that `x1` is still 1 on line 3.

The analogy stops working at **branches**. After an `if` / `else`, which
`const` holds the answer? SSA needs a special way to say "this value is
whichever one we arrived with". That is φ (phi), or block arguments in MLIR.

## 🖼️ Picture

```
         x > 0 ?
        ┌───┴───┐
        ▼       ▼
     r1 = x   r2 = 0          two separate definitions,
        │       │             no reassignment
        └───┬───┘
            ▼
   r3 = φ(r1 from left, r2 from right)     ← "pick based on which way we came"
   return r3


 LLVM style: φ at top of block           MLIR style: block takes arguments
 ─────────────────────────────           ─────────────────────────────────
 merge:                                  cf.cond_br %pos, ^merge(%x : i32),
   %r = phi [%x, %then], [0, %else]                       ^merge(%zero : i32)
   ret %r                                ^merge(%r: i32):
                                           return %r : i32

 the φ lists incoming edges              each jump passes the value, like a
                                         function call passing an argument
```

The MLIR version is easier to read if you think of each block as a small
function: jumping to it is like **calling it with arguments**.

## 🔧 In each tool

| Tool    | SSA?                                                                                                                                     | How the join is written                         |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| LLVM IR | Yes, for registers (`%x`). Memory (`load`/`store`) is not SSA.                                                                           | `phi`                                           |
| MLIR    | Yes, everywhere                                                                                                                          | Block arguments; structured ops use `scf.yield` |
| Triton  | Yes, because it lowers to MLIR. Your Python variables become SSA values.                                                                 | Handled for you                                 |
| Mojo    | Yes, because it lowers to MLIR. You can reassign a `var`. After optimization, locals end up as SSA values, like Clang's `mem2reg` below. | Handled for you                                 |

Real outputs for [samples/max_or_zero.c](../samples/max_or_zero.c):

```llvm
; LLVM IR (clang -O0 + opt -passes=mem2reg)
5:                                                ; preds = %4, %3
  %.0 = phi i32 [ %0, %3 ], [ 0, %4 ]
  ret i32 %.0
```

```mlir
// MLIR (samples/max_or_zero.blockargs.mlir, after mlir-opt)
    cf.cond_br %0, ^bb1(%arg0 : i32), ^bb1(%c0_i32 : i32)
  ^bb1(%1: i32):  // 2 preds: ^bb0, ^bb0
    return %1 : i32
```

When MLIR is translated to LLVM IR (`mlir-translate --mlir-to-llvmir`), the
block argument **becomes a `phi`**. This is real output:

```llvm
5:                                                ; preds = %3, %4
  %6 = phi i32 [ 0, %4 ], [ %0, %3 ]
```

### 🔍 Where the φ comes from: `mem2reg`

Clang does not produce SSA directly. At `-O0` it stores every local variable
in memory (`alloca` + `store`/`load`). The `mem2reg` pass then promotes those
to SSA registers and inserts φs where needed. That is why the samples run
`opt -passes=mem2reg`: it is the smallest step that turns memory variables
into SSA values.

```
 clang -O0           ──mem2reg──►      SSA
 %r = alloca i32                       (no alloca)
 store %x, ptr %r                      %.0 = phi i32 [%0,...],[0,...]
 store 0,  ptr %r
 %v = load ptr %r
```

## ⚠️ Common confusion

- **"SSA means the program can't mutate anything."** No. Memory can still be
  written (`store`, `memref.store`). SSA only applies to _values/registers_.
  This is why MLIR has both `tensor` (a value, SSA-friendly) and `memref`
  (memory you can write to). See bufferization in chapter 03.
- **"Static" means the text, not runtime.** A value is _written_ once in the
  code, but inside a loop it is computed again on every iteration. The loop
  header's φ gets a new incoming value on each pass.

## 🔗 Related

- [Basic block and CFG](basic-block.md)
- [AST vs IR](../00-bridge/ast-vs-ir.md)
- [Dialect](../02-ir-design/dialect.md)

---

✅ Verified against: LLVM/MLIR 23.1.1
