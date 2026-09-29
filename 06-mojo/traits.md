# Traits 🧬

> **One line:** A trait is a named set of methods a type promises to have,
> like an interface. Generic functions constrain their type parameters with
> traits (`[T: Shape]`) and are compiled separately for each concrete type.
> There is no runtime dispatch.

## 🌉 From frontend

A TypeScript `interface Shape { area(): number }` plus a generic
`function describe<T extends Shape>(s: T)`. The difference: TypeScript
erases `T` and calls `s.area()` dynamically at runtime. Mojo compiles
`describe[Square]` and `describe[Circle]` as two separate, fully inlinable
functions (_monomorphization_).

## 🖼️ Picture

```
 trait Shape                         describe[T: Shape](s: T)
   def area(self) -> Float64              │  compiled per T used:
   def name(self) -> String               ├── describe[Square]  → calls Square.area directly
        ▲              ▲                  └── describe[Circle]  → calls Circle.area directly
        │ conforms     │ conforms
 struct Square   struct Circle       no vtable, no indirect call; each copy can inline

 built-in traits used everywhere:
   Copyable      has a copy constructor (.copy())
   Movable       can be relocated (move constructor)
   Writable      can be printed / formatted
   Comparable, Hashable, Sized (len) ...
```

## 🔧 In each tool

Real run of [samples/mojo_traits.mojo](../samples/mojo_traits.mojo):

```mojo
trait Shape:
    def area(self) -> Float64:
        ...
    def name(self) -> String:
        ...

@fieldwise_init                      # generates __init__(out self, side: Float64)
struct Square(Copyable, Shape):
    var side: Float64
    def area(self) -> Float64:
        return self.side * self.side
    def name(self) -> String:
        return "square"

def describe[T: Shape](s: T):        # compiled once per T
    print(" ", s.name(), "area =", s.area())

def total_area[T: Shape & Copyable](items: List[T]) -> Float64:   # trait composition
    var total = 0.0
    for item in items:
        total += item.area()
    return total
```

```
  square area = 4.0
  circle area = 3.141592653589793
  total area of squares = 14.0
```

| Language   | Interface mechanism                                               | Dispatch                                                    |
| ---------- | ----------------------------------------------------------------- | ----------------------------------------------------------- |
| TypeScript | `interface`, structural                                           | Runtime (erased generics)                                   |
| C++        | Virtual base class / C++20 concepts / CRTP                        | Virtual: runtime; templates + CRTP: compile time            |
| Rust       | `trait` + generics / `dyn Trait`                                  | Static by default, dynamic with `dyn`                       |
| Mojo       | `trait` + parameters `[T: Trait]`                                 | Static (specialized per type)                               |
| MLIR       | Op **interfaces** and **traits** (`Pure`, `InferTypeOpInterface`) | Interfaces: runtime lookup; traits: compile-time properties |

## ⚠️ Common confusion

- **Mojo traits vs MLIR traits.** Same word, different things. An MLIR
  trait is a property attached to an op definition (`Pure`,
  `SameOperandsAndResultType`). A Mojo trait is a language interface.
- **Specialization has a cost.** Each concrete type gets its own compiled
  copy, which increases binary size and compile time. It is the same
  tradeoff as C++ templates and CRTP
  (see [Virtual dispatch and CRTP](../08-cpp-for-compilers/virtual-dispatch-and-crtp.md)).
- **`...` in a trait method** means "no body here; conforming types must
  provide it".

## 🔗 Related

- [Parameters vs arguments](parameters-vs-arguments.md)
- [Virtual dispatch and CRTP](../08-cpp-for-compilers/virtual-dispatch-and-crtp.md)
- [Operation](../02-ir-design/operation.md): MLIR traits on ops

---

✅ Verified against: Mojo 1.1.0 (run locally)
