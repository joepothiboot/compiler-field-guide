# Question Bank: Optimizations and Codegen ⚙️

Answer out loud, then open the fold.

---

### 1. Pass vs pattern vs pass manager?

<details><summary>Answer</summary>

A pattern is a local rule (match an op shape, rewrite it). A pass is a
transformation or analysis over the whole IR, often driving many patterns.
The pass manager runs a pipeline of passes, nested by op type
(`builtin.module(func.func(canonicalize,cse))`), caches analyses, and can
time and dump each pass.

→ [Pass and pass manager](../03-transformations/pass-and-pass-manager.md)
</details>

### 2. How does MLIR's greedy pattern driver work, and how can it go wrong?

<details><summary>Answer</summary>

It keeps a worklist of ops, tries matching patterns on each, and after a
successful rewrite re-adds the affected ops and their users. It stops at a
fixpoint or at `max-iterations`. It goes wrong if two patterns undo each
other (A→B, B→A), or if IR is modified without going through the
`rewriter`, which the driver then doesn't see.

→ [Pattern rewrite](../03-transformations/pattern-rewrite.md)
</details>

### 3. Folding vs canonicalization?

<details><summary>Answer</summary>

Folding computes a result from existing values or constants and never
creates new ops (`addi 2, 3` → `5`, `x + 0` → `x`). Canonicalization rewrites
into a standard form using patterns that may create ops (e.g. an `scf.if`
selecting `x` or `0` → `arith.maxsi x, 0`, real output).

→ [Canonicalization and folding](../03-transformations/canonicalization-and-folding.md)
</details>

### 4. Why is `x + 0.0` not folded to `x` for floats?

<details><summary>Answer</summary>

If `x = -0.0`, then `-0.0 + 0.0 = +0.0`, which is not `x`. `x + (-0.0)` _is_
folded, because adding `-0.0` never changes a value. Real `mlir-opt` output in
`samples/float_fold.mlir` shows both.
</details>

### 5. What does CSE need to prove before merging two ops?

<details><summary>Answer</summary>

Same op name, same operands, same attributes, no side effects (e.g. a `load`
cannot be merged across a possible `store`), and the first op must dominate
the second.

→ [CSE and DCE](../03-transformations/cse-and-dce.md)
</details>

### 6. When is code "dead"?

<details><summary>Answer</summary>

When its results are unused **and** it has no side effects. An unused `store`
or `print` is not dead. `symbol-dce` removes unused private functions. The
inliner removed `@square` automatically once it had no callers.
</details>

### 7. Why inline? When not to?

<details><summary>Answer</summary>

Inlining removes call overhead, but the bigger benefit is that later passes
(CSE, fusion, constant propagation) can work across the former call
boundary. Don't inline when it grows code too much (instruction cache
pressure, compile time) or for recursive functions. GPU kernels are usually
fully inlined.

→ [Inlining](../03-transformations/inlining.md)
</details>

### 8. What is fusion and why is it the most important ML optimization?

<details><summary>Answer</summary>

Merging ops into one loop or kernel so intermediates stay in registers
instead of round-tripping through memory. Elementwise ops are memory-bound,
so fewer memory trips means real speedups: `relu(a+b)` goes from 5120 to 3072
floats of traffic. `--linalg-fuse-elementwise-ops` shows two `linalg.generic`
ops becoming one, and Inductor produced `cpp_fused_add_mul_relu_0`.

→ [Fusion](../03-transformations/fusion.md)
</details>

### 9. When does fusion NOT help?

<details><summary>Answer</summary>

When the fused op is small next to the main compute: in my matmul benchmark,
fusing relu into the epilogue made no visible difference (O(N²) vs O(N³)).
It can also hurt by raising register pressure and lowering GPU occupancy.
</details>

### 10. Explain tiling. Did it help in your benchmark?

<details><summary>Answer</summary>

Tiling splits loops into blocks that fit in fast memory so data is reused
before eviction. Honest answer from my M2 benchmark: textbook cache tiling
gave **no** speedup over the interchanged loop (the hardware prefetcher already
streams rows well). **Register blocking** (a 4×16 tile of C in SIMD registers)
gave 13×, and k-blocking added 2.3× at N=2048, where the data outgrows L2.

→ [Tiling](../03-transformations/tiling.md), [Matmul page](../rosetta/matmul-naive-tiled-fused.md)
</details>

### 11. What can stop a loop from auto-vectorizing?

<details><summary>Answer</summary>

