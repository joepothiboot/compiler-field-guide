# Vocab 🔤

The same few hundred names show up in every compiler codebase. This folder is
the lookup table.

Strip away the business logic and a compiler sees no users, carts or
payments. It sees five questions, over and over:

| #   | Question                                   | Where the answer lives                                  |
| --- | ------------------------------------------ | ------------------------------------------------------- |
| 1   | **Where is the data?** (memory)            | `load`, `store`, `alloc`, `ptr`, `memref`, `shared`     |
| 2   | **What is computed?** (arithmetic)         | `add`, `mul`, `fma`, `cmp`, `select`, `dot`             |
| 3   | **In what order?** (control flow)          | `br`, `phi`, `for`, `if`, `yield`, `return`             |
| 4   | **What shape?** (iteration space, layout)  | `M N K`, `stride`, `offset`, `dim`, `tile`, `block`     |
| 5   | **Who does it in parallel?** (parallelism) | `tid`, `ctaid`, `pid`, `warp`, `lane`, `vector`, `mask` |

Every name in the tables below answers one of these. That is why `%arg0` or
`vector.transfer_read` looks the same at Google, Meta, NVIDIA, OpenAI and
Apple: the hardware has the same five problems everywhere.

## 📑 Pages

| Page                                                   | Answers                                                                      |
| ------------------------------------------------------ | ---------------------------------------------------------------------------- |
| [value-names.md](value-names.md)                       | What do `%arg0`, `%c0`, `%0`, `%rd7`, `%arrayidx` mean, and who prints them? |
| [opcodes.md](opcodes.md)                               | The op vocabulary by category, with the spelling in LLVM, MLIR, PTX, Triton  |
| [kernel-parameter-names.md](kernel-parameter-names.md) | `pid`, `offs`, `mask`, `BLOCK_SIZE`, `M N K`, `tid`: names humans choose     |
| [who-uses-what.md](who-uses-what.md)                   | A matrix: which tool or language uses which family of names                  |

## 🏷️ How to read the "Seen here" column

- A number (for example `65`) is how many times that spelling appears in this
  repo's [samples/](../samples/) (counted with `grep` on 2026-10-04). It is
  real output from this machine.
- `—` means it is standard vocabulary but it does not appear in the samples.
  Those entries come from the tools' documented conventions, not from output
  in this repo. Verify with the tool before quoting one in an interview.

## 🧭 Two kinds of names

1. **Printer names**: chosen by the tool (`%arg0`, `%0`, `%c0`, `%rd7`). They
   tell you what produced the IR.
2. **Human names**: chosen by the author (`pid`, `offs`, `BLOCK_SIZE`, `acc`).
   They are conventions, so they are consistent only because people copy
   each other (Triton tutorials, CUDA samples, the BLAS papers).

Knowing which kind a name is tells you whether you can trust it. A printer
name is a fact about the IR. A human name is a hint.
