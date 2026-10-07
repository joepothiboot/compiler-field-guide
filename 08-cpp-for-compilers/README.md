# C++ for Compilers 🧰

The C++ techniques LLVM and MLIR are written with, explained with runnable code from [codebases/](../codebases/).

| Page | In one line |
| ---- | ----------- |
| [Ownership and Arenas 🔑](ownership-and-arenas.md) | Compiler C++ has no garbage collector and almost no reference counting. |
| [SmallVector and ArrayRef 📏](small-vector-and-arrayref.md) | `SmallVector<T, N>` stores its first `N` elements inside the object and only heap-allocates when it grows past `N`. `ArrayRef<T>` is a non-owning (pointer, length) view used to pass any contiguous list across an API without copying. |
| [Virtual Dispatch and CRTP 🔀](virtual-dispatch-and-crtp.md) | Virtual functions dispatch at runtime through a vtable, which is flexible and costs an indirect call. |
| [LLVM-Style RTTI: isa, cast, dyn_cast 🏷️](llvm-style-rtti.md) | LLVM builds with `-fno-rtti`, so there is no `dynamic_cast`. |
| [Intrusive Lists 🔗](intrusive-lists.md) | In an intrusive list, the `prev`/`next` links live inside each element. |
| [Variant ASTs 🧾](variant-asts.md) | Instead of a class hierarchy, an AST node can be a `std::variant` over a closed set of alternatives. `std::visit` then forces every visitor to handle every alternative at compile time. |
| [Owning Slots and Safe Rewrites ✂️](owning-slots-and-safe-rewrites.md) | A transformation that replaces a node must write through the owning edge (`std::unique_ptr<Node>&`, a "slot"), not just the node pointer. |
| [LLVM Coding Conventions 📐](llvm-coding-conventions.md) | LLVM and MLIR code follows a specific C++ dialect: C++17, no exceptions, no RTTI, heavy use of assertions, its own container library (ADT), and naming rules that differ from most C++ style guides. |

New pages start from [../_templates/term.md](../_templates/term.md).
