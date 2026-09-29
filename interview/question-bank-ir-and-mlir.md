# Question Bank: IR and MLIR 🏗️

Answer out loud, then open the fold.

---

### 1. What is SSA and why do compilers use it?

<details><summary>Answer</summary>

Static single assignment: every value has exactly one definition. Use-def is
then trivial (one reaching definition per use), so constant propagation, CSE,
DCE and value numbering become simple. At control-flow joins, φ nodes (LLVM)
or block arguments (MLIR) merge values from different paths.

→ [SSA](../01-foundations/ssa.md)
</details>

### 2. φ node vs block argument?

<details><summary>Answer</summary>

Same meaning, different syntax. LLVM puts `phi [v1, %pred1], [v2, %pred2]` at
the top of a block. MLIR gives blocks parameters, and each branch passes
values: `cf.br ^bb3(%x : i32)`. When MLIR is translated to LLVM IR, block
arguments become φs (real `mlir-translate` output on the SSA page).
</details>

### 3. How is SSA constructed?

<details><summary>Answer</summary>

Compute dominators and dominance frontiers. For each variable, place φs at the
iterated dominance frontier of its definition blocks. Rename with a DFS over the
dominator tree, keeping a stack of current versions per variable. Remove dead
φs (pruned SSA). LLVM's `mem2reg` does this for `alloca`s.

→ [SSA construction](../09-algorithms/ssa-construction.md)
</details>

### 4. Define dominance. Why does SSA require it?

<details><summary>Answer</summary>

A dominates B if every path from entry to B passes through A. In SSA, a
definition must dominate each use, otherwise some path reaches the use
without the value existing. MLIR reports this as `operand #0 does not
dominate this use` (real error in `samples/bad_dominance.mlir`).

→ [Dominance](../01-foundations/dominance.md)
</details>

### 5. What is a dominance frontier?

<details><summary>Answer</summary>

DF(A) = the blocks B where A dominates a predecessor of B but does not strictly
dominate B: where A's dominance "runs out". Those are exactly the places a
definition in A may need a φ.
</details>

### 6. What is a basic block? What makes something a loop in the CFG?

<details><summary>Answer</summary>

A basic block is straight-line code with one entry at the top and one
terminator at the end. A loop is identified by a **back edge**, an edge whose
target dominates its source. The target is the header. Compilers find loops
from the graph, not from syntax.

→ [Basic block and CFG](../01-foundations/basic-block.md), [Loops in IR](../01-foundations/loops-in-ir.md)
</details>

### 7. What's the difference between an AST and an IR?

<details><summary>Answer</summary>

An AST mirrors the source syntax (`IfStmt`, `ForStmt`). An IR describes
behavior in a form designed for analysis: blocks, jumps, SSA values. Every
kind of loop becomes the same CFG shape, so one optimization handles all of them.
</details>

### 8. What is MLIR and why does it exist?

<details><summary>Answer</summary>

A framework for building IRs. Instead of one fixed IR like LLVM's, you define
**dialects** (ops, types, attributes) at different abstraction levels and
lower between them progressively. High-level facts ("this is a matmul")
survive long enough for high-level optimizations like tiling and fusion.
Triton, Mojo and many ML compilers are built on it.

→ [Dialect](../02-ir-design/dialect.md)
</details>

### 9. What are the parts of an MLIR operation?

<details><summary>Answer</summary>

Name, operands, results, attributes/properties, regions, successors and a
location. `--mlir-print-op-generic` prints any op in this uniform form.

→ [Operation](../02-ir-design/operation.md)
</details>

### 10. What is a region? What does `IsolatedFromAbove` mean?

<details><summary>Answer</summary>

A region is a list of blocks owned by an op (loop body, `if` branches, a
function body). Code inside can use values from enclosing regions that
dominate it. `IsolatedFromAbove` (e.g. `func.func`) forbids that, which
also lets the pass manager process functions in parallel.

→ [Region](../02-ir-design/region.md)
</details>

### 11. Attribute vs operand? Property vs discardable attribute?

