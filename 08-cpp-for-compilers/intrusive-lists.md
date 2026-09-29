# Intrusive Lists 🔗

> **One line:** In an intrusive list, the `prev`/`next` links live **inside
> each element**. Insert, remove and move are O(1) with zero allocations,
> and an element can unlink itself knowing only its own pointer. This is how
> LLVM stores instructions in blocks and blocks in functions.

## 🌉 From frontend

The DOM is an intrusive tree: every node knows its own `parentNode`,
`previousSibling` and `nextSibling`, so `el.remove()` or
`ref.before(el)` work from the element alone. A `std::list<Node*>` is more
like an array of IDs: to remove an element you first need to find where it
is stored.

## 🖼️ Picture

```
 std::list<Inst*>                          intrusive list (llvm::ilist)
 ────────────────                          ────────────────────────────
 [list node]─►[list node]─►[list node]     sentinel ⇄ [Inst: prev|next|data] ⇄ [Inst: ...] ⇄ sentinel
     │            │            │                 (circular: end() == &sentinel,
     ▼            ▼            ▼                  no null checks, no special cases)
   Inst         Inst         Inst
 2 allocations per element, and to         1 allocation per element (the Inst itself)
 erase by Inst* you need a side map        i->eraseFromParent(), i->moveBefore(j):
 Inst* → iterator (more memory, a hash)    O(1), no search, no allocation

 cost: an element can be in only ONE list per hook, and the list never copies
```

## 🔧 In each tool

From [codebases/compiler-mechanics-cpp/04_ir_data_structures.cpp](../codebases/compiler-mechanics-cpp/04_ir_data_structures.cpp):

```cpp
struct ListHook {                     // lives INSIDE every element
  ListHook *prev = nullptr;
  ListHook *next = nullptr;
};

class Inst : public ListHook {
public:
  void eraseFromParent();             // unlink + destroy: needs no container
  void moveBefore(Inst *other);       // O(1) splice, even into another block
  ...
};

void Inst::moveBefore(Inst *other) {
  hookUnlink(this);
  hookInsertBefore(other, this);
  parent_ = other->parent_;           // ownership follows list membership
}
```

The test moves an instruction into another block and erases one, checking
the allocation count before and after (`CHECK(g_allocations == before)`).
Real output of the comparison with `std::list`:

```
       allocations for 4 instructions: intrusive=4, std::list<Inst*>+index=17
```

The safe erase-while-iterating pattern, used throughout LLVM:

```cpp
for (auto it = list.begin(); it != list.end();) {
  Inst *cur = &*it;
  ++it;                               // advance FIRST
  if (cur->opcode() == "add")
    cur->eraseFromParent();           // now safe: `it` no longer points at cur
}
```

| Real codebase | Where                                                                                                                                                              |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| LLVM          | `llvm/include/llvm/ADT/ilist.h`, `simple_ilist.h`; `BasicBlock` holds its `Instruction`s, `Function` its `BasicBlock`s; `I->eraseFromParent()`, `I->moveBefore(J)` |
| MLIR          | `Block` holds an intrusive list of `Operation`; `Region` of `Block`; `op->erase()`, `op->moveBefore(other)`                                                        |
| Linux kernel  | `struct list_head` embedded in structs: the same idea in C                                                                                                         |

## 🎤 Interview angle

- "Why does LLVM use intrusive lists for instructions?" → passes constantly
  delete, move and insert instructions while holding raw pointers to others.
  Intrusive lists make each edit O(1) and allocation-free, and they keep all
  other pointers and iterators valid.
- "What's the catch?" → one list per hook, the list does not own copies, and
  the element must know about the list type.

## ⚠️ Common confusion

- **Iterator invalidation is local.** Erasing an element invalidates only
  iterators to _that_ element, unlike `std::vector`, where an erase shifts
  everything after it.
- **`size()` can be O(n).** The teaching version walks the list, and
  `llvm::simple_ilist` does not store a size. Don't call it in a loop.

## 🔗 Related

- [Ownership and arenas](ownership-and-arenas.md)
- [Variant ASTs](variant-asts.md)
- [Basic block and CFG](../01-foundations/basic-block.md)

---

✅ Verified against: compiler-mechanics-cpp `14818a3` (built and tested
locally, including ASan/UBSan)
