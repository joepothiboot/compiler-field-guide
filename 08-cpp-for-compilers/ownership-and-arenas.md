# Ownership and Arenas 🔑

> **One line:** Compiler C++ has no garbage collector and almost no reference
> counting. Every object is owned in one of two ways: by exactly one
> `std::unique_ptr` (a tree edge), or by a long-lived **context/arena** that
> owns everything and hands out raw, **non-owning** pointers.

## 🖼️ Picture

```
 A) UNIQUE_PTR TREE (ASTs)                 B) CONTEXT ARENA (LLVM / MLIR IR)
 ─────────────────────────                 ─────────────────────────────────
   Call 'foo'  ── owns ──┐                  MLIRContext / LLVMContext
     │ unique_ptr        │                  ┌──────────────────────────────┐
     ▼                   ▼                  │ owns every Type, Attribute,  │
   Binary '+'        Binary '*'             │ uniqued constant ...         │
     │    │            │    │               └──────┬───────────┬───────────┘
   Num 1  Num 2      Num 3  Call 'bar'             │ raw ptr   │ raw ptr
                                                   ▼           ▼
 destroy the root → the whole tree dies     passes, builders, analyses hold
 exactly once; moving a subtree is a        Operation*, Type ... never freeing
 visible std::move                          them; the context frees all at once

 RAW POINTER in LLVM code  =  "I am looking at it", NEVER "I own it"
```

## 🔧 In each tool

**1. `std::move` is only a cast.** From
[codebases/compiler-mechanics-cpp/01_memory_ownership.cpp](../codebases/compiler-mechanics-cpp/01_memory_ownership.cpp):

```cpp
InstPtr a = createInstruction("add");
Instruction *raw = a.get();         // non-owning observer

InstPtr b = std::move(a);           // the MOVE happens in unique_ptr's move-assignment
CHECK(a.get() == nullptr);          // specified: the source is left empty (not "invalid")
CHECK(b.get() == raw);              // the heap object itself never moved

a = createInstruction("sub");       // legal: `a` is an empty-but-alive unique_ptr

(void)std::move(b);                 // does NOTHING observable: it is just a cast
CHECK(b && b->opcode() == "add");
```

**2. Sink parameters.** Passing `unique_ptr` by value means the callee
consumes it, which is how LLVM hands a `Module` to a JIT:

```cpp
std::string consumeInstruction(InstPtr inst);  // caller must write std::move(x)
std::string name = consumeInstruction(std::move(b));
CHECK(b == nullptr);                            // caller provably has nothing left
```

**3. The context arena.** Pointers stay valid across `vector` reallocation,
because the `unique_ptr` _targets_ never move:

```cpp
class IRContext {
public:
  Instruction *create(std::string opcode) {
    arena_.push_back(std::make_unique<Instruction>(std::move(opcode)));
    return arena_.back().get();   // stable address
  }
private:
  std::vector<InstPtr> arena_;
};
// 1000 more creates force reallocation; i0 is still valid.
// When the context dies, all 1001 instructions die at once.
```

**4. RAII guard**, modeled on `mlir::OpBuilder::InsertionGuard`, which
restores the builder position even on early return:

```cpp
{
  Builder::InsertionGuard guard(b);   // saves the insertion point
  b.setInsertionPoint(&loopBody);
  b.createOp("phi");
}                                     // destructor restores it, unconditionally
CHECK(b.insertionPoint() == &entry);
```

**5. Why not `shared_ptr`.** IR is full of cycles (loops, def-use, parent
links), and reference counting cannot free a cycle. The file builds a
two-block loop with strong back-edges and shows that **both blocks stay
alive after every local reference is gone**. It then fixes the leak with a
`weak_ptr` back-edge.

**6. Every AST edge a `unique_ptr`.** From the workbench,
[module1-ast-ownership](../codebases/llvm-idioms-workbench/module1-ast-ownership/):
the demo counts every allocation with a replaced global `operator new`. Real
output:

```
== process totals ==

  allocations:   13
  deallocations: 13
  bytes:         432
```

Balanced: every node freed exactly once, with no `delete` written anywhere.

| Real codebase | Ownership model                                                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM          | `LLVMContext` owns types and constants; `Module` owns functions; functions own blocks own instructions (intrusive lists). `parseIRFile` returns `std::unique_ptr<Module>` |
| MLIR          | `MLIRContext` owns (uniques) types and attributes; operations are owned by their parent block; APIs hand out `Operation *`                                                |
| Clang         | AST nodes are bump-allocated in `ASTContext` and never individually freed                                                                                                 |
| Mojo          | Single ownership built into the language: `var`, `^`, ASAP destruction ([Ownership and transfer](../06-mojo/ownership-and-transfer.md))                                   |

## 🎤 Interview angle

- "What does `std::move` do?" → nothing at runtime: it is a cast to an
  rvalue reference. The move happens in the move constructor or assignment
  it selects.
- "Is a moved-from `unique_ptr` usable?" → yes, it is specified to be null.
  Moved-from `std::string`/`std::vector` are "valid but unspecified":
  assign or clear them, don't read them.
- "Why does LLVM avoid `shared_ptr` for IR?" → cycles leak, atomic
  refcount costs, and ownership becomes unreadable.

## ⚠️ Common confusion

- **A raw pointer is not a smell here.** In LLVM, `Instruction *` means an
  observer. What would be a smell is an _owning_ raw pointer, or a
  `new` without a clear owner.
- **Arena pointers die with the arena.** Using an `Operation *` after its
  context is destroyed is the MLIR version of a dangling pointer. The
  mechanics file shows exactly that moment.

## 🔗 Related

- [SmallVector and ArrayRef](small-vector-and-arrayref.md)
- [Owning slots and safe rewrites](owning-slots-and-safe-rewrites.md)
- [Ownership and transfer (Mojo)](../06-mojo/ownership-and-transfer.md)

---

✅ Verified against: codebases built and tested locally (Apple clang 21,
C++17), including ASan/UBSan
