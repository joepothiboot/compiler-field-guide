# Question Bank: C++ for Compilers 🧰

Answer out loud, then open the fold. Links go to the full explanation.

---

### 1. What does `std::move` actually do?

<details><summary>Answer</summary>

Nothing at runtime. It is a cast to an rvalue reference (`static_cast<T&&>`),
which makes overload resolution pick the move constructor or move
assignment. Those do the moving. `(void)std::move(b);` alone leaves `b`
unchanged: the mechanics repo has a test for exactly that.

→ [Ownership and arenas](../08-cpp-for-compilers/ownership-and-arenas.md)
</details>

### 2. After `b = std::move(a)` with `unique_ptr`, can you use `a`?

<details><summary>Answer</summary>

Yes. `unique_ptr`'s move is _specified_ to leave the source null, so `a` is an
empty but fully valid object. You can test it, assign to it or reset it. For
`std::string` and `std::vector`, the moved-from state is "valid but
unspecified": assign or clear them, but don't read the contents.
</details>

### 3. Why does LLVM avoid `shared_ptr` for IR?

<details><summary>Answer</summary>

IR graphs are full of cycles (loop back edges, def-use chains, parent
pointers), and reference counting cannot free a cycle: it leaks. It also
costs atomic increments and a control block, and it makes ownership
unreadable. LLVM uses `unique_ptr` for tree edges and context/arena ownership
with raw non-owning pointers for everything else.

→ [Ownership and arenas](../08-cpp-for-compilers/ownership-and-arenas.md) (the cycle-leak test)
</details>

### 4. What is an arena / context, and what is its failure mode?

<details><summary>Answer</summary>

One long-lived object (e.g. `MLIRContext`, `BumpPtrAllocator`) owns all nodes
and frees them together. Everyone else holds raw pointers. It makes
allocation cheap and ownership trivial. The failure mode: using a pointer
after the context is destroyed, i.e. a dangling `Operation *`.
</details>

### 5. Why can't a member function template be virtual?

<details><summary>Answer</summary>

A vtable is a fixed-size array of slots laid out when the class is compiled.
A template has an unbounded set of instantiations, some created later in
other translation units or plugins, so there is no way to assign stable
slots. The alternatives are double dispatch, CRTP static visitors, or a kind
tag with `switch`/`dyn_cast`.

→ [Virtual dispatch and CRTP](../08-cpp-for-compilers/virtual-dispatch-and-crtp.md)
</details>

### 6. What happens when a base class constructor calls a virtual function?

<details><summary>Answer</summary>

It calls the **base** version: during the base constructor, the object's
dynamic type is still the base (the vptr points at the base vtable). That
is why LLVM uses `Create()` factory functions instead of doing registration
work in constructors.
</details>

### 7. What is CRTP and why does LLVM use it?

<details><summary>Answer</summary>

`class Derived : Base<Derived>`: the base can `static_cast<Derived*>(this)`
and call derived methods directly, resolved at compile time. No vtable, and
calls inline, which matters for IR walks that run millions of times.
Examples: `llvm::InstVisitor`, `PassInfoMixin`, and every MLIR op class
(`mlir::Op<ConcreteOp, Traits...>`). Costs: no heterogeneous containers,
and code size grows per instantiation.
</details>

### 8. How do `isa<>`, `cast<>` and `dyn_cast<>` work without RTTI?

<details><summary>Answer</summary>

Each base stores a kind enum. Each subclass has
`static bool classof(const Base*)`, an equality check for a leaf or a range
check (`First <= k <= Last`) for an abstract base. `isa` calls `classof`,
`dyn_cast` returns the `static_cast` or null, and `cast` asserts and then
`static_cast`s. The cost is one load and one or two compares, which inline.

→ [LLVM-style RTTI](../08-cpp-for-compilers/llvm-style-rtti.md)
</details>

### 9. `cast<>` vs `dyn_cast<>`: when do you use which?

<details><summary>Answer</summary>

`cast` is an **assertion**: you already know the type. It never returns null,
and in release builds it is an unchecked `static_cast`, so a wrong `cast` is
UB. `dyn_cast` is a **query**: null means "not that type". Both assert on a
null _input_. Use `dyn_cast_if_present` when null is legitimate.
`if (cast<T>(p))` is a code smell.
</details>

### 10. Why does LLVM build with `-fno-rtti` and `-fno-exceptions`?

<details><summary>Answer</summary>

