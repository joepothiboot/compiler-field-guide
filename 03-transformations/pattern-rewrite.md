# Pattern Rewrite 🧩

> **One line:** A _rewrite pattern_ is a small local rule, "if you see this
> op in this shape, replace it with that". A _driver_ applies a set of
> patterns across the IR. MLIR has two main drivers: **greedy** (for
> simplification) and **dialect conversion** (for lowering).

## 🌉 From frontend

An ESLint rule with an autofix: it matches one AST node type, checks a
condition and emits a replacement. `eslint --fix` is the driver that keeps
applying fixes until no rule matches. MLIR's greedy driver works the same
way, repeating until the IR stops changing (a _fixpoint_).

## 🖼️ Picture

```
 GREEDY DRIVER (canonicalize, most cleanup passes)
 ───────────────────────────────────────────────
   worklist = all ops
   while worklist not empty:
     op = pop()
     for each pattern matching op.name:
       if pattern.matchAndRewrite(op) succeeds:
         push changed ops and their users back on the worklist
         break
   (stops at a fixpoint, or after max-iterations)

 DIALECT CONVERSION DRIVER (lowering)
 ────────────────────────────────────
   for each op marked ILLEGAL by the ConversionTarget:
     find a pattern that turns it into LEGAL ops
     (may chain several patterns; can roll back on failure)
   full conversion: any illegal op left = error
```

## 🔧 In each tool

Both kinds, from nano-dsp-mlir (`850be64`).

**Greedy pattern**: `dsp.relu(dsp.relu(x))` → `dsp.relu(x)`, in
`lib/Dialect/DSP/IR/DSPOps.cpp`:

```cpp
LogicalResult ReluOp::canonicalize(ReluOp op, PatternRewriter &rewriter) {
  auto inner = op.getInput().getDefiningOp<ReluOp>();   // MATCH: is my input a relu?
  if (!inner)
    return failure();                                    // no match → try other patterns
  rewriter.replaceOp(op, inner.getResult());             // REWRITE: use the inner result
  return success();
}
```

Real effect (`nanodsp-opt --canonicalize` on
[samples/dsp_relu.mlir](../samples/dsp_relu.mlir)):

```mlir
// before                                  // after
%a = dsp.relu %x : tensor<2x3xf32>         %0 = dsp.relu %arg0 : tensor<2x3xf32>
%b = dsp.relu %a : tensor<2x3xf32>         return %0 : tensor<2x3xf32>
return %b : tensor<2x3xf32>
```

The outer relu now has no users, so the driver erases it as dead code.

**Conversion pattern**: `dsp.relu` → `linalg.generic`, in
`lib/Conversion/DSPToLinalg/DSPToLinalg.cpp` (trimmed):

```cpp
struct ReluOpLowering : public OpConversionPattern<ReluOp> {
  LogicalResult
  matchAndRewrite(ReluOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    ...
    auto generic = rewriter.create<linalg::GenericOp>(
        loc, TypeRange{resTy},
        /*inputs=*/ValueRange{adaptor.getInput()},   // adaptor = operands AFTER conversion
        /*outputs=*/ValueRange{dest}, ...,
        [zero](OpBuilder &nested, Location nestedLoc, ValueRange args) {
          Value r = nested.create<arith::MaximumFOp>(nestedLoc, args[0], zero);
          nested.create<linalg::YieldOp>(nestedLoc, r);
        });
    rewriter.replaceOp(op, generic.getResults());
    return success();
  }
};
```

| Tool   | Pattern mechanism                                                                                                                        |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM   | Mostly hand-written visitors (`InstCombine` is one huge set of local rewrites); backends use TableGen patterns for instruction selection |
| MLIR   | `RewritePattern` / `OpRewritePattern<T>` (greedy), `OpConversionPattern<T>` (conversion), and PDLL / declarative `Pat<>` in TableGen     |
| Triton | Its passes are MLIR patterns, e.g. converting `tt.dot` into GPU-specific ops                                                             |
| Mojo   | Internal                                                                                                                                 |

## ⚠️ Common confusion

- **Always modify IR through the `rewriter`.** Changing ops directly
  (e.g. `op->erase()`) hides the change from the driver, and it breaks.
- **Pattern order is not guaranteed.** Each pattern must be correct no
  matter which others ran first. `benefit` lets you prefer one pattern
  over another.
- **Greedy patterns must not loop forever.** A pattern that rewrites A → B
  paired with another that rewrites B → A never reaches a fixpoint. The
  driver stops at `max-iterations` and reports it.

## 🔗 Related

- [Legalization](../02-ir-design/legalization.md)
- [Canonicalization and folding](canonicalization-and-folding.md)
- [Use-def chains](../01-foundations/use-def-chains.md)

---

✅ Verified against: MLIR 23.1.1 · nano-dsp-mlir `850be64`