<details><summary>Answer</summary>

Operands are runtime SSA values. Attributes are compile-time constants.
Properties are attributes the op definition declares and owns (e.g.
`cmpi`'s predicate, printed as `<{predicate = 4 : i64}>`). Discardable
attributes (`{dialect.name = ...}`) are extra metadata that passes may drop.

→ [Attributes and properties](../02-ir-design/attributes-and-properties.md)
</details>

### 12. `tensor` vs `memref` vs `vector`?

<details><summary>Answer</summary>

`tensor`: an immutable value with no address, which makes optimization easy.
`memref`: a buffer in memory (pointer + offset + sizes + strides) that can be
stored to. `vector`: a fixed-size SIMD value held in registers.
Bufferization converts tensors to memrefs.

→ [Types in MLIR](../02-ir-design/types.md)
</details>

### 13. What is ODS / TableGen?

<details><summary>Answer</summary>

A declarative `.td` spec for ops (operands, results, traits, assembly
format). `mlir-tblgen` generates the C++ class, accessors, parser, printer
and verifier. You hand-write only custom logic (verify, fold,
canonicalize). In nano-dsp, `DSP_ReluOp` in `DSPOps.td` becomes `class ReluOp`
with `getInput()`.

→ [ODS and TableGen](../02-ir-design/ods-and-tablegen.md)
</details>

### 14. What is progressive lowering?

<details><summary>Answer</summary>

Lowering in many small steps through several dialects instead of one big
jump: e.g. `scf` → `cf` → `llvm` dialect → LLVM IR. Each step is simple and
testable, and mixed-dialect IR is normal between steps.
</details>

### 15. Partial vs full dialect conversion?

<details><summary>Answer</summary>

Both use a `ConversionTarget` (legal/illegal ops) and patterns. Full
conversion fails if any illegal op remains. Partial conversion leaves
unconverted ops in place. Real example: `--convert-to-llvm` without
`--convert-scf-to-cf` leaves `scf.if` behind, and `mlir-translate` then fails.
nano-dsp uses full conversion so no `dsp` op can leak into later stages.

→ [Legalization](../02-ir-design/legalization.md)
</details>

### 16. What is the `llvm` dialect vs LLVM IR?

<details><summary>Answer</summary>

The `llvm` dialect is MLIR ops that mirror LLVM IR one-to-one, still in MLIR
text. `mlir-translate --mlir-to-llvmir` leaves MLIR and produces real `.ll`.
</details>

### 17. How are values connected in the IR (use-def)?

<details><summary>Answer</summary>

Each value keeps a list of its uses. Each use points to its single
definition. `replaceAllUsesWith` is O(uses). `--mlir-print-value-users` prints
the lists as comments. Memory dependencies are **not** tracked this way;
they need alias analysis.

→ [Use-def chains](../01-foundations/use-def-chains.md)
</details>

### 18. What does `index` mean in MLIR?

<details><summary>Answer</summary>

An integer type whose width depends on the target (64-bit on typical
hosts), used for sizes, loop bounds and indices.
</details>

### 19. How would you add a new op to a dialect end to end?

<details><summary>Answer</summary>

Declare it in ODS (operands, results, traits, assembly format), rebuild so
TableGen regenerates the C++, add verify/fold/canonicalize if needed, add a
conversion pattern to lower it and register it in the pass's pattern set,
and add lit tests (`.mlir` + `// CHECK:` lines) for parsing, verification
errors and lowering. nano-dsp's four ops follow exactly this path.
</details>

### 20. What is "dialect conversion type conversion" and why does `unrealized_conversion_cast` appear?

<details><summary>Answer</summary>

When lowering changes types (e.g. `!schema.value` → `i64` in
json-schema-mlir, or `memref` → LLVM struct), a `TypeConverter` maps them.
Where converted and unconverted code meet, the framework inserts
`unrealized_conversion_cast`, which must cancel out later
(`--reconcile-unrealized-casts`). Leftover casts mean an incomplete lowering.
</details>
