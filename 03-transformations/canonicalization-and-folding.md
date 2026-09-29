# Canonicalization and Folding 🧹

> **One line:** _Folding_ computes an op's result at compile time when its
> inputs are constants (or trivially simplifies it, like `x + 0 → x`).
> _Canonicalization_ rewrites IR into one agreed "standard form", so later
> passes only need to handle one shape.

## 🌉 From frontend

Terser does both: `2 * 3` becomes `6` (folding), and `if (!a) b(); else c();`
becomes `a ? c() : b()` (a standard form). Prettier is canonicalization for
formatting: there is only one output, whatever the input style was, which
makes diffs meaningful. Canonical IR makes pattern matching simpler in the
same way.

## 🖼️ Picture

Real `mlir-opt --canonicalize` on [samples/fold_cse.mlir](../samples/fold_cse.mlir):

```
 BEFORE                                     AFTER --canonicalize
 ──────                                     ───────────────────
 %c2 = arith.constant 2                     %c5_i32 = arith.constant 5
 %c3 = arith.constant 3                     %0 = arith.muli %arg0, %c5_i32
 %c0 = arith.constant 0                     %1 = arith.muli %arg0, %c5_i32
 %five = arith.addi %c2, %c3   ── fold ──►   (5)
 %same = arith.addi %x, %c0    ── fold ──►   (x)
 %a = arith.muli %same, %five               return %0, %1
 %b = arith.muli %same, %five
 %dead = arith.subi %a, %b     ── no users, Pure → erased
 return %a, %b
```

Notice that canonicalize did **not** merge `%0` and `%1`, even though they
are identical. That is CSE's job (see [CSE and DCE](cse-and-dce.md)).

A bigger canonicalization, from the [dialect](../02-ir-design/dialect.md)
page: a whole `scf.if` that returns either `x` or `0` depending on `x > 0`
is recognized as `arith.maxsi %x, 0`.

## 🔧 In each tool

| Mechanism                 | Where it lives                                                                                     | Example                                           |
| ------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| `fold()`                  | A method on the op (`hasFolder = 1` in ODS)                                                        | `addi(c2, c3)` → constant `5`, `addi(x, 0)` → `x` |
| Canonicalization patterns | `getCanonicalizationPatterns()` or `hasCanonicalizeMethod = 1`                                     | nano-dsp's `relu(relu(x))` → `relu(x)`            |
| The pass                  | `--canonicalize` runs all folders + all canonicalization patterns of all loaded dialects, greedily | —                                                 |

| Tool   | Equivalent                                                                   |
| ------ | ---------------------------------------------------------------------------- |
| LLVM   | `InstCombine` / `InstSimplify` passes, and constant folding inside IRBuilder |
| MLIR   | `fold` + canonicalization patterns + `--canonicalize`                        |
| Triton | Runs MLIR canonicalize between its stages, plus Triton-specific combines     |
| Mojo   | Internal; `comptime` values are computed fully at compile time by design     |

## ⚠️ Common confusion

- **Folding never creates new ops.** A folder can only return an existing
  value or a constant. Anything that needs new ops is a pattern.
- **"Canonical" is a convention per dialect.** For example, constants are
  moved to the right-hand side of commutative ops (`5 + x` → `x + 5`), so a
  pattern only has to check one side.
- **Floating point is careful.** Real output for
  [samples/float_fold.mlir](../samples/float_fold.mlir): `x + 0.0` is
  **kept**, but `x + (-0.0)` is folded to `x`. The reason: if `x` is
  `-0.0`, then `-0.0 + 0.0 = +0.0`, which is not `x`. Adding `-0.0` never
  changes any value. Integers have no such issue. The same run also moved
  `5 + i` to `i + 5`:

  ```mlir
  %0 = arith.addf %arg0, %cst : f32        // x + 0.0: kept
  %1 = arith.addi %arg1, %c5_i32 : i32     // 5 + i  → i + 5
  return %0, %arg0, %1 : f32, f32, i32     // x + (-0.0) → x
  ```

## 🔗 Related

- [Pattern rewrite](pattern-rewrite.md)
- [CSE and DCE](cse-and-dce.md)
- [ODS and TableGen](../02-ir-design/ods-and-tablegen.md)

---

✅ Verified against: MLIR 23.1.1
