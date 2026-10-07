# CSE and DCE ♻️

> **One line:** _Common subexpression elimination_ (CSE) computes identical
> expressions once and reuses the result. _Dead code elimination_ (DCE)
> deletes code whose result nobody uses.

## 🖼️ Picture

Real output on [samples/fold_cse.mlir](../samples/fold_cse.mlir):

```
 --cse only                               --canonicalize --cse
 ──────────                               ────────────────────
 %0 = arith.addi %c2, %c3                 %c5_i32 = arith.constant 5
 %1 = arith.addi %arg0, %c0               %0 = arith.muli %arg0, %c5_i32
 %2 = arith.muli %1, %0     ◄── %a        return %0, %0      ◄── both results
 return %2, %2              ◄── %b is gone,                      are the same value
                                %dead is gone too
```

- CSE alone merged `%a` and `%b` into `%2`, and removed `%dead`
  (the MLIR CSE pass also deletes trivially dead ops it finds).
- It did **not** fold the constants. That is canonicalize's job.
- Together they reduce the function to one multiply. The usual pipeline
  is `canonicalize, cse` repeated, because each can expose work for the other.

## 🔧 In each tool

What makes two ops "the same" for CSE:

```
 same op name   AND  same operands  AND  same attributes/properties
 AND  the op has no side effects (Pure)
 AND  the first one dominates the second
```

A `memref.load` is **not** CSE'd freely: a `store` between two loads could
change the value. Side effects block it.

| Tool   | CSE                                                   | DCE                                                                                     |
| ------ | ----------------------------------------------------- | --------------------------------------------------------------------------------------- |
| LLVM   | `early-cse`, `gvn` (global value numbering, stronger) | `dce`, `adce`, `globaldce` (unused functions)                                           |
| MLIR   | `--cse`                                               | Canonicalize erases unused `Pure` ops; `--symbol-dce` removes unused private functions  |
| Triton | MLIR CSE between stages                               | Same                                                                                    |
| Mojo   | Internal (MLIR + LLVM)                                | Internal; generic functions are only compiled for the parameter values you actually use |

## ⚠️ Common confusion

- **"Dead" means unused _and_ free of side effects.** A `print` or a
  `store` whose result is unused is not dead.
- **CSE can make code slower on GPUs.** Keeping a value alive longer to
  reuse it uses a register for longer. Sometimes recomputing is cheaper
  than keeping it (see [Occupancy](../04-hardware/occupancy.md)).
- **GVN vs CSE.** GVN also finds equivalences that are not textually
  identical, e.g. across different blocks and after simplification.

## 🔗 Related

- [Canonicalization and folding](canonicalization-and-folding.md)
- [Use-def chains](../01-foundations/use-def-chains.md)
- [Inlining](inlining.md)

---

✅ Verified against: MLIR 23.1.1
