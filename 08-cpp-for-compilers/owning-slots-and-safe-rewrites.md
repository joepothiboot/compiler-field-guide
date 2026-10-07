# Owning Slots and Safe Rewrites ✂️

> **One line:** A transformation that replaces a node must write through the
> **owning edge** (`std::unique_ptr<Node>&`, a "slot"), not just the node
> pointer. When a child must survive its parent (`x + 0 → x`), move it out of
> the parent **first**, then replace the parent. After that, every raw pointer
> into the old subtree is dangling.

## 🖼️ Picture

```
 WHY THE SLOT                                  THE DANGEROUS CASE: bar + 0 → bar
 ────────────                                  ─────────────────────────────────
 bool Run(ExprPtr &Root)                        Slot ──► Binary '+'
          ^^^^^^^^^^^^^                                   ├─ Lhs ──► Call 'bar'   (must SURVIVE)
 folding `1 + 2` at the ROOT replaces                     └─ Rhs ──► Number 0
 the root object itself; with only an
 ExprAST* the pass couldn't tell its           1. Hoisted = std::move(Bin->LhsSlot())
 caller "your root is a new object"               → Bin's Lhs edge is now NULL
                                                2. Slot = std::move(Hoisted)
 LLVM: Value* vs Use& — you need the use          → old '+' destroyed; its Lhs is null,
 (the edge) to replace what it points at             so 'bar' is NOT freed; Slot → 'bar'
                                                3. never touch Bin again (dangling)
```

## 🔧 In each tool

From the workbench,
[module3-pass-manager](../codebases/llvm-idioms-workbench/module3-pass-manager/)
(`src/ConstantFoldingPass.cpp`).

**Case 1: fold two constants.** Build the replacement first, then publish it:

```cpp
ExprPtr Folded = std::make_unique<NumberExprAST>(Value);  // can't fail after this
Slot = std::move(Folded);
// unique_ptr::operator= releases the source, then deletes the old pointee:
//   the BinaryExprAST and its two Number children are destroyed, exactly once.
// `Bin`, `Lhs` and `Rhs` are DANGLING from here on.
```

**Case 2: an identity rule hoists a surviving subtree.**

```cpp
ExprPtr Hoisted;
switch (Bin->GetOp()) {
case '+':
  if (IsLiteral(Bin->GetRhs(), 0.0))
    Hoisted = std::move(Bin->GetLhsSlot());   // parent's edge becomes null
  ...
}
if (Hoisted) {
  Slot = std::move(Hoisted);                   // parent dies; the child survives
  ++NumSimplified;
  return true;
}
```

Real demo output, which proves it moved rather than copied, and that nothing
leaked or was freed twice:

```
== pipeline ==

  constant-folding: changed - 4 node(s) folded, 0 identity(ies) simplified
  dead-code-elimination: changed - 2 unreachable statement(s) removed
  pipeline reported changes

== why Run() takes unique_ptr<ExprAST> & ==

  before: Binary '+' at 0x100a8d2c0
  after:  Number 3
          at 0x100a8d2e0
  the root node itself was replaced, so the pass had to write
  through the caller's owning pointer.

== identity simplification moves, it does not copy ==

  'bar' node before: 0x100a8d280
  root node after:   0x100a8d280
  same node: true - the subtree survived its parent's destruction because
  ownership was transferred out of the parent first.

== allocation balance across mutation ==

  28 allocations, 28 frees
  balanced: true (a leak would show up here; a double free would have crashed)
```

(Addresses differ between runs.)

**Dead code elimination** removes everything after a `return` with one
`Stmts.truncate(I + 1)`. Each removed `unique_ptr` destroys its whole
subtree, and the container never holds a slot pointing at freed memory.

**A rewrite left out on purpose:** `x * 0 → 0`. It is correct algebra, but
it discards `x`, and `x` may contain a call with side effects. Doing it
soundly needs an effect analysis. MLIR solves the same problem with the
`Pure` trait: only side-effect-free ops can be dropped.

| Concept                  | This module              | LLVM                          | MLIR                                   |
| ------------------------ | ------------------------ | ----------------------------- | -------------------------------------- |
| The edge to rewrite      | `ExprPtr &` slot         | `Use &` (operand edge)        | `OpOperand &`                          |
| Replace everywhere       | assign to the slot       | `V->replaceAllUsesWith(New)`  | `rewriter.replaceOp(op, newValues)`    |
| Delete safely            | `unique_ptr` destruction | `I->eraseFromParent()`        | `rewriter.eraseOp(op)`                 |
| "Did I change anything?" | `bool Run(...)`          | `PreservedAnalyses` / `bool`  | `LogicalResult` from `matchAndRewrite` |
| Traversal                | hand-written recursion   | hand-written or `InstVisitor` | **the driver** (greedy or conversion)  |

That last row is the point of the workbench's planned module 4: in MLIR the
traversal belongs to the framework, and a pass only declares **patterns**.
Compare `TryFoldBinary` with nano-dsp's `ReluOp::canonicalize` on the
[Pattern rewrite](../03-transformations/pattern-rewrite.md) page.

## 🎤 Interview angle

The workbench README's own summary is worth saying out loud:

> After you write through an owning slot, every raw pointer into the old
> subtree is dangling. Do the replacement last, and never read `Bin` again.

And the soundness point: "Knowing which obvious rewrite is unsound (`x * 0`)
is more of the job than knowing the rewrites."

## ⚠️ Common confusion

- **`Slot = std::move(Bin->GetLhsSlot())` in one line is actually well
  defined**, because `unique_ptr` releases the source before deleting the
  old object. The module still writes it as two statements, so the code
  stays correct if it is ever reordered.
- **Post-order matters.** Visiting children first lets `(2*5) + (10-4)`
  collapse to `16` in one traversal, without a fixpoint loop.

## 🔗 Related

- [Ownership and arenas](ownership-and-arenas.md)
- [Pattern rewrite](../03-transformations/pattern-rewrite.md)
- [CSE and DCE](../03-transformations/cse-and-dce.md)

---

✅ Verified against: llvm-idioms-workbench `454c234` (built, tested and run
locally, including ASan/UBSan)
