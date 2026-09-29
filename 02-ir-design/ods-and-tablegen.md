# ODS and TableGen 📝

> **One line:** You declare an op once in a `.td` file (ODS, the Operation
> Definition Specification), and **TableGen** generates the C++ class,
> parser, printer and verifier for it.

## 🌉 From frontend

Like writing a GraphQL schema or an OpenAPI spec and generating TypeScript
types and client code from it. You describe the _shape_ declaratively, and a
code generator writes the boilerplate that has to match it exactly.

```
 GraphQL / OpenAPI                  MLIR
 ─────────────────                  ────
 schema.graphql                     DSPOps.td          (declarative spec)
      │ graphql-codegen                  │ mlir-tblgen
      ▼                                  ▼
 types.ts, hooks.ts                 DSPOps.h.inc / DSPOps.cpp.inc  (generated C++)
      │                                  │
 your code imports them             your .cpp includes them and fills in
                                    only the custom parts (verify, canonicalize)
```

## 🖼️ Picture

A real op from nano-dsp-mlir
(`include/nanodsp/Dialect/DSP/IR/DSPOps.td`, commit `850be64`):

```tablegen
def DSP_ReluOp : DSP_Op<"relu", [Pure, SameOperandsAndResultType]> {
  │               │       │        └─ traits: no side effects; input and
  │               │       │           output have the same type
  │               │       └─ op name → "dsp.relu"
  │               └─ base class for all ops of the dsp dialect
  └─ TableGen record name

  let summary = "Elementwise max(x, 0) with NaN propagation.";

  let arguments = (ins DSP_Tensor:$input);        ← operands (and attributes)
  let results = (outs DSP_Tensor:$result);        ← results

  let assemblyFormat = [{                          ← generates parser + printer
    $input attr-dict `:` type($result)                for: dsp.relu %x : tensor<...>
  }];

  let hasCanonicalizeMethod = 1;                   ← "I will write canonicalize() in C++"
}
```

What `mlir-tblgen -gen-op-decls` generates from it (real output, trimmed):

```cpp
class ReluOp : public ::mlir::Op<ReluOp,
    ::mlir::OpTrait::ZeroRegions, ::mlir::OpTrait::OneResult,
    ::mlir::OpTrait::OneTypedResult<::mlir::RankedTensorType>::Impl,
    ::mlir::OpTrait::ZeroSuccessors, ::mlir::OpTrait::OneOperand,
    ...
    ::mlir::OpTrait::SameOperandsAndResultType,
    ::mlir::InferTypeOpInterface::Trait> {
public:
  static constexpr ::llvm::StringLiteral getOperationName() {
    return ::llvm::StringLiteral("dsp.relu");
  }
  ::mlir::TypedValue<::mlir::RankedTensorType> getInput() { ... }  // from $input
  ...
```

From about 15 lines of `.td`, you get a typed accessor `getInput()`, trait
checks, a parser and printer, and a verifier. The only hand-written part is
the canonicalize method (in `lib/Dialect/DSP/IR/DSPOps.cpp`):

```cpp
LogicalResult ReluOp::canonicalize(ReluOp op, PatternRewriter &rewriter) {
  // relu is idempotent -- max(max(x,0),0) == max(x,0), including for NaN.
  auto inner = op.getInput().getDefiningOp<ReluOp>();
  if (!inner)
    return failure();
  rewriter.replaceOp(op, inner.getResult());
  return success();
}
```

## 🔧 In each tool

| Tool   | How ops/instructions are declared                                                                                                                        |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM   | IR instructions are hand-written C++. TableGen (`llvm-tblgen`) is used for **target** descriptions: registers, instruction encodings, selection patterns |
| MLIR   | ODS `.td` + `mlir-tblgen` for ops, dialects, types, attributes, passes and interfaces                                                                    |
| Triton | Its `tt` / `ttg` dialects are defined in ODS `.td` files, like any MLIR dialect                                                                          |
| Mojo   | Not user-facing. Library code is written in Mojo itself                                                                                                  |

## ⚠️ Common confusion

- **TableGen is a generic record language; ODS is one use of it.** The
  same `tblgen` engine powers LLVM's backends, Clang's diagnostics and MLIR's
  ODS, each with its own generator (`-gen-op-decls`, `-gen-register-info` …).
- **You never edit `.inc` files.** They are regenerated on every build. If
  the generated code is wrong, fix the `.td`.
- **`assemblyFormat` is optional.** Without it, you write the parser and
  printer by hand in C++, or the op only has the generic form.

## 🧪 Seen in my projects

- nano-dsp-mlir: `DSPBase.td` (dialect), `DSPOps.td` (4 ops)
- json-schema-mlir: `include/Schema/SchemaDialect.td`, `SchemaOps.td`

## 🔗 Related

- [Operation](operation.md)
- [Attributes and properties](attributes-and-properties.md)
- [Canonicalization and folding](../03-transformations/canonicalization-and-folding.md)
- [Instruction selection](../07-codegen-runtime/instruction-selection.md): TableGen in LLVM backends

---

✅ Verified against: MLIR 23.1.1 · nano-dsp-mlir `850be64`
