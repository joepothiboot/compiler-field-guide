# The Whole Stack 🗺️

> **One line:** Each tool is a different entry point that eventually reaches
> the same few layers: MLIR, then LLVM IR, then machine code for a CPU or GPU.

## 🖼️ Picture

```
 WHAT YOU WRITE         ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
                        │ PyTorch      │  │ Triton       │  │ Mojo         │
                        │ model (.py)  │  │ kernel (.py) │  │ (.mojo)      │
                        └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
                               │ torch.compile   │ @triton.jit     │ mojo build
 ───────────────────────────── ▼ ─────────────── │ ─────────────── │ ──────────
 GRAPH LEVEL            ┌──────────────┐         │                 │
 whole model,           │ FX graph     │         │                 │
 ops on tensors         │ (Dynamo)     │         │                 │
                        └──────┬───────┘         │                 │
                               │ Inductor writes │                 │
                               └───Triton code──►│                 │
 ─────────────────────────────────────────────── ▼ ─────────────── ▼ ──────────
 MLIR LEVEL                               ┌──────────────┐  ┌──────────────┐
 many dialects,                           │ tt  (Triton) │  │ Mojo's own   │
 lowered step                             │  ▼           │  │ internal     │
 by step                                  │ ttg (layouts)│  │ dialects     │
                                          └──────┬───────┘  └──────┬───────┘
      upstream MLIR (used by your projects):     │                 │
      linalg → scf / affine → cf → llvm dialect  │                 │
                          │                      │                 │
 ──────────────────────── ▼ ──────────────────── ▼ ─────────────── ▼ ──────────
 LLVM IR                ┌─────────────────────────────────────────────────────┐
 one SSA IR,            │  LLVM IR   (define, br, phi, load, fadd, ...)       │
 target-independent     │  optimized by LLVM passes (opt -O2)                  │
                        └───────────────┬─────────────────────┬───────────────┘
 ────────────────────────────────────── ▼ ─────────────────── ▼ ──────────────
 TARGET                 ┌──────────────────────┐   ┌──────────────────────────┐
                        │ CPU backend          │   │ GPU backend (NVPTX)      │
                        │ x86-64 / AArch64 asm │   │ PTX ──ptxas──► SASS/cubin│
                        └──────────────────────┘   └──────────────────────────┘
```

## 📏 How to read it

- **Going down the diagram is called lowering.** Each step removes some
  high-level meaning ("this is a matmul") and adds concrete detail ("this is a
  loop, this is a load from address X").
- **MLIR is a framework, not one IR.** It lets you define many IRs (called
  _dialects_) and move a program between them. Triton and Mojo both build
  their own dialects on top of it.
- **LLVM IR is where the paths join.** Almost every path passes through it,
  because LLVM already has mature backends for CPUs and GPUs.
- **PyTorch reaches the GPU through Triton.** `torch.compile` (TorchInductor)
  writes Triton kernels for you on GPU.

## 🔧 Where each tool sits

| Tool             | You write            | It owns these layers                                     | Hands off to            |
| ---------------- | -------------------- | -------------------------------------------------------- | ----------------------- |
| PyTorch Inductor | Python model         | Graph capture, fusion decisions                          | Triton (GPU), C++ (CPU) |
| Triton           | Python kernel        | `tt` → `ttg` dialects, GPU layouts                       | LLVM IR → PTX           |
| Mojo             | Mojo source          | The language and its internal MLIR dialects              | LLVM IR → CPU / GPU     |
| MAX              | Graph of ops         | Graph compiler, kernels written in Mojo                  | Mojo kernels            |
| Upstream MLIR    | Dialect IR (`.mlir`) | `linalg`, `scf`, `affine`, `cf`, `llvm` ...              | LLVM IR                 |
| LLVM             | LLVM IR (`.ll`)      | Optimization, instruction selection, register allocation | Machine code            |

## 🧪 Where my projects sit

```
json-schema-mlir :  JSON schema ──► custom dialect ──► upstream MLIR ──► LLVM IR
nano-dsp-mlir    :  dsp dialect ──► linalg ──► loops ──► LLVM IR    (+ Mojo kernels
                                                                     as a second
                                                                     implementation)
vizmlir          :  reads the .mlir text at each step, draws the GPU work, shows the differences
```

## 🔗 Related

- [Dialect](../02-ir-design/dialect.md): the building block of the MLIR level
- [Vector add in 5 IRs](../rosetta/vector-add-in-5-irs.md): one program at each level

---

✅ Verified against: LLVM/MLIR 23.1.1 · Mojo 1.1.0 · Triton: from the Triton
docs, not run locally
