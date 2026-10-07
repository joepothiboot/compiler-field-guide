# Pass and Pass Manager 🏭

> **One line:** A _pass_ is one transformation or analysis over the IR. The
> _pass manager_ runs an ordered pipeline of passes, nests them at the right
> level (module, function) and can time, dump or parallelize them.

## 🖼️ Picture

```
 --pass-pipeline="builtin.module(func.func(canonicalize,cse))"
                  ──────┬───────  ────┬────  ─────┬─────────
                        │             │           └─ passes run on each function
                        │             └─ "for every func.func inside..."
                        └─ "starting from the module..."

  builtin.module
  ├── func.func @a  ──► canonicalize ──► cse     ┐ functions are IsolatedFromAbove,
  ├── func.func @b  ──► canonicalize ──► cse     ├ so the pass manager can process
  └── func.func @c  ──► canonicalize ──► cse     ┘ them on separate threads

  analyses (DominanceInfo, LoopInfo ...) are computed on demand and
  cached; a pass that changes the IR invalidates them
```

## 🔧 In each tool

**Timing.** Real output of `mlir-opt --mlir-timing` on
[samples/fold_cse.mlir](../samples/fold_cse.mlir):

```
  Total Execution Time: 0.0140 seconds

  ----Wall Time----  ----Name----
    0.0069 ( 49.5%)  Parser
    0.0017 ( 12.3%)  'func.func' Pipeline
    0.0012 (  8.4%)    CanonicalizerPass
    0.0005 (  3.9%)    CSEPass
    0.0000 (  0.0%)      (A) DominanceInfo      ← (A) = an analysis CSE requested
    0.0012 (  8.3%)  Output
```

**Dumping IR between passes.** Real output of
`--convert-scf-to-cf --canonicalize --mlir-print-ir-after-all` (trimmed):

```
// -----// IR Dump After SCFToControlFlowPass: convert-scf-to-cf //----- //
    cf.cond_br %0, ^bb1, ^bb2
  ^bb1:  // pred: ^bb0
    cf.br ^bb3(%arg0 : i32)
  ^bb2:  // pred: ^bb0
    cf.br ^bb3(%c0_i32 : i32)
  ^bb3(%1: i32):  // 2 preds: ^bb1, ^bb2
    ...
// -----// IR Dump After CanonicalizerPass: canonicalize{... max-iterations=10 ...} //----- //
    %0 = arith.maxsi %arg0, %c0_i32 : i32
    return %0 : i32
```

This is exactly the data [vizmlir](https://github.com/joepothiboot/vizmlir)
visualizes.

| Tool   | Pass manager                                                                       | Useful flags                                                                  |
| ------ | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| LLVM   | New pass manager (`opt -passes=...`)                                               | `-print-after-all`, `-time-passes`, `-print-pipeline-passes`                  |
| MLIR   | `PassManager` / `OpPassManager`, nested by op type                                 | `--mlir-print-ir-after-all`, `--mlir-timing`, `--mlir-print-ir-after-failure` |
| Triton | Builds an MLIR pass pipeline per compile stage (`ttir` → `ttgir` → `llir` → `ptx`) | `MLIR_ENABLE_DUMP=1`, `TRITON_KERNEL_DUMP=1`                                  |
| Mojo   | Internal MLIR pipeline                                                             | `mojo build --emit llvm` / `--emit asm` to see the output                     |

## ⚠️ Common confusion

- **Transformation pass vs analysis.** An analysis (dominance, loop info)
  only computes facts. Transformation passes consume those facts and change
  the IR, which invalidates them.
- **Pass options** appear in braces: `canonicalize{max-iterations=10}`.
  The dump header above shows every option with its value.
- **Nesting errors.** Running a function-only pass directly on the module
  fails. Real output for `--pass-pipeline="builtin.module(affine-loop-tile)"`:
  `Can't add pass 'AffineLoopTiling' restricted to 'func.func' on a
PassManager intended to run on 'builtin.module', did you intend to nest?`
  The fix is the `func.func(...)` wrapper.

## 🔗 Related

- [Pattern rewrite](pattern-rewrite.md)
- [Canonicalization and folding](canonicalization-and-folding.md)

---

✅ Verified against: MLIR 23.1.1
