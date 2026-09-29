# SmallVector and ArrayRef 📏

> **One line:** `SmallVector<T, N>` stores its first `N` elements **inside the
> object** and only heap-allocates when it grows past `N`. `ArrayRef<T>` is
> a non-owning (pointer, length) view used to pass any contiguous list
> across an API without copying.

## 🌉 From frontend

Most operand lists in a compiler are tiny (1 to 4 items), like most React
`children` arrays. Allocating a heap array for each one is like making a
network request for every 2-item list. `SmallVector` keeps small lists
inline. `ArrayRef` is like passing a `TypedArray.subarray()` view instead of
copying the data.

## 🖼️ Picture

```
 std::vector<T>                     SmallVector<T, 4>
 ┌──────────────┐                   ┌─────────────────────────────────────┐
 │ begin ───────┼──► heap [a b]     │ Begin ─┐  Size  Capacity            │
 │ size, cap    │    (1 malloc      │        ▼                            │
 └──────────────┘     even for 1)   │ [ a | b | _ | _ ]  ← inline buffer  │
                                    └─────────────────────────────────────┘
                                     0 mallocs for ≤ 4 elements

 5th push_back ─► Grow(): allocate 8 on the heap, move elements, Begin → heap
                  (from then on it behaves exactly like std::vector)

 ArrayRef<T>:  { const T *Data; size_t Length }   ← a view; owns nothing
```

## 🔧 In each tool

From the workbench,
[module1-ast-ownership](../codebases/llvm-idioms-workbench/module1-ast-ownership/)
(`include/SmallVector.h`, about 200 lines, instrumented with a counting
`operator new`). Real demo output:

```
== foo(1 + 2, 3 * bar) ==

  [heap] 2-element argument list (inline capacity 4): 0 allocations, 0 bytes
  storage is inline, size 2, capacity 4

  sizeof(CallExprAST) = 88 bytes (argument storage included)
  sizeof(ExprList)    = 56 bytes (3 words + 4 inline unique_ptrs)

== outgrowing the inline capacity ==

  [heap] pushing 4 elements (fits inline): 4 allocations, 64 bytes
  storage is inline (4 allocations above are the nodes themselves)
  [heap] pushing the 5th element (spills): 2 allocations, 80 bytes
  storage is heap, capacity grew to 8 (1 node + 1 buffer = 2 allocations above)
```

The spill path (`Grow`), from the same header:

```cpp
void Grow(size_t MinCapacity) {
  size_t NewCapacity = Capacity * 2;
  if (NewCapacity < MinCapacity)
    NewCapacity = MinCapacity;
  // Raw allocation: elements are constructed by hand, so not `new T[]`.
  T *NewBegin = static_cast<T *>(::operator new(NewCapacity * sizeof(T)));
  for (size_t I = 0; I != Size; ++I)
    new (NewBegin + I) T(std::move(Begin[I]));   // placement-new + move
  DestroyRange(Begin, Begin + Size);
  if (!IsSmall())
    ::operator delete(Begin);                     // never free the inline buffer
  Begin = NewBegin;
  Capacity = NewCapacity;
}
// storage: alignas(T) char Buffer[sizeof(T) * N];
```

**The subtle part**: moving a `SmallVector` is not always cheap. If the data
is on the heap, a move steals one pointer. If it is inline, every element
must be moved, because the storage is part of the source object. That is why
LLVM passes `SmallVectorImpl<T>&` or `ArrayRef<T>` across API boundaries,
never a `SmallVector` by value.

| Real codebase | Where                                                                                                        |
| ------------- | ------------------------------------------------------------------------------------------------------------ |
| LLVM          | `llvm/include/llvm/ADT/SmallVector.h` (`SmallVector`, `SmallVectorImpl`), `llvm/include/llvm/ADT/ArrayRef.h` |
| MLIR          | `ValueRange`, `TypeRange`, `OperandRange`: views over operand storage, same idea as `ArrayRef`               |
| Mojo          | `Span` (a non-owning view) in `std.collections`; `List` for owned growable storage                           |
| C++20         | `std::span` is the standard `ArrayRef`                                                                       |

## 🎤 Interview angle

- "Why `SmallVector`?" → compilers create millions of tiny lists (operands,
  successors, uses), and their size distribution is heavily skewed to 1–4.
  Inline storage removes a `malloc`/`free` and a cache miss for each.
- "How do you pick `N`?" → by measuring. Too big and every node bloats (the
  demo's `CallExprAST` is already 88 bytes). Too small and you pay the
  allocation anyway.
- "Why take `ArrayRef` as a parameter?" → one signature accepts a
  `SmallVector`, a `std::vector`, a C array or `{a, b, c}`, with no copy.

## ⚠️ Common confusion

- **Don't use `SmallVector` everywhere.** The workbench's `PassManager`
  deliberately uses `std::vector` for its pass list: it is built once, is not
  on a hot path, and inline storage would only make the object bigger.
- **An `ArrayRef` must not outlive what it points to.** Returning an
  `ArrayRef` to a local vector is a dangling view.

## 🔗 Related

- [Ownership and arenas](ownership-and-arenas.md)
- [Intrusive lists](intrusive-lists.md)
- [Use-def chains](../01-foundations/use-def-chains.md): the lists these containers hold

---

✅ Verified against: llvm-idioms-workbench `454c234` (built and run locally)
