# Attributes and Properties 📎

> **One line:** An _attribute_ is a compile-time constant attached to an op
> (`5 : i32`, `sgt`, a dense array). A _property_ is an attribute that the
> op's definition declares and owns. A _discardable attribute_ is extra
> metadata anyone can attach and any pass may drop.

## 🖼️ Picture

Real generic output for [samples/attributes.mlir](../samples/attributes.mlir):

```
 %1 = "arith.cmpi"(%arg0, %0) <{predicate = 4 : i64}> : (i32, i32) -> i1
                    ────┬────  ─────────┬──────────
                    operands        property: which comparison.
                    (runtime)       4 is the enum value of "sgt";
                                    the pretty form prints `cmpi sgt`

 %2 = "arith.addf"(%arg1, %arg1) <{fastmath = #arith.fastmath<fast>}>
                                  {guide.note = "any dialect can attach me"}
                                  ─────────────────┬───────────────────────
                                   discardable attribute: {...} without <>,
                                   name must be prefixed with a dialect
                                   ("guide.") to avoid collisions
```

Pretty form, as you would write it:

```mlir
%gt = arith.cmpi sgt, %x, %c5 : i32
%s = arith.addf %y, %y fastmath<fast> {guide.note = "any dialect can attach me"} : f32
```

## 🔧 In each tool

| Kind                    | Syntax (generic)       | Owned by             | Example                                                                                                 |
| ----------------------- | ---------------------- | -------------------- | ------------------------------------------------------------------------------------------------------- |
| Property                | `<{ name = … }>`       | The op definition    | `value` on `arith.constant`, `predicate` on `cmpi`                                                      |
| Discardable attribute   | `{ dialect.name = … }` | Nobody in particular | Hints, analysis results, debug tags                                                                     |
| Attribute _value kinds_ | —                      | —                    | `5 : i32`, `"text"`, `[1, 2]`, `dense<0.0> : tensor<4xf32>`, `affine_map<...>`, `#arith.fastmath<fast>` |

| Tool    | Equivalent                                                                                                                                 |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| LLVM IR | Instruction flags (`nsw`, `fast`), constants, and **metadata** (`!tbaa`, `!llvm.loop`) which, like discardable attributes, passes may drop |
| MLIR    | Properties and attributes as above                                                                                                         |
| Triton  | `tl.constexpr` arguments become attributes/constants in the IR; op details like `evict_policy` are attributes                              |
| Mojo    | Compile-time **parameters** (`[width: Int]`) become constant values in the IR, much like attributes                                        |

## ⚠️ Common confusion

- **Attribute vs operand.** If the value is known at compile time and is
  part of _what the op is_ (compare _how_?), it is an attribute. If it is
  data flowing at runtime, it is an operand.
- **Attributes are immutable and uniqued.** Two `5 : i32` attributes are the
  same object in memory. You change an op's attribute by replacing it,
  never by editing it.
- **"Properties" are newer.** Older MLIR stored everything in one attribute
  dictionary. Properties are stored inline in the op for speed. You will see
  both styles in older blog posts.

## 🔗 Related

- [Operation](operation.md)
- [ODS and TableGen](ods-and-tablegen.md): where properties are declared
- [Parameters vs arguments (Mojo)](../06-mojo/parameters-vs-arguments.md)

---

✅ Verified against: MLIR 23.1.1
