# Lexer and Parser 🔤

> **One line:** The _lexer_ cuts source text into tokens (words). The
> _parser_ arranges those tokens into a tree (AST) using the language's
> grammar. Together they make up the **front end**.

## 🌉 From frontend

You have seen both halves: a syntax highlighter is basically a lexer, and
[astexplorer.net](https://astexplorer.net) shows you a parser's output. When
Prettier or ESLint says "Unexpected token", that is the parser rejecting a
token that the grammar does not allow in that position.

## 🖼️ Picture

```
 source text      int max_or_zero(int x) { ... }
      │
      │ LEXER: characters → tokens (no structure yet)
      ▼
 [int] [identifier max_or_zero] [(] [int] [identifier x] [)] [{] ...
      │
      │ PARSER: tokens → tree (applies the grammar)
      ▼
 FunctionDecl max_or_zero 'int (int)'
 ├── ParmVarDecl x 'int'
 └── CompoundStmt
     ├── DeclStmt  (int r)
     ├── IfStmt  has_else
     └── ReturnStmt
      │
      │ SEMANTIC ANALYSIS: names resolved, types checked,
      │                    implicit conversions made explicit
      ▼
 typed AST  ──► first IR (see ast-vs-ir)
```

## 🔧 In each tool

Real Clang output for [samples/max_or_zero.c](../samples/max_or_zero.c).

Tokens (`clang -fsyntax-only -Xclang -dump-tokens`):

```
int              'int'                    Loc=<max_or_zero.c:1:1>   [StartOfLine]
identifier       'max_or_zero'            Loc=<max_or_zero.c:1:5>   [LeadingSpace]
l_paren          '('                      Loc=<max_or_zero.c:1:16>
int              'int'                    Loc=<max_or_zero.c:1:17>
identifier       'x'                      Loc=<max_or_zero.c:1:21>  [LeadingSpace]
r_paren          ')'                      Loc=<max_or_zero.c:1:22>
l_brace          '{'                      Loc=<max_or_zero.c:1:24>  [LeadingSpace]
```

AST (`clang -fsyntax-only -Xclang -ast-dump`, addresses removed):

```
`-FunctionDecl <max_or_zero.c:1:1, line:6:1> line:1:5 max_or_zero 'int (int)'
  |-ParmVarDecl <col:17, col:21> col:21 used x 'int'
  `-CompoundStmt
    |-DeclStmt
    | `-VarDecl col:7 used r 'int'
    |-IfStmt has_else
    | |-BinaryOperator 'int' '>'
    | | |-ImplicitCastExpr 'int' <LValueToRValue>      ← added by semantic analysis
    | | | `-DeclRefExpr 'int' lvalue ParmVar 'x' 'int'
    | | `-IntegerLiteral 'int' 0
    | |-BinaryOperator 'int' '='
    | `-BinaryOperator 'int' '='
    `-ReturnStmt
```

`ImplicitCastExpr <LValueToRValue>` is the compiler writing down "read the
value stored in `x` here". You did not write it, but semantic analysis adds
it. Later it becomes a `load`.

| Tool   | Front end                                                                                               | Can you see it?                |
| ------ | ------------------------------------------------------------------------------------------------------- | ------------------------------ |
| Clang  | Hand-written lexer and recursive-descent parser                                                         | `-dump-tokens`, `-ast-dump`    |
| MLIR   | `.mlir` files have their own generic parser; your _language_ needs its own front end that emits ops     | `mlir-opt` parses `.mlir` text |
| Triton | Uses Python's own parser (`ast` module) on the decorated function, then walks that AST to emit `tt` ops | Only through Triton internals  |
| Mojo   | Mojo's own lexer and parser (not exposed)                                                               | Parse errors from `mojo run`   |

## ⚠️ Common confusion

- **Parse errors vs type errors.** "Expected `;`" comes from the parser.
  "Cannot convert `String` to `Int`" comes from semantic analysis, which
  runs after parsing on a valid tree.
- **Triton kernels must be valid Python _and_ valid Triton.** Python parses
  them first. Triton then rejects constructs it cannot compile (for example
  most Python objects inside the kernel).
- **The front end is the smallest part of an ML compiler.** Most of the
  work in this guide happens after the first IR is built.

## 🔗 Related

- [AST vs IR](../00-bridge/ast-vs-ir.md)
- [Babel is a compiler](../00-bridge/babel-is-a-compiler.md)

---

✅ Verified against: Clang 23.1.1
