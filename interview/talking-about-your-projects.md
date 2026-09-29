# Talking About Your Projects 💬

Short, honest stories for "tell me about a project" and "what was the
hardest part?". Each follows the same shape and uses only facts you can
show: repository state, test results, and numbers measured in this guide.

```
 CONTEXT    one sentence: what it is
 DECISION   the engineering choice you made, and the alternative you rejected
 EVIDENCE   a test, a number, or real compiler output
 LIMIT      what it does NOT do yet (interviewers trust you more when you say it first)
```

---

## 📦 nano-dsp-mlir

- **Context:** An out-of-tree MLIR compiler for a small image/math DSL: a
  `dsp` dialect (add, relu, matmul, conv2d) lowered to `linalg.generic`, then
  to LLVM through upstream passes, plus a Mojo SIMD kernel library with the
  same semantics.
- **Decision:** The `dsp` → `linalg` lowering is a **full** conversion, so no
  `dsp` op can leak into later stages ("fails loudly instead of silently
  leaking"). `relu` lowers to `arith.maximumf`, not `maxnumf`, so NaN
  propagates like NumPy. Stated in the op's ODS description.
- **Evidence:** The Mojo kernels and the MLIR pipeline are tested against the
  same golden values, so each checks the other. `relu(relu(x))` folds via a
  canonicalization pattern (real `nanodsp-opt` output in
  [Pattern rewrite](../03-transformations/pattern-rewrite.md)).
- **Limit:** Tiling + vectorization (Stage 3, a Transform-dialect schedule)
  is designed but not started, per the README's status table.

## 📐 json-schema-mlir

- **Context:** Compiles a JSON Schema into a specialized native validator,
  instead of interpreting the rule tree at runtime.
- **Decision:** Raise rules into a `schema` dialect and simplify them **as
  constraints** (subsumption such as `min_length 5 ⊑ 2`, conjunction fusion)
  _before_ lowering, because those facts are lost once the IR is `arith`/`scf`.
- **Evidence:** The pipeline stages (`--schema-canonicalize`,
  `--lower-schema-to-std` with a `TypeConverter`, `--schema-to-llvm-pipeline`)
  and its tests.
- **Link to theory:** the "what is lost at each level" table on
  [A tensor's journey](../maps/tensor-journey-matmul-to-ptx.md) is the same
  argument.

## 🔍 vizmlir

- **Context:** A browser tool that reads `--mlir-print-ir-after-all` output
  and draws GPU work: blocks, warps, memory spaces, and coalescing verdicts for
  each access, following an access across passes.
- **Decision:** When an address is linear in thread/block ids and loop
  counters, it checks the verdict for **every** warp and iteration ("proven,
  not guessed"). It reads the IR but never runs it, and says so.
- **Evidence:** The PTX difference between coalesced (`shl 2`) and strided
  (`shl 7`) access in [Memory coalescing](../04-hardware/memory-coalescing.md)
  is exactly the pattern it classifies.

## 🛠️ llvm-idioms-workbench + compiler-mechanics-cpp

- **Context:** C++17 study code that re-implements the LLVM idioms and
  compiler algorithms interviews probe: ownership, `SmallVector`,
  `isa/dyn_cast`, a pass manager, SSA construction, dataflow, register allocation.
- **Decision:** Prove claims with instrumentation instead of comments: a
  counting `operator new`, an interpreter that checks SSA preserves
  results, a `verify()` for register allocation.
- **Evidence:** 11 test suites pass, also under ASan + UBSan
  (`scripts/test-codebases.sh --asan`). A 2-element argument list costs
  0 allocations. The identity rewrite keeps the same node address. 28
  allocations, 28 frees.

## 🧭 compiler-field-guide (this repo)

- **Context:** A single guide mapping compiler concepts across LLVM, MLIR,
  Triton, PyTorch and Mojo, with every listing produced on my machine.
- **Evidence you can quote:**
  - Matmul on an M2 core: **137 ms → 3.0 ms** at 512² (45×), **2.7 s → 0.24 s**
    at 2048² (11×), all bit-identical. The biggest win was register blocking,
    **not** the textbook cache tiling (which gave nothing).
  - Float sum of 16.7 M × `0.1f`: SIMD was **10× faster and more accurate**
    than in-order, which is exactly why compilers won't reorder it without
    fast-math.
  - LLVM 23 vectorizes a float sum at `-O2` but keeps it ordered
    (`llvm.vector.reduce.fadd`).
  - Upstream MLIR lowers `linalg.matmul` to PTX with one thread per block by
    default, which shows why tiling decisions must be made high in the stack.
  - Mojo 1.1 changes found by compiling (`fn` removed, `alias` → `comptime`,
    `__deinit__`, `max.gpu` imports).

## ❓ Answering "what was the hardest part?"

Pick a moment where measurement or a test changed your mind. From this
guide: "I expected cache tiling to speed up matmul on the M2. It didn't. The
hardware prefetcher already handled row streaming. Measuring showed the
real bottleneck was reloading C, and register blocking fixed it: 13× on the
same machine. I now measure before I optimize."