RTTI emits `type_info` and name strings for every polymorphic class (binary
size), and `dynamic_cast` is slow and opaque. Exceptions add unwind tables
and hidden control flow. Errors use `assert` (bugs), `llvm::Error` /
`Expected<T>` (recoverable) and, in MLIR, `LogicalResult`.

→ [LLVM coding conventions](../08-cpp-for-compilers/llvm-coding-conventions.md)
</details>

### 11. Why `SmallVector`? How do you choose `N`?

<details><summary>Answer</summary>

Compilers create huge numbers of tiny lists (operands, successors, uses),
mostly 1–4 elements. Inline storage avoids a heap allocation for each. My
workbench demo shows a 2-element list costing 0 allocations and the 5th push
costing exactly 1 buffer. Choose `N` by measuring the real distribution: a
bigger `N` bloats every object (`CallExprAST` is 88 bytes there).

→ [SmallVector and ArrayRef](../08-cpp-for-compilers/small-vector-and-arrayref.md)
</details>

### 12. Why is moving a `SmallVector` not always O(1)?

<details><summary>Answer</summary>

If its elements are on the heap, a move steals one pointer. If they are
inline, they are part of the source object, so each element must be moved
individually. That is why APIs take `SmallVectorImpl<T>&` or `ArrayRef<T>`,
not `SmallVector` by value.
</details>

### 13. What is an intrusive list and why does LLVM store instructions in one?

<details><summary>Answer</summary>

The `prev`/`next` links live inside each element. Insert, erase and move are
O(1) with zero allocations, an element can remove itself from just its own
pointer (`eraseFromParent`), and other pointers stay valid. My mechanics test
shows 4 allocations (intrusive) vs 17 (`std::list<Inst*>` + an index map)
for 4 instructions.

→ [Intrusive lists](../08-cpp-for-compilers/intrusive-lists.md)
</details>

### 14. How do you erase elements while iterating an LLVM list?

<details><summary>Answer</summary>

Take the current element, advance the iterator **first**, then erase:
`Inst *cur = &*it; ++it; if (...) cur->eraseFromParent();`. With an
intrusive list, only iterators to the erased element are invalidated.
</details>

### 15. `std::variant` vs a class hierarchy for an AST?

<details><summary>Answer</summary>

Variant: a closed set, and `std::visit` fails to compile if a case is
missing (exhaustiveness). Every node is the size of the largest alternative,
and the set cannot be extended. Hierarchy + kind tag: open to extension
(MLIR dialects), stable addresses, varied node sizes, but a forgotten case is
a silent bug. Frontend AST → variant is attractive. Extensible IR → hierarchy.

→ [Variant ASTs](../08-cpp-for-compilers/variant-asts.md)
</details>

### 16. Why does a pass that folds the root take `unique_ptr<Node>&`, not `Node*`?

<details><summary>Answer</summary>

Folding `1 + 2` at the root replaces the root object itself. Only the owning
edge (the caller's `unique_ptr`) can be pointed at the new node. It is the
same distinction as `Value*` vs `Use&` in LLVM: to replace what an edge
points to, you need the edge.

→ [Owning slots and safe rewrites](../08-cpp-for-compilers/owning-slots-and-safe-rewrites.md)
</details>

### 17. How do you rewrite `bar + 0 → bar` without a double free or use-after-free?

<details><summary>Answer</summary>

Move the child out of the parent first (`Hoisted = std::move(Bin->LhsSlot())`,
which nulls the parent's edge), then assign into the parent's slot
(`Slot = std::move(Hoisted)`). This destroys the parent, which no longer owns
`bar`. After that, every raw pointer into the old subtree is dangling. My
test proves the surviving node has the same address (it was moved, not
copied), with balanced allocations, under ASan.
</details>

### 18. Why is `x * 0 → 0` not always a valid rewrite?

<details><summary>Answer</summary>

It discards `x`. If `x` contains a call with side effects (I/O, a store), the
rewrite changes behavior. It is only valid when `x` is side-effect-free, which
is what MLIR's `Pure` trait certifies.
</details>

### 19. What's an RAII guard and where does MLIR use one?

<details><summary>Answer</summary>

An object whose destructor restores state, so restoration happens on every
exit path. `OpBuilder::InsertionGuard` saves the builder's insertion point and
restores it at scope end. Guards are non-copyable so they cannot restore twice.
</details>

### 20. What does "a raw pointer in LLVM" mean?

<details><summary>Answer</summary>

A non-owning observer. Owning raw pointers are a bug in LLVM style. Ownership
is always a `unique_ptr`, a container, or a context.
</details>
