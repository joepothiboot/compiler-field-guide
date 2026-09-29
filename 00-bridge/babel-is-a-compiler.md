# Babel Is a Compiler 🌉

> **One line:** If you have written a Babel plugin or configured a bundler,
> you have already used a compiler: parse, transform, generate.

## 🌉 From frontend

Babel takes modern JS, turns it into a tree, runs plugins over the tree, and
prints older JS. An ML compiler does the same three steps. It has more
intermediate forms, and its output is machine code instead of JS.

## 🖼️ Picture

```
 BABEL                                  AN ML COMPILER
 ─────                                  ──────────────
 source.js                              model.py / kernel.mojo
    │ @babel/parser                        │ front end (parse, type-check)
    ▼                                      ▼
 AST (ESTree)                           AST
    │ plugins visit nodes                  │ build IR
    ▼                                      ▼
 transformed AST                        high-level IR  (tensor ops)
    │                                      │ lower
    │                                      ▼
    │                                   mid-level IR   (loops, buffers)
    │                                      │ lower
    │                                      ▼
    │                                   LLVM IR        (SSA, registers)
    │ @babel/generator                     │ backend
    ▼                                      ▼
 output.js                              machine code (x86 / ARM / PTX)
```

## 🔧 Term by term

| Babel / FE term                  | Compiler term                            | Notes                                                              |
| -------------------------------- | ---------------------------------------- | ------------------------------------------------------------------ |
| `@babel/parser`                  | Front end (lexer + parser)               | Same job: text → tree                                              |
| AST / ESTree node                | AST node                                 | Same idea                                                          |
| Plugin with a `visitor`          | Pass / rewrite pattern                   | MLIR patterns match an op, much like a visitor matches a node type |
| Preset (`preset-env`)            | Pass pipeline (`-O2`, a pipeline string) | An ordered list of passes                                          |
| `@babel/generator`               | Code generation (codegen)                | Tree/IR → output text or bytes                                     |
| Source maps                      | Debug info / locations (`loc(...)`)      | Tracks which output came from which source line                    |
| Target browsers (`browserslist`) | Target triple (`nvptx64-nvidia-cuda`)    | "What machine am I generating code for?"                           |
| Tree-shaking                     | Dead code elimination (DCE)              | Remove what nothing uses                                           |
| Minifier constant folding        | Constant folding / canonicalization      | `2 * 3` → `6`                                                      |

## ⚠️ Where the analogy stops working

1. **Babel has one tree. A compiler has several IRs.** Each IR is designed so
   that certain optimizations are easy at that level. See
   [AST vs IR](ast-vs-ir.md).
2. **Babel's output is still high-level code.** A compiler's output is
   concrete: registers, memory addresses, vector instructions.
3. **Performance is the main goal.** Babel mostly cares about producing
   _correct_ output. An ML compiler cares just as much about _fast_ output,
   which depends on the hardware (see chapter 04).

## 🔗 Related

- [AST vs IR](ast-vs-ir.md)
- [Bundler plugins vs passes](bundler-plugins-vs-passes.md)
- [The whole stack](../maps/the-whole-stack.md)

---

✅ Verified against: concept page, no code
