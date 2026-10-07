# def, struct and Argument Conventions 🔥

> **One line:** Mojo functions are declared with `def`, data types with
> `struct`, and every argument has a **convention** that says whether the
> function borrows it (`read`, the default), mutates the caller's value
> (`mut`), owns its own value (`var`) or initializes the caller's
> result (`out`).

## 🖼️ Picture

```
 caller's value  xs ──────────────┐
                                  │
 read   (default)   ──► callee sees xs, cannot change it       (no copy)
 mut                ──► callee changes xs, caller sees it      (no copy)
 var                ──► callee gets its OWN value:
                          consume(xs.copy())  → a copy, xs untouched
                          consume(xs^)        → xs is transferred; caller loses it
 out                ──► callee writes the caller's uninitialized result slot
```

## 🔧 In each tool

Real run of [samples/mojo_arguments.mojo](../samples/mojo_arguments.mojo)
(Mojo 1.1.0):

```mojo
def show(x: List[Int]):              # read: borrowed, immutable
def append_one(mut x: List[Int]):    # mut: caller sees the append
    x.append(1)
def consume(var x: List[Int]) -> Int:  # var: owned by this function
    x.append(99)
    return len(x)
def make_list(out result: List[Int]):  # out: initializes the result
    result = [7, 8, 9]

struct Counter(Movable):
    var count: Int
    def __init__(out self):          # constructors initialize `self` via `out`
        self.count = 0
    def bump(mut self):              # mutating method
        self.count += 1
    def get(self) -> Int:            # read-only method
        return self.count
```

```
  read: 3 items
after mut: 4
consume a copy: 5  original still: 4
consume by transfer: 5
out result: 3
counter: 2
```

Using `xs` after `consume(xs^)` is a compile error. Real message:

```
moved.mojo:7:14: error: use of uninitialized value 'xs'
    print(len(xs))
             ^
```

| Concept           | Mojo 1.1                      | C++                          | Rust                  |
| ----------------- | ----------------------------- | ---------------------------- | --------------------- |
| Borrow, read-only | `x: T` (read)                 | `const T&`                   | `&T`                  |
| Borrow, mutable   | `mut x: T`                    | `T&`                         | `&mut T`              |
| Owned value       | `var x: T`                    | `T` by value (+ `std::move`) | `T` by value          |
| Transfer at call  | `f(x^)`                       | `f(std::move(x))`            | `f(x)` (move default) |
| Explicit copy     | `x.copy()`                    | copy constructor (implicit)  | `x.clone()`           |
| Constructor       | `def __init__(out self, ...)` | constructor                  | `fn new() -> Self`    |

## ⚠️ Common confusion

- **`fn` is gone in Mojo 1.1.** Older docs and blog posts use `fn` for
  strict functions and `def` for Python-like ones. In 1.1, `def` is the
  only keyword. Real compiler message: `error: 'fn' has been removed; use
'def' instead`. A `def` only raises errors if it says `raises`.
- **Copies are explicit for non-trivial types.** `List` is not implicitly
  copied. You write `.copy()` or transfer with `^`. Accidental deep copies
  are a common performance bug in other languages.
- **`out` is not a return statement.** It names the storage the caller
  provides, so large results are built in place with no copy.

## 🔗 Related

- [Ownership and transfer](ownership-and-transfer.md)
- [Ownership and arenas (C++)](../08-cpp-for-compilers/ownership-and-arenas.md)
- [Traits](traits.md)

---

✅ Verified against: Mojo 1.1.0 (run locally)
