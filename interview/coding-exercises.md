# Coding Exercises ✍️

Live-coding and whiteboard problems common in compiler and ML-systems
interviews. Each has a time box, what the interviewer is checking, hints,
and a **reference solution you have already run**: in
[codebases/](../codebases/) or [samples/](../samples/).

Try each one from a blank file first. Compare with the reference only after.

---

## C++ / data structures

### E1. Implement `isa`, `cast`, `dyn_cast` (20 min)

Given `class Value { Kind getKind() const; }` and three subclasses, write
`classof` for each, including a range check for an abstract middle class,
and the three templates.

- **Checking:** the `cast` vs `dyn_cast` contract, null handling, the enum-range trick, const propagation.
- **Hints:** `dyn_cast` returns `nullptr`; `cast` asserts. Make `dyn_cast<T>(const U*)` return `const T*`.
- **Reference:** `codebases/compiler-mechanics-cpp/03_rtti_isa_dyncast.cpp`, `codebases/llvm-idioms-workbench/module2-custom-rtti/include/Casting.h`

### E2. A minimal `SmallVector<T, N>` (30 min)

`push_back`, `size`, `operator[]`, a destructor, and growth from inline to heap storage.

- **Checking:** placement new, moving during growth, never freeing the inline buffer, alignment (`alignas(T) char buf[sizeof(T) * N]`).
- **Reference:** `codebases/llvm-idioms-workbench/module1-ast-ownership/include/SmallVector.h`

### E3. An intrusive doubly-linked list with self-removal (25 min)

Elements embed `prev`/`next`. Implement `push_back`, `insertBefore`, and a
static `remove(T*)`.

- **Checking:** a circular sentinel (no null checks), O(1) unlink, erase-while-iterating.
- **Reference:** `codebases/compiler-mechanics-cpp/04_ir_data_structures.cpp`

### E4. Replace a subtree safely (20 min)

With `std::unique_ptr` AST edges, implement `x + 0 → x` in place.

- **Checking:** move the child out of the parent before replacing the parent; no reads of the dangling parent afterward.
- **Reference:** `TryFoldBinary` in `codebases/llvm-idioms-workbench/module3-pass-manager/src/ConstantFoldingPass.cpp`

---

## Compiler algorithms

### E5. Constant folding over an expression tree (20 min)

Fold `(2 * 5) + (10 - 4)` to `16` in one post-order traversal. Then say
which identity you would **not** implement, and why.

- **Checking:** post-order, not folding across side effects (`x * 0` with a call in `x`).
- **Reference:** module 3 above; `constantFold` in `04_ir_data_structures.cpp`

### E6. Dominators on a small CFG (30 min)

Given successor lists, compute immediate dominators.

- **Checking:** reverse postorder, the `intersect` walk, the fixpoint loop, handling predecessors not yet processed.
- **Reference:** `computeIDom` in `codebases/compiler-mechanics-cpp/05_ssa_construction.cpp`

### E7. Liveness (30 min)

Compute live-in / live-out per block for a loop CFG.

- **Checking:** upward-exposed uses, the backward direction, the worklist that re-queues predecessors, termination.
- **Reference:** `computeLiveness` in `codebases/compiler-mechanics-cpp/06_dataflow_analysis.cpp` (expected fixpoint in its tests)

### E8. Place φ nodes (40 min, senior)

Given dominance frontiers and definition sites, place φs, then rename.

- **Checking:** the _iterated_ frontier worklist, stack-based renaming over the dominator tree, filling φ operands per incoming edge.
- **Reference:** `buildSSA` in `05_ssa_construction.cpp`

### E9. Graph coloring with K registers (30 min)

Simplify/select with optimistic spilling. Show a 4-cycle colors with K = 2.

- **Reference:** `allocate` in `codebases/compiler-mechanics-cpp/07_register_allocation.cpp`

---

## Performance / kernels (Mojo or C++)

### E10. SIMD vector add with a tail (15 min)

Any length `n`, native width.

- **Checking:** `simd_width_of`, the SIMD loop bound `i + width <= n`, the scalar tail.
- **Reference:** [samples/vadd.mojo](../samples/vadd.mojo)

### E11. Fast, accurate float sum (20 min)

Sum `n` floats faster than a scalar loop. Then explain why your answer differs from the scalar result.

- **Checking:** multiple SIMD accumulators, reducing once at the end, float non-associativity, and when a library may reorder.
- **Reference:** [samples/reduce_sum.mojo](../samples/reduce_sum.mojo) (real numbers on the [reduction page](../rosetta/reduction-in-5-irs.md))

### E12. Speed up a naive matmul (45 min, open-ended)

Start from the `(i, j, k)` loop. Explain each step and predict its effect before measuring.

- **Checking:** loop interchange, register blocking, cache blocking, measuring and verifying (`diff: 0.0`), honesty when a textbook step does not help.
- **Reference:** [samples/matmul_cpu.mojo](../samples/matmul_cpu.mojo), [matmul page](../rosetta/matmul-naive-tiled-fused.md)

### E13. Block reduction on a GPU (30 min)

Sum 256 floats per block using shared memory, then using warp shuffles.

- **Checking:** `barrier()` placement, halving the stride, thread 0 writing the result, the butterfly shuffle offsets.
- **Reference:** [samples/gpu_block_sum.mojo](../samples/gpu_block_sum.mojo), `warp_sum_kernel` in [samples/gpu_warp_and_coalescing.mojo](../samples/gpu_warp_and_coalescing.mojo)

---

## MLIR (take-home style)

### E14. Write a canonicalization pattern (45 min)

`relu(relu(x)) → relu(x)` for a custom op.

- **Reference:** `ReluOp::canonicalize` in nano-dsp-mlir (`lib/Dialect/DSP/IR/DSPOps.cpp`); see [Pattern rewrite](../03-transformations/pattern-rewrite.md)

### E15. Lower a custom op with a conversion pattern (60 min)

Lower `dsp.relu` to `linalg.generic` + `arith.maximumf` under a full-conversion target.

- **Reference:** `ReluOpLowering` in nano-dsp-mlir's `lib/Conversion/DSPToLinalg/DSPToLinalg.cpp`; see [Legalization](../02-ir-design/legalization.md)
