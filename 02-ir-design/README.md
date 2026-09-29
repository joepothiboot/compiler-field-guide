# IR Design 🌐

How MLIR IR is built out of parts, and how it moves between levels.

| Page                                                         | In one line                                                                                                                                                                                            |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Dialect 🌐](dialect.md)                                     | A dialect is a named group of MLIR operations, types and attributes, for example `arith`, `scf`, `linalg` or `llvm`.                                                                                   |
| [Operation (Op) ⚙️](operation.md)                            | In MLIR, _everything_ is an operation: an add, a loop, a function, even the module itself.                                                                                                             |
| [Region 🪆](region.md)                                       | A region is a list of blocks nested _inside_ an op.                                                                                                                                                    |
| [Types in MLIR 🧮](types.md)                                 | Every SSA value has a type, and the type says what kind of data it is: a scalar (`i32`, `f32`), a SIMD vector (`vector<4xf32>`), an immutable array value (`tensor`) or a buffer in memory (`memref`). |
| [Attributes and Properties 📎](attributes-and-properties.md) | An _attribute_ is a compile-time constant attached to an op (`5 : i32`, `sgt`, a dense array).                                                                                                         |
| [ODS and TableGen 📝](ods-and-tablegen.md)                   | You declare an op once in a `.td` file (ODS, the Operation Definition Specification), and TableGen generates the C++ class, parser, printer and verifier for it.                                       |
| [Legalization 🚦](legalization.md)                           | Legalization means converting the IR until every op is one the next stage accepts.                                                                                                                     |

New pages start from [../_templates/term.md](../_templates/term.md).
