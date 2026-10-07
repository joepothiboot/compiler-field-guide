# Operation (Op) ⚙️

> **One line:** In MLIR, _everything_ is an operation: an add, a loop, a
> function, even the module itself. Every op has the same five parts:
> **name, operands, results, attributes/properties, regions**.

## 🖼️ Picture

```
   %2 = "arith.addf"(%0, %1) <{fastmath = #arith.fastmath<none>}> : (f32, f32) -> f32
   ─┬─   ─────┬────  ───┬───  ────────────────┬──────────────────   ─────┬────   ─┬─
    │         │         │                     │                          │        │
 results     name    operands          properties                operand types  result
 (SSA values                           (compile-time constants,                 types
  it defines)                           part of the op's definition)

   "scf.for"(%lb, %ub, %step) ({  ...body...  }) : (index, index, index) -> ()
                               ───────┬───────
                                    regions
                           (nested code the op owns)

  other parts, not shown:
  - successors: blocks a terminator can jump to (cf.br ^bb1)
  - location:   loc("file.mlir":9:3), used for error messages and debug info
```

## 🔧 In each tool

Every op has a **custom (pretty) form**, defined by its dialect, and a
**generic form** that works for any op. Real output of
`mlir-opt --mlir-print-op-generic` on [samples/vadd.mlir](../samples/vadd.mlir):

```mlir
// pretty form (what you write)
%s = arith.addf %x, %y : f32
scf.for %i = %c0 to %n step %c1 { ... }

// generic form (what every op really is)
%5 = "arith.addf"(%3, %4) <{fastmath = #arith.fastmath<none>}> : (f32, f32) -> f32
"scf.for"(%0, %2, %1) ({
^bb0(%arg3: index):
  ...
  "scf.yield"() : () -> ()
}) : (index, index, index) -> ()
```

Notice in the generic form:

- `func.func` and `builtin.module` are ordinary ops with a region.
- The loop variable `%i` is a **block argument** of the loop body.
- `scf.yield` is the terminator of the loop body region.

| Tool    | Equivalent of an "op"                                                                                       |
| ------- | ----------------------------------------------------------------------------------------------------------- |
| LLVM IR | An `Instruction`. Fixed set (`add`, `load`, `br` …); no regions; functions and modules are not instructions |
| MLIR    | `Operation`, open-ended: any dialect can define new ones                                                    |
| Triton  | `tt.load`, `tt.dot`, `tt.reduce` … are MLIR ops in the `tt` dialect                                         |
| Mojo    | Library functions eventually become MLIR ops; the `__mlir_op` syntax lets you write one directly            |

## ⚠️ Common confusion

- **The pretty form is only syntax sugar.** Two ops that print very
  differently have the same internal structure. When in doubt, print generic.
- **An op can have zero results** (`memref.store`, `scf.yield`). It exists
  for its side effect or as a terminator.
- **Traits and interfaces** describe op behavior: `Pure` (no side effects,
  safe to delete if unused), `Terminator`, `SameOperandsAndResultType`.
  Passes query these instead of hard-coding op names.

## 🧪 Seen in my projects

- nano-dsp-mlir: `dsp.relu` is declared `Pure` and `SameOperandsAndResultType`
  in `include/nanodsp/Dialect/DSP/IR/DSPOps.td`

## 🔗 Related

- [Region](region.md)
- [Attributes and properties](attributes-and-properties.md)
- [ODS and TableGen](ods-and-tablegen.md)

---

✅ Verified against: MLIR 23.1.1
