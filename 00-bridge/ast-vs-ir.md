# AST vs IR 🌳

> **One line:** An AST mirrors how the code was _written_. An IR (intermediate
> representation) describes what the code _does_, in a form built to be
> analyzed and transformed.

## 🌉 From frontend

You know ASTs from ESLint, Prettier and Babel: `IfStatement`,
`BinaryExpression` and so on. An AST keeps the programmer's structure, so
`if` / `else`, `for` and `x += 1` all stay as written.

An IR drops that structure. Loops, `if`s and `?:` all become the same few
things: **blocks of straight-line instructions, connected by jumps**. That
sounds like a step backwards, but it means one optimization can handle every
kind of control flow, instead of one copy per syntax form.

## 🖼️ Picture

Source ([samples/max_or_zero.c](../samples/max_or_zero.c)):

```c
int max_or_zero(int x) { int r; if (x > 0) r = x; else r = 0; return r; }
```

```
 AST: shaped like the source            IR: shaped like the execution
 ───────────────────────────            ─────────────────────────────
 FunctionDecl max_or_zero               ┌───────────────────────────┐
 ├── ParmVar x                          │ entry:                    │
 └── Compound                           │   %2 = icmp sgt %0, 0     │
     ├── VarDecl r                      │   br %2, label %3, %4     │
     ├── IfStmt                         └─────┬──────────────┬──────┘
     │   ├── cond: x > 0                      ▼              ▼
     │   ├── then: r = x              ┌────────────┐  ┌────────────┐
     │   └── else: r = 0              │ 3: br %5   │  │ 4: br %5   │
     └── Return r                     └─────┬──────┘  └─────┬──────┘
                                            └──────┬────────┘
   "r" is a variable that is                       ▼
   assigned twice                     ┌─────────────────────────────┐
                                      │ 5: %.0 = phi [%0,%3],[0,%4] │
                                      │    ret %.0                  │
                                      └─────────────────────────────┘
                                        no "r": each value has exactly
                                        one definition (SSA)
```

## 🔧 In each tool

| Tool   | AST                                   | First IR                                        |
| ------ | ------------------------------------- | ----------------------------------------------- |
| Clang  | Clang AST (`clang -Xclang -ast-dump`) | LLVM IR                                         |
| MLIR   | Each front end has its own AST        | The front end emits ops in a high-level dialect |
| Triton | Python `ast` module of your `@jit` fn | `tt` dialect (Triton IR)                        |
| Mojo   | Mojo's parser AST (not exposed)       | Mojo's internal MLIR dialects                   |

Real LLVM IR for the C above (`clang -O0` then `opt -passes=mem2reg`, from
`scripts/regen.sh`):

```llvm
define i32 @max_or_zero(i32 noundef %0) #0 {
  %2 = icmp sgt i32 %0, 0
  br i1 %2, label %3, label %4

3:                                                ; preds = %1
  br label %5

4:                                                ; preds = %1
  br label %5

5:                                                ; preds = %4, %3
  %.0 = phi i32 [ %0, %3 ], [ 0, %4 ]
  ret i32 %.0
}
```

## ⚠️ Common confusion

- **"MLIR is an AST."** It is not. MLIR ops _can_ be nested (regions), so
  high-level MLIR can look tree-like. It is still SSA, and values are passed
  by reference to their single definition, not by name.
- **"There is one IR."** Real compilers have several IRs at different levels.
  The whole point of MLIR is to make adding another level cheap.

## 🔗 Related

- [Basic block](../01-foundations/basic-block.md)
- [SSA](../01-foundations/ssa.md): where the `phi` comes from
- [Babel is a compiler](babel-is-a-compiler.md)

---

✅ Verified against: LLVM 23.1.1
