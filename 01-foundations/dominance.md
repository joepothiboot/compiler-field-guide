# Dominance 👑

> **One line:** Block A _dominates_ block B if **every** path from the
> function entry to B goes through A. In SSA, a value can only be used where
> its definition dominates the use.

## 🌉 From frontend

Think of a variable declared with `const` inside an `if`: you cannot use it
after the `if`, because on the `else` path it was never created. JS enforces
this with block scope. SSA enforces the same thing with dominance, except
that SSA has no scopes, only blocks and paths.

## 🖼️ Picture

```
 CFG of a loop (vadd)                 Dominator tree of the same CFG
 ────────────────────                 ──────────────────────────────
     ┌───────┐                              entry
     │ entry │                                │
     └───┬───┘                              header
         ▼                                  ┌─┴──┐
     ┌────────┐◄──────┐                   body   exit
     │ header │       │                    │
     └─┬────┬─┘       │                  latch
       ▼    ▼         │
   ┌──────┐ ┌──────┐  │     read: "X is a parent of Y" = "X dominates Y"
   │ body │ │ exit │  │
   └──┬───┘ └──────┘  │     - entry dominates everything
      ▼               │     - header dominates body, latch and exit
   ┌───────┐          │     - body does NOT dominate exit
   │ latch │──────────┘       (you can reach exit without going through body)
   └───────┘
```

Real dominator tree from LLVM for [samples/vadd.c](../samples/vadd.c)
(`opt -passes='mem2reg,loop-simplify,print<domtree>'`). Blocks are named
by number: `%4` is entry, `%5` header, `%7` body, `%17` latch, `%19` exit.

```
Inorder Dominator Tree:
  [1] %4 {0,5} [0]
    [2] %5 {1,5} [1]
      [3] %7 {2,4} [2]
        [4] %17 {3,4} [3]
      [3] %19 {4,5} [2]
Roots: %4
```

## 🔧 In each tool

When the rule is broken, MLIR's verifier stops you. Real output for
[samples/bad_dominance.mlir](../samples/bad_dominance.mlir), where `%y` is
only defined on one path:

```
bad_dominance.mlir:9:3: error: operand #0 does not dominate this use
  return %y : i32
  ^
bad_dominance.mlir:6:8: note: operand defined here (op in the same region)
  %y = arith.addi %x, %x : i32
       ^
```

The fix is to pass the value in as a block argument (φ), with a value for
each incoming path. See [SSA](ssa.md).

| Tool    | Where dominance shows up                                                                                                          |
| ------- | --------------------------------------------------------------------------------------------------------------------------------- |
| LLVM IR | Verifier: "Instruction does not dominate all uses!"; `DominatorTree` analysis used by most passes                                 |
| MLIR    | Verifier error above; `DominanceInfo` analysis. Inside nested regions, values from outside are visible if the parent op dominates |
| Triton  | Handled for you. Python variables become SSA values automatically                                                                 |
| Mojo    | Handled for you. The compiler reports "use of uninitialized value" at the source level instead                                    |

## ⚠️ Common confusion

- **Dominance is about all paths, not "comes earlier in the file".** A
  block printed earlier can still fail to dominate a later one.
- **Post-dominance** is the mirror: B post-dominates A if every path from
  A to the _exit_ goes through B. Used for things like "is this code always
  reached after that?".
- **Why optimizations care:** a pass can only move an instruction to a
  place its operands still dominate. Hoisting code out of a loop is legal
  only if its inputs are defined above the loop.

## 🔗 Related

- [SSA](ssa.md)
- [Loops in IR](loops-in-ir.md)
- [Use-def chains](use-def-chains.md)

---

✅ Verified against: LLVM/MLIR 23.1.1
