# Legalization 🚦

> **One line:** Legalization means converting the IR until every op is one
> the next stage accepts. A **ConversionTarget** lists what is _legal_ and
> _illegal_, and conversion patterns rewrite the illegal ops.

## 🌉 From frontend

A browserslist target says "the output must run in Safari 15". Babel then
rewrites every feature Safari 15 does not support, and leaves the rest
alone. If a feature has no transform, the build fails. The ConversionTarget
is the browserslist. The conversion patterns are the Babel transforms.

## 🖼️ Picture

```
 ConversionTarget
 ┌────────────────────────────────────────────┐
 │ LEGAL:    arith, linalg, tensor, func       │
 │ ILLEGAL:  dsp (the whole dialect)           │
 └────────────────────────────────────────────┘

 input                        patterns                 output
 ─────                        ────────                 ──────
 dsp.relu   (illegal) ──► ReluOpLowering  ──► linalg.generic + arith.maximumf
 dsp.add    (illegal) ──► AddOpLowering   ──► linalg.generic + arith.addf
 func.return (legal)  ──────── untouched ─────► func.return

 FULL conversion:     every illegal op must be converted, or the pass fails
 PARTIAL conversion:  illegal ops without a pattern are left in place
```

## 🔧 In each tool

A real ConversionTarget from nano-dsp-mlir
(`lib/Conversion/DSPToLinalg/DSPToLinalg.cpp`):

```cpp
ConversionTarget target(*ctx);
target.addIllegalDialect<DSPDialect>();
target.addLegalDialect<arith::ArithDialect, linalg::LinalgDialect,
                       tensor::TensorDialect, func::FuncDialect>();
target.addLegalOp<ModuleOp>();

RewritePatternSet patterns(ctx);
populateDSPToLinalgPatterns(patterns);

// Full conversion: nothing from 'dsp' may survive.
if (failed(applyFullConversion(getOperation(), target, std::move(patterns))))
  signalPassFailure();
```

Real result of running it (`nanodsp-opt --convert-dsp-to-linalg` on
[samples/dsp_relu.mlir](../samples/dsp_relu.mlir)):

```mlir
%0 = tensor.empty() : tensor<2x3xf32>
%cst = arith.constant 0.000000e+00 : f32
%1 = linalg.generic {indexing_maps = [#map, #map], iterator_types = ["parallel", "parallel"]}
     ins(%arg0 : tensor<2x3xf32>) outs(%0 : tensor<2x3xf32>) {
^bb0(%in: f32, %out: f32):
  %2 = arith.maximumf %in, %cst : f32
  linalg.yield %2 : f32
} -> tensor<2x3xf32>
```

**What happens when something is left over.** Upstream `--convert-to-llvm`
is a _partial_ conversion. Running it without `--convert-scf-to-cf` first
leaves the `scf.if` in place. `mlir-opt` does not complain, but the next
stage does. Real output:

```mlir
llvm.func @max_or_zero(%arg0: i32) -> i32 {
  %1 = llvm.icmp "sgt" %arg0, %0 : i32
  %2 = scf.if %1 -> (i32) {          ← still here: nothing converted scf
```

```
$ mlir-translate --mlir-to-llvmir
error: Dialect `scf' not found for custom op 'scf.if'
```

| Tool   | Legalization                                                                                                                                 |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM   | In the backend: "type legalization" splits types the CPU lacks (e.g. `i128` → two `i64`), "op legalization" expands unsupported instructions |
| MLIR   | `ConversionTarget` + `applyFullConversion` / `applyPartialConversion`                                                                        |
| Triton | Its `tt` → `ttg` → `llvm` conversions are MLIR dialect conversions                                                                           |
| Mojo   | Internal; you see it only if something cannot be compiled for a target                                                                       |

## ⚠️ Common confusion

- **Partial conversion can hide problems.** It succeeds with illegal ops
  still present, and the error appears in a later stage (as above). Use
  full conversion when "nothing may survive" is the contract.
- **Type conversion is part of it.** Lowering `tensor`/`memref` types to
  LLVM structs needs a `TypeConverter` alongside the op patterns. Mismatches
  show up as `unrealized_conversion_cast` ops, which
  `--reconcile-unrealized-casts` must clean up.
- **Dynamic legality:** an op can be legal only in some cases, e.g.
  `target.addDynamicallyLegalOp<...>(callback)`.

## 🔗 Related

- [Dialect](dialect.md)
- [Pattern rewrite](../03-transformations/pattern-rewrite.md)
- [Instruction selection](../07-codegen-runtime/instruction-selection.md)

---

✅ Verified against: MLIR 23.1.1 · nano-dsp-mlir `850be64`
