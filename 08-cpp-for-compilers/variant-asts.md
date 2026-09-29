# Variant ASTs 🧾

> **One line:** Instead of a class hierarchy, an AST node can be a
> `std::variant` over a **closed** set of alternatives. `std::visit` then
> forces every visitor to handle every alternative at compile time. The cost:
> nodes are as big as the largest alternative, and nobody else can add new
> kinds.

## 🌉 From frontend

This is exactly TypeScript's discriminated union with an exhaustive
`switch`: add a new member to `type Expr = Num | Var | BinOp | Let` and
every `switch` without a case for it stops compiling (with the `never`
trick). `std::variant` + `std::visit` give C++ the same guarantee.

## 🖼️ Picture

```
 INHERITANCE + KIND TAG (LLVM IR, Clang)    CLOSED VARIANT (many frontends)
 ───────────────────────────────────────    ───────────────────────────────
 class Expr { Kind k; };                    struct Expr {
 class NumExpr : Expr {...};                  std::variant<NumLit, VarRef,
 class BinExpr : Expr {...};                               BinOp, LetExpr> node;
                                            };
 + OPEN: a new dialect can add kinds        + EXHAUSTIVE: std::visit fails to compile
 + stable heap addresses, dyn_cast            if a handler is missing
 - forgetting a case = silent bug           - CLOSED: the set is fixed in one place
                                            - every node is as large as the biggest one

 MLIR chose OPEN registration (dialects add ops at runtime), so it cannot use variant
```

## 🔧 In each tool

From [codebases/compiler-mechanics-cpp/04_ir_data_structures.cpp](../codebases/compiler-mechanics-cpp/04_ir_data_structures.cpp):

```cpp
struct Expr;
using ExprPtr = std::unique_ptr<Expr>;   // indirection: a variant can't contain itself

struct NumLit  { double value; };
struct VarRef  { std::string name; };
struct BinOp   { char op; ExprPtr lhs, rhs; };
struct LetExpr { std::string name; ExprPtr value, body; };

struct Expr { std::variant<NumLit, VarRef, BinOp, LetExpr> node; };

// C++17 "overloaded" trick: one struct inheriting operator() from several lambdas
template <class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template <class... Ts> overloaded(Ts...) -> overloaded<Ts...>;   // needed in C++17
```

Constant folding as a pure tree rewrite. `holds_alternative` is the variant
equivalent of `isa<>`:

```cpp
[](const BinOp &b) {
  ExprPtr l = constantFold(*b.lhs);
  ExprPtr r = constantFold(*b.rhs);
  if (std::holds_alternative<NumLit>(l->node) &&
      std::holds_alternative<NumLit>(r->node))
    return num(applyOp(b.op, std::get<NumLit>(l->node).value,
                             std::get<NumLit>(r->node).value));
  return bin(b.op, std::move(l), std::move(r));
},
```

The test builds `let x = (2 * 3) + 4 in (x * y)`, checks it evaluates to 50
with `y = 5`, folds it and checks the result still evaluates to 50. Real
output:

```
       folded AST: let x = 10 in (x*y)
```

| Real codebase                     | Node representation                                                  |
| --------------------------------- | -------------------------------------------------------------------- |
| LLVM IR, Clang AST, MLIR          | Inheritance + kind tag, open                                         |
| Rust compiler, OCaml/ML compilers | Enums / algebraic data types (closed, exhaustive match)              |
| Mojo                              | `Variant[...]` in the stdlib for closed unions; traits for open sets |

## 🎤 Interview angle

- "Variant or inheritance for my AST?" → a variant when the node set is
  closed and you want exhaustiveness checking (a frontend AST). Inheritance
  when others must extend it (IR with dialects), or when nodes vary a lot in size.
- "Why the `overloaded` deduction guide?" → C++17 needs it to deduce the
  lambda types. C++20 deduces them without it. LLVM targets C++17.

## ⚠️ Common confusion

- **Recursive variants need indirection.** `BinOp` holds
  `std::unique_ptr<Expr>`, not `Expr`, because a type cannot contain itself.
- **Pure vs in-place rewrites.** This folder returns a fresh tree, which is
  easy to test. Real compilers usually rewrite in place, which needs the
  ownership care shown in
  [Owning slots and safe rewrites](owning-slots-and-safe-rewrites.md).

## 🔗 Related

- [LLVM-style RTTI](llvm-style-rtti.md)
- [AST vs IR](../00-bridge/ast-vs-ir.md)
- [Canonicalization and folding](../03-transformations/canonicalization-and-folding.md)

---

✅ Verified against: compiler-mechanics-cpp `14818a3` (built and tested locally)
