# Basic Block and CFG 🧱

> **One line:** A _basic block_ is a run of instructions with one way in (the
> top) and one way out (a jump at the bottom). The _control-flow graph_ (CFG)
> is the graph of blocks connected by those jumps.

## 🌉 From frontend

Think of a synchronous function body with no `if`, no loop, no `return` in
the middle and no `await`. Once it starts, every line runs, in order. Each
`if` and loop in real code breaks the function into several of these pieces,
joined by arrows.

The analogy stops working at _jumps_. JS has no `goto`, but at the IR level
every `if`, loop, `break` and `continue` becomes a jump between blocks.

## 🖼️ Picture

A `for` loop ([samples/vadd.c](../samples/vadd.c)) as a CFG:

```
 for (int i = 0; i < n; i++)
   c[i] = a[i] + b[i];

            ┌─────────────────┐
            │ entry           │
            │  br header      │
            └────────┬────────┘
                     ▼
            ┌─────────────────┐ ◄──────────────┐
            │ header          │                │
            │  i = φ(0, i+1)  │                │  back edge
            │  i < n ?        │                │  (this is what
            └───┬─────────┬───┘                │   makes it a loop)
          true  │         │ false              │
                ▼         ▼                    │
   ┌─────────────────┐  ┌──────────┐           │
   │ body            │  │ exit     │           │
   │  load a[i],b[i] │  │  ret     │           │
   │  fadd, store    │  └──────────┘           │
   │  i+1, br header │─────────────────────────┘
   └─────────────────┘
```

Rules of a basic block:

```
  ┌────────────────────────┐
  │ label:                 │ ← jumps can only land here
  │   instr                │
  │   instr                │ ← no jumps in or out of the middle
  │   terminator           │ ← exactly one, always last: br / cond_br / ret
  └────────────────────────┘
```

## 🔧 In each tool

| Tool    | Block syntax                                                                                               | Terminators                          | How values flow in  |
| ------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------ | ------------------- |
| LLVM IR | `5:` or `loop.header:`                                                                                     | `br`, `br i1`, `switch`, `ret`       | `phi` instructions  |
| MLIR    | `^bb1(%i: index):`                                                                                         | `cf.br`, `cf.cond_br`, `func.return` | **Block arguments** |
| Triton  | You do not write blocks. The kernel is straight-line code over tiles, and the compiler creates the blocks. | —                                    | —                   |
| Mojo    | You do not write blocks. `if` and `for` become blocks during lowering.                                     | —                                    | —                   |

The same loop in MLIR after `--convert-scf-to-cf`
([samples/vadd.mlir](../samples/vadd.mlir)). This is real output:

```mlir
    cf.br ^bb1(%c0 : index)
  ^bb1(%0: index):  // 2 preds: ^bb0, ^bb2        ← header, i arrives as a block argument
    %1 = arith.cmpi slt, %0, %dim : index
    cf.cond_br %1, ^bb2, ^bb3
  ^bb2:  // pred: ^bb1                            ← body
    %2 = memref.load %arg0[%0] : memref<?xf32>
    %3 = memref.load %arg1[%0] : memref<?xf32>
    %4 = arith.addf %2, %3 : f32
    memref.store %4, %arg2[%0] : memref<?xf32>
    %5 = arith.addi %0, %c1 : index
    cf.br ^bb1(%5 : index)                        ← back edge, passes i+1
  ^bb3:  // pred: ^bb1                            ← exit
    return
```

And in LLVM IR (from `clang` + `mem2reg`):

```llvm
5:                                                ; preds = %17, %4
  %.0 = phi i32 [ 0, %4 ], [ %18, %17 ]
  %6 = icmp slt i32 %.0, %3
  br i1 %6, label %7, label %19
```

## ⚠️ Common confusion

- **A _basic block_ is not a GPU _thread block_.** They share a name and
  nothing else. A basic block is a piece of code. A GPU block (CUDA
  "thread block", Triton "program") is a group of threads. See chapter 04.
- **An MLIR "block" can also be a region's body.** In `scf.for { ... }` the
  braces hold a region with one block inside. It is the same concept, just
  nested.
- **`preds` comments** like `; preds = %17, %4` are printed by the tool for
  you. They are not part of the program.

## 🔗 Related

- [SSA](ssa.md): φ and block arguments in detail
- [AST vs IR](../00-bridge/ast-vs-ir.md)

---

✅ Verified against: LLVM/MLIR 23.1.1
