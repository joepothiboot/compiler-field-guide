# Value Names 🏷️

> **One line:** An SSA value's name tells you which tool printed it and often
> what it computes. Learn the printer's naming rules and IR becomes readable.

## 🖼️ Picture

```
  %arg0          ← function / block argument (MLIR printer)
  %0 %1 %2       ← unnamed result, numbered in order (LLVM, MLIR)
  %c0 %c1 %cst   ← constant (MLIR arith.constant printer hint)
  %alloc         ← memref.alloc result
  %arrayidx %add ← clang -O0, named after the C expression
  %rd7 %r3 %p1   ← PTX virtual register: 64-bit, 32-bit, predicate
  buf0 tmp0      ← Inductor-generated code (Python / Triton)
```

## 🔧 MLIR (printer names)

| Name                                                                              | Meaning                                                  | Seen here  |
| --------------------------------------------------------------------------------- | -------------------------------------------------------- | ---------- |
| `%arg0`, `%arg1`, ...                                                             | Argument of a function or block, numbered by position    | 73, 35     |
| `%0`, `%1`, ...                                                                   | Unnamed op result                                        | many       |
| `%c0`, `%c1`, `%c64`                                                              | `arith.constant` with an `index` value                   | 34, 28, 10 |
| `%c0_i32`, `%c5_i32`                                                              | `arith.constant` of an integer type; type is suffixed    | 18, 7      |
| `%cst`                                                                            | `arith.constant` of a float (or splat/dense)             | 8          |
| `%c1_0`, `%c1_1`                                                                  | Same name used again, so the printer appends `_N`        | 10         |
| `%alloc`, `%alloc_0`                                                              | Result of `memref.alloc`                                 | —          |
| `%dim`, `%dim_0`                                                                  | Result of `memref.dim` / `tensor.dim`                    | —          |
| `%empty`                                                                          | Result of `tensor.empty`                                 | —          |
| `%subview`, `%extracted_slice`, `%collapsed`, `%expanded`, `%transposed`, `%cast` | Result of the op of that name                            | —          |
| `%in`, `%out`, `%in_0`                                                            | Block arguments inside a `linalg.generic` body           | —          |
| `%block_id_x`, `%thread_id_x`, `%block_dim_x`                                     | `gpu.block_id`, `gpu.thread_id`, `gpu.block_dim` results | —          |

The rule: if an op declares a name hint (`OpAsmOpInterface`), the printer uses
it. Otherwise it prints a number. That is why constants are readable and
arithmetic results are `%0`, `%1`.

Names written by a human in `.mlir` files are kept: `%x`, `%y`, `%r`, `%s`,
`%i`, `%acc`, `%zero`, `%n` all appear in [samples/](../samples/) because
the samples were hand-written.

## 🔧 LLVM IR

| Name                                                     | Meaning                                           | Seen here |
| -------------------------------------------------------- | ------------------------------------------------- | --------- |
| `%0`, `%1`                                               | Unnamed temporaries                               | many      |
| `%retval`                                                | Slot for the return value (clang `-O0`)           | —         |
| `%x.addr`                                                | Stack slot holding parameter `x` (clang `-O0`)    | —         |
| `%arrayidx`                                              | `getelementptr` for `a[i]`                        | —         |
| `%add`, `%mul`, `%sub`, `%div`                           | Result of that C operator                         | —         |
| `%cmp`, `%tobool`, `%cond`                               | Comparison / bool conversion / ternary result     | —         |
| `%inc`, `%conv`, `%idxprom`                              | `i++`, a cast, an index widened to 64 bits        | —         |
| `%call`                                                  | Result of a call                                  | —         |
| `%i.0`, `%sum.0`                                         | φ for variable `i` / `sum` (after `mem2reg`)      | —         |
| `%indvars.iv`, `%indvars.iv.next`                        | Induction variable and its next value (`indvars`) | —         |
| `%exitcond`                                              | Loop-exit comparison                              | —         |
| `%vec.phi`, `%wide.load`, `%index`, `%bin.rdx`, `%n.vec` | Loop vectorizer output                            | —         |

Block labels follow the same idea: `entry`, `for.cond`, `for.body`, `for.inc`,
`for.end`, `if.then`, `if.else`, `if.end`, `vector.body`, `middle.block`.

## 🔧 PTX (NVIDIA virtual registers)

PTX declares typed register banks, and the prefix says the type.

| Prefix                               | Type                                                          | Seen here               |
| ------------------------------------ | ------------------------------------------------------------- | ----------------------- |
| `%r`                                 | 32-bit integer                                                | `%r1`...`%r12` (many)   |
| `%rd`                                | 64-bit integer (an address)                                   | `%rd1`...`%rd28` (many) |
| `%f`                                 | 32-bit float                                                  | —                       |
| `%fd`                                | 64-bit float                                                  | —                       |
| `%p`                                 | predicate (1 bit)                                             | `%p1`, `%p2`            |
| `%tid`, `%ntid`, `%ctaid`, `%nctaid` | Special registers: thread id, block size, block id, grid size | 13, 7, 13, —            |

In `ld.global.f32 %f1, [%rd4]` you can read the type off every operand.
See [ptx-ptxas-and-sass](../07-codegen-runtime/ptx-ptxas-and-sass.md).

## 🔧 Generated Python (Inductor, `torch.compile`)

| Name                                 | Meaning                                                                  | Seen here |
| ------------------------------------ | ------------------------------------------------------------------------ | --------- |
| `arg0_1`, `primals_1`, `tangents_1`  | Graph inputs; `primals` and `tangents` appear in forward/backward graphs | 3, —, —   |
| `buf0`, `buf1`                       | Intermediate buffer between kernels                                      | 3         |
| `tmp0`, `tmp1`                       | Scalar temporaries inside a generated Triton kernel                      | 4         |
| `in_ptr0`, `out_ptr0`, `in_out_ptr0` | Kernel pointer arguments: read, written, read-write                      | 4, 3, —   |
| `xindex`, `xmask`, `XBLOCK`          | Flattened element index, its bounds mask, block size                     | —         |
| `rindex`, `rmask`, `RBLOCK`          | The same for a reduction axis                                            | —         |
| `x0`, `x1`, `r1`                     | Index along one dimension (x0 is the inner one)                          | 13        |

## ⚠️ Common confusion

- **`%arg0` is not a name you chose.** If a function has parameters `a`, `b`
  in the source, MLIR calls them `%arg0`, `%arg1` unless you wrote names.
- **`%c0` is just a hint.** Two different constants can both print as `%c0_0`
  and `%c0_1`; the suffix is for uniqueness, not meaning.
- **`%r` in PTX is a register, `%r` in a hand-written MLIR sample is a result.**
  The same string means different things in different IRs.

## 🔗 Related

[ssa](../01-foundations/ssa.md) · [operation](../02-ir-design/operation.md) ·
[types](../02-ir-design/types.md) · [opcodes](opcodes.md)
