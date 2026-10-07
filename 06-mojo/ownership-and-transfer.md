# Ownership and Transfer `^` 📦➡️

> **One line:** Every Mojo value has exactly one owner. The owner decides when
> it is destroyed, which is **right after its last use** ("as soon as
> possible"). `x^` transfers ownership; a copy only happens when you ask for
> one.

## 🖼️ Picture

```
 lifecycle methods on a struct
 ─────────────────────────────
 __init__(out self, ...)              construct
 __init__(out self, *, copy: Self)    copy constructor    ← x.copy()
 __init__(out self, *, deinit move: Self)  move constructor ← when storage must change
 __deinit__(deinit self)              destructor          ← after the LAST use

 var a = Buffer("a")   ──┐
 keep(a^)                │ ownership handed to keep(); `a` is now uninitialized
                         └► keep's parameter is destroyed when keep() finishes
```

## 🔧 In each tool

Real output of [samples/mojo_ownership.mojo](../samples/mojo_ownership.mojo),
with a print in every lifecycle method:

```
1) create
  init    a
2) explicit copy
  copy    a -> a'
3) transfer with ^
  keep() now owns a
  del     a                      ← destroyed at the end of keep(), not of main()
4) transfer into a List: the value must move into the list's storage
  init    c
  move    c                      ← a real move: the bytes changed address
5) end of main: values are destroyed right after their last use
  last use of a' and c
  del     c
  del     a'
```

Two things this run shows:

- **Transfer is not always a move.** `keep(a^)` handed the value over
  _without_ calling the move constructor: the compiler passed the same
  storage. The move constructor only ran when the value had to relocate
  into the list's buffer.
- **Destruction is as early as possible.** `a` died inside `keep()`, and the
  last two values died immediately after the `print` that used them.

The lifecycle methods, as written in the sample:

```mojo
struct Buffer(Copyable, Movable):
    var name: String
    var data: List[Float32]

    def __init__(out self, *, copy: Self):           # deep copy
        self.name = copy.name + "'"
        self.data = copy.data.copy()

    def __init__(out self, *, deinit move: Self):    # steal the fields
        self.name = move.name^
        self.data = move.data^

    def __deinit__(deinit self):                     # destructor
        print("  del    ", self.name)
```

| Idea               | Mojo                   | C++                                                     | Rust          |
| ------------------ | ---------------------- | ------------------------------------------------------- | ------------- |
| Destroy time       | After last use (ASAP)  | End of scope (RAII)                                     | End of scope  |
| Transfer           | `x^`                   | `std::move(x)` (just a cast)                            | implicit move |
| Use after transfer | Compile error          | Legal: "valid but unspecified" (for `unique_ptr`: null) | Compile error |
| Copy               | `.copy()` / `Copyable` | implicit copy constructor                               | `.clone()`    |

## ⚠️ Common confusion

- **Older names.** Pre-1.0 Mojo code and posts use `__copyinit__`,
  `__moveinit__`, `__del__` and `owned`. Use the forms on this page instead.
  Real Mojo 1.1 warnings from this sample's first draft: `'__del__' is deprecated; use '__deinit__'` and
  `'deinit' argument 'take' does not define a move constructor; declare it
as '__init__(*, deinit move)'`.
- **ASAP destruction vs RAII.** C++ destroys at the closing brace, so a
  lock guard lives to the end of the scope. In Mojo a value you never use
  again may be destroyed earlier than you expect. Keep guards alive
  explicitly (e.g. use them with `with`).
- **Compare with C++ moved-from objects.** In C++, `std::move` only casts,
  and the moved-from object still exists. See
  [Ownership and arenas](../08-cpp-for-compilers/ownership-and-arenas.md).

## 🔗 Related

- [def, struct and argument conventions](def-struct-and-argument-conventions.md)
- [Owning slots and safe rewrites (C++)](../08-cpp-for-compilers/owning-slots-and-safe-rewrites.md)
- [Bufferization](../03-transformations/bufferization.md): in-place vs copy, compiler side

---

✅ Verified against: Mojo 1.1.0 (run locally)
