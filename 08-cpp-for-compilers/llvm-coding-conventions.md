# LLVM Coding Conventions 📐

> **One line:** LLVM and MLIR code follows a specific C++ dialect: C++17,
> no exceptions, no RTTI, heavy use of assertions, its own container
> library (ADT), and naming rules that differ from most C++ style guides.
> Knowing it makes both reading and contributing much faster.

## 🌉 From frontend

It is like joining a team with a strict ESLint and Prettier config and its
own utility library: nothing about the language is new, but the house
rules decide what "idiomatic" looks like, and reviewers enforce them.

## 🖼️ Picture

```
 LANGUAGE                    C++17  (no concepts, ranges, coroutines as the baseline)
 COMPILER FLAGS              -fno-exceptions  -fno-rtti
 ERROR HANDLING              assert(cond && "message")      programmer errors (debug builds)
                             llvm::Error / Expected<T>      recoverable errors (must be handled)
                             LogicalResult / FailureOr<T>   MLIR: success() / failure()
                             report_fatal_error             unrecoverable
 CONTAINERS (ADT)            SmallVector, ArrayRef, DenseMap, StringRef, ilist, ...
 CASTING                     isa<> / cast<> / dyn_cast<>    (never dynamic_cast)
 OWNERSHIP                   unique_ptr edges + context arenas; raw pointer = observer
```

## 🔧 In each tool

**Naming** (LLVM coding standards):

| Kind                      | LLVM style                       | Example                             |
| ------------------------- | -------------------------------- | ----------------------------------- |
| Types, classes            | `UpperCamelCase`                 | `BinaryExprAST`, `PassManager`      |
| Variables, members        | `UpperCamelCase`                 | `NumFolded`, `Stmts`                |
| Functions (LLVM)          | `lowerCamelCase`                 | `eraseFromParent()`, `getOperand()` |
| Functions (MLIR)          | `lowerCamelCase`                 | `matchAndRewrite`, `getDefiningOp`  |
| Enumerators               | `UpperCamelCase`, often prefixed | `VK_Add`, `NK_Number`               |
| STL-compatible containers | STL spelling                     | `push_back`, `size`, `begin`        |

The workbench follows LLVM's style but uses `UpperCamelCase` for its own
functions (`GetLhsSlot()`, `Run()`), and keeps STL spelling for `SmallVector`
methods, as its module 1 README explains. Match the surrounding code in the
project you are in.

**Headers**: every LLVM header starts with the banner
`//===- File.h - Description ---------------------------------*- C++ -*-===//`,
which the workbench copies (`//===- Casting.h - Minimal llvm/Support/Casting.h --===//`).

**Assertions**: always with a message, inside the condition:

```cpp
assert(Val && "cast<> used on a null pointer");
assert(isa<To>(Val) && "cast<> argument of incompatible type!");
```

The workbench's CMake builds with `-fno-exceptions -fno-rtti -Wall -Wextra`
so the compiler enforces the conventions. The mechanics repo compiles its
RTTI file with and without `-fno-rtti`.

**ADT cheat sheet**:

| Need                             | Use                                                         | Instead of              |
| -------------------------------- | ----------------------------------------------------------- | ----------------------- |
| Short list, usually ≤ N items    | `SmallVector<T, N>`                                         | `std::vector<T>`        |
| Pass a list without copying      | `ArrayRef<T>` / `MutableArrayRef<T>`                        | `const std::vector<T>&` |
| Pass a string without copying    | `StringRef`                                                 | `const std::string&`    |
| Hash map with pointer / int keys | `DenseMap<K, V>`                                            | `std::unordered_map`    |
| Small set of pointers            | `SmallPtrSet<T*, N>`                                        | `std::set<T*>`          |
| Build a string                   | `Twine` (for concatenation) / `raw_string_ostream`          | `std::string +`         |
| Print                            | `llvm::outs()`, `llvm::errs()`, `LLVM_DEBUG(dbgs() << ...)` | `std::cout`             |
| Optional value                   | `std::optional<T>`                                          | sentinel values         |

## 🎤 Interview angle

- "Why no exceptions?" → code size, predictable control flow, and the
  ability to build and link with `-fno-exceptions` everywhere. Errors are
  values (`Expected<T>`, `LogicalResult`) or assertions.
- "What's the difference between `assert` and `llvm::Error`?" → `assert` is
  for bugs, compiled out in release. `Error` is for conditions the program
  must handle, like a malformed input file, and it asserts if you forget to
  check it.
- "Which C++ standard?" → C++17 as the baseline, so write C++17 in
  interviews for LLVM roles.

## ⚠️ Common confusion

- **Release builds drop asserts** (`-DNDEBUG`). Code that relies on an
  assertion's side effects breaks in release. And `cast<>` becomes an
  unchecked `static_cast`.
- **MLIR and LLVM differ slightly**: MLIR uses `LogicalResult` heavily and
  has its own `FailureOr<T>`. Both use `lowerCamelCase` for functions.

## 🔗 Related

- [LLVM-style RTTI](llvm-style-rtti.md)
- [SmallVector and ArrayRef](small-vector-and-arrayref.md)
- [LLVM and MLIR codebase tour](../real-world/llvm-and-mlir-tour.md)

---

✅ Verified against: LLVM coding standards (llvm.org/docs/CodingStandards) as
reflected in the workbench and mechanics codebases