Possible pointer aliasing (LLVM adds runtime overlap checks in `vadd`), unknown
trip counts (it needs a remainder loop), calls or complex control flow in the
body, non-contiguous access, and float reductions that would need
reordering. LLVM 23 vectorized the float sum but kept it **ordered**
(`llvm.vector.reduce.fadd` with a scalar running sum). Only `-ffast-math` gave
it 4 reassociated vector accumulators.

→ [Vectorization](../03-transformations/vectorization.md), [Reduction page](../rosetta/reduction-in-5-irs.md)
</details>

### 12. Why is floating-point reduction order a correctness issue?

<details><summary>Answer</summary>

Float addition is not associative. Real numbers from my sample: summing
16.7 M copies of `0.1f` in order gives 1,935,089, a 16-lane SIMD sum gives
1,694,270, and the float64 reference is 1,677,722. The reordered version was
more accurate _and_ 10× faster, but it gives a different result, so a
compiler may only reorder when allowed (fast-math / `reassoc`).
</details>

### 13. What is bufferization and what's its main risk?

<details><summary>Answer</summary>

Converting value-style `tensor` ops into `memref` buffers, deciding whether
each update can be in place. Main risk: unnecessary copies. Real example:
returning the original tensor as well forces `memref.alloc` + `memref.copy`.

→ [Bufferization](../03-transformations/bufferization.md)
</details>

### 14. What is instruction selection? Give an example of combining ops.

<details><summary>Answer</summary>

Mapping IR ops to target instructions, preferring combined forms. Real
AArch64 output: `mul` + `add` → `MADDXrrr`, and `fmul contract` + `fadd contract`
→ `FMADDSrrr`. Without `contract`, float mul+add aren't fused, because fusing
changes rounding. A later machine pass (MachineCombiner) rewrote
`mul`+`sub` into `neg` + `madd`.

→ [Instruction selection](../07-codegen-runtime/instruction-selection.md)
</details>

### 15. SelectionDAG vs GlobalISel?

<details><summary>Answer</summary>

Both are LLVM instruction selectors. SelectionDAG works on a DAG per basic
block and is the long-standing default. GlobalISel works on whole functions
in Machine IR and is used by AArch64 at `-O0`, with growing coverage. Both
use TableGen patterns from the target's `.td` files.
</details>

### 16. Explain register allocation as graph coloring.

<details><summary>Answer</summary>

Nodes are virtual registers. Edges connect values that are live at the same
time. Coloring with K colors assigns K physical registers. Chaitin–Briggs:
simplify nodes with degree < K, push one optimistically when stuck, and
select colors in reverse. If no color is free, spill. My mechanics test
shows Briggs coloring a 4-cycle with K = 2 with no spill, where Chaitin
would spill.

→ [Graph-coloring register allocation](../09-algorithms/graph-coloring-register-allocation.md)
</details>

### 17. What allocator does LLVM actually use?

<details><summary>Answer</summary>

Greedy (`RegAllocGreedy.cpp`) at `-O1+`: a priority queue of live ranges with
live-range splitting and eviction. Fast at `-O0`. The vocabulary is the same
(interference, spill, live range). Real MIR shows `%0..%5` becoming
`$x0/$x8/$x9`, with `isSSA` going from true to false.
</details>

### 18. What is liveness and how is it computed?

<details><summary>Answer</summary>

A variable is live at a point if some path from there reaches a use before a
redefinition. Backward dataflow: `OUT = ∪ IN(succ)`, `IN = USE ∪ (OUT − DEF)`,
where USE is upward-exposed uses only. Iterate with a worklist to a
fixpoint. Bitvectors make the meet a word-wise OR.

→ [Dataflow analysis](../09-algorithms/dataflow-analysis.md)
</details>

### 19. What is an ABI? Give a concrete example.

<details><summary>Answer</summary>

The binary calling contract. On AArch64: integer arguments in `x0–x7`,
floats in `d0–d7`, return in `x0`/`d0`, large structs by pointer. Real
example: `make_pair(a, b)` returning a 2-field struct compiles to a bare
`ret`, because `a` and `b` are already in the return registers `x0`, `x1`.
On x86-64, a 32-byte struct argument is passed on the stack instead.

→ [ABI and calling conventions](../07-codegen-runtime/abi-and-calling-conventions.md)
</details>

### 20. What does the linker do? What's a relocation?

<details><summary>Answer</summary>

It combines object files, resolves each undefined symbol (`U _square`) to a
definition (`T _square`), and patches the machine code at each relocation
(e.g. `ARM64_RELOC_BRANCH26 _square` on a `bl`). A missing definition gives
`Undefined symbols ... ld: symbol(s) not found`, a link error, not a compile
error.

→ [Linking and object files](../07-codegen-runtime/linking-and-object-files.md)
</details>
