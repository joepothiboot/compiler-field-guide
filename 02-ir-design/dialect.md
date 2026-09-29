# Dialect 🗣️

> **One line:** A dialect is a named group of MLIR operations, types and
> attributes, for example `arith`, `scf`, `linalg` or `llvm`. A program can
> mix several dialects at once, and compiling it means gradually converting
> the high-level dialects into low-level ones.

## 🌉 From frontend

Think of a web page that mixes HTML, CSS and SVG in one document. Each has
its own vocabulary and its own namespace, and they sit together in one tree.
MLIR dialects work the same way, with a prefix on every op:

```
arith.addf     ← op "addf" from the arith dialect
scf.for        ← op "for"  from the scf dialect
llvm.icmp      ← op "icmp" from the llvm dialect
```

The analogy stops working because, unlike HTML/CSS/SVG, dialects are
designed to be **converted into each other**, step by step, until only the
`llvm` dialect is left.

## 🖼️ Picture

Progressive lowering of one function
([samples/max_or_zero.scf.mlir](../samples/max_or_zero.scf.mlir)). Every
listing below is real `mlir-opt` output:

```
 ┌───────────────────────────────────────────────────────────┐
 │ LEVEL 1   func + arith + scf        (structured: if/else) │
 │   %r = scf.if %pos -> (i32) {                             │
 │     scf.yield %x : i32                                    │
 │   } else {                                                │
 │     scf.yield %zero : i32                                 │
 │   }                                                       │
 └──────────────────────────┬────────────────────────────────┘
                            │ --convert-scf-to-cf
                            ▼
 ┌───────────────────────────────────────────────────────────┐
 │ LEVEL 2   func + arith + cf         (blocks and jumps)    │
 │   cf.cond_br %0, ^bb1, ^bb2                               │
 │ ^bb1:  cf.br ^bb3(%arg0 : i32)                            │
 │ ^bb2:  cf.br ^bb3(%c0_i32 : i32)                          │
 │ ^bb3(%1: i32): ...  return %1 : i32                       │
 └──────────────────────────┬────────────────────────────────┘
                            │ --convert-to-llvm
                            ▼
 ┌───────────────────────────────────────────────────────────┐
 │ LEVEL 3   llvm dialect only         (1:1 with LLVM IR)    │
 │   %1 = llvm.icmp "sgt" %arg0, %0 : i32                    │
 │   llvm.cond_br %1, ^bb1, ^bb2                             │
 │   ...  llvm.return %2 : i32                               │
 └──────────────────────────┬────────────────────────────────┘
                            │ mlir-translate --mlir-to-llvmir
                            ▼
 ┌───────────────────────────────────────────────────────────┐
 │ LLVM IR   (leaves MLIR)                                   │
 │   %2 = icmp sgt i32 %0, 0                                 │
 │   %6 = phi i32 [ 0, %4 ], [ %0, %3 ]                      │
 └───────────────────────────────────────────────────────────┘
```

Where the common upstream dialects sit:

```
 HIGH  │ tensor, linalg          "matmul these two tensors"
       │ affine, scf             "loop i from 0 to N", structured control flow
       │ memref, vector, arith   buffers, SIMD vectors, math on scalars
       │ cf                      unstructured blocks and jumps
 LOW   │ llvm, nvvm, rocdl       1:1 with LLVM IR / GPU intrinsics
```

## 🔧 In each tool

| Tool    | Dialects                                                                                                                                        |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM IR | Has no dialects. It is a single fixed IR. MLIR's `llvm` dialect mirrors it.                                                                     |
| MLIR    | Upstream: `func`, `arith`, `scf`, `cf`, `memref`, `tensor`, `linalg`, `vector`, `gpu`, `llvm` … and you can define your own in TableGen (`.td`) |
| Triton  | Its own dialects: `tt` (Triton IR, tile-level ops) and `ttg` (TritonGPU, adds data layouts), then lowered to `llvm` + `nvvm`                    |
| Mojo    | Built on MLIR with Modular's internal dialects. You do not see them, but you can call MLIR ops directly with `__mlir_op` (advanced)             |

## ⚠️ Common confusion

- **"Converting to `llvm` dialect" is not "producing LLVM IR".** The `llvm`
  dialect is still MLIR text. `mlir-translate` is a separate step that
  leaves MLIR and writes real `.ll`.
- **Mixed-dialect IR is normal.** Level 2 above mixes `func`, `arith` and
  `cf` at the same time. A pass converts only the dialects it is responsible
  for and leaves the rest unchanged.
- **The lowering path is a choice.** `linalg` can go through `affine` or
  straight to `scf`. Different projects choose differently.

## 🧪 Seen in my projects

- nano-dsp-mlir: custom `dsp` dialect in `include/nanodsp/Dialect/DSP/IR/DSPOps.td`,
  lowered to `linalg` and then to loops
- json-schema-mlir: the `schema` dialect (`include/Schema/SchemaOps.td`)
  simplifies validation rules while they are still constraints, then lowers
  to `arith` / `scf` / `math` and on to LLVM IR

## 🔗 Related

- [The whole stack](../maps/the-whole-stack.md)
- [Bundler plugins vs passes](../00-bridge/bundler-plugins-vs-passes.md)
- [SSA](../01-foundations/ssa.md): why block arguments become `phi`

---

✅ Verified against: MLIR 23.1.1
