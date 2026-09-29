# LLVM-Style RTTI: isa, cast, dyn_cast 🏷️

> **One line:** LLVM builds with `-fno-rtti`, so there is no `dynamic_cast`.
> Instead, each base class stores a **kind** field, each subclass has a static
> `classof()` predicate, and the templates `isa<>`, `cast<>` and `dyn_cast<>`
> are built on top. A downcast becomes one load and one or two integer compares.

## 🌉 From frontend

TypeScript's discriminated unions: `type Shape = { kind: "circle", r } |
{ kind: "square", s }`, then `if (shape.kind === "circle")` narrows the type.
LLVM does the same thing by hand in C++: a `kind` field in the base class,
and `dyn_cast<Circle>(shape)` is the narrowing check.

## 🖼️ Picture

```
 enum ValueKind {                          classof = equality (leaf) or RANGE (base)
   VK_Argument,
   VK_ConstantInt,                         Instruction::classof(v):
   VK_Instruction_Begin,  ─┐                 Begin <= v->kind <= End     ← 2 compares,
   VK_BinaryOp_Begin = ... ├ Instruction     covers every instruction      any hierarchy depth
   VK_Add = ...           ─┤ ┐ BinaryOp
   VK_Mul,                 │ ┘               AddInst::classof(v):
   VK_Load,                │                   v->kind == VK_Add          ← 1 compare
   VK_Call,               ─┘
   VK_Instruction_End = VK_Call,           the ORDER of the enum is load-bearing:
 };                                        subclasses must be contiguous in the range

 isa<T>(p)      bool          "is it a T?"                     asserts p != null
 cast<T>(p)     T*, never null "I KNOW it is a T"              asserts in debug; free static_cast in release
 dyn_cast<T>(p) T* or null    "is it a T? if so, give it to me" asserts p != null
 *_if_present / _or_null      same, but null input → false / null
```

## 🔧 In each tool

**The mechanism**, from
[codebases/compiler-mechanics-cpp/03_rtti_isa_dyncast.cpp](../codebases/compiler-mechanics-cpp/03_rtti_isa_dyncast.cpp):

```cpp
class Instruction : public Value {
public:
  static bool classof(const Value *v) {
    return v->getKind() >= VK_Instruction_Begin &&
           v->getKind() <= VK_Instruction_End;       // the range trick
  }
};

template <typename To, typename From>
To *dyn_cast(From *val) {
  return isa<To>(val) ? static_cast<To *>(val) : nullptr;   // no runtime type graph
}
```

The typical consumer, a peephole constant folder. About 80% of LLVM
transform code has this shape:

```cpp
bool tryConstantFold(const Value *v, long long &out) {
  const auto *bin = dyn_cast<BinaryOp>(v);            // range check
  if (!bin)
    return false;
  const auto *lhs = dyn_cast<ConstantInt>(bin->lhs());
  const auto *rhs = dyn_cast<ConstantInt>(bin->rhs());
  if (!lhs || !rhs)
    return false;
  if (isa<AddInst>(bin))                               // leaf check
    out = lhs->value() + rhs->value();
  else if (isa<MulInst>(bin))
    out = lhs->value() * rhs->value();
  else
    return false;
  return true;
}
```

The build compiles this file twice, once with `-fno-rtti`, to prove the
casts do not need language RTTI. Both pass: `8/8 tests passed`,
including the `03_no_rtti` entry.

**The contracts**, from the workbench
[module2-custom-rtti](../codebases/llvm-idioms-workbench/module2-custom-rtti/)
(`include/Casting.h`), which also preserves `const`. Real demo output:

```
== isa<> / cast<> / dyn_cast<> contracts ==

  isa<CallExprAST>(root)   = true
  isa<NumberExprAST>(root) = false
  dyn_cast<NumberExprAST>(root) = nullptr  <- the query form, null is a normal answer
  cast<CallExprAST>(root)->GetCallee() = foo  <- never null; asserts if wrong

== const-ness survives the cast ==

  dyn_cast<CallExprAST>(const ExprAST *)   -> const CallExprAST *
  dyn_cast<NumberExprAST>(ExprAST *)       -> NumberExprAST *
  (both checked by static_assert at compile time)

== cost ==

  sizeof(ExprAST)       = 16 bytes (vtable pointer + Kind)
  a dyn_cast<> is one load of Kind plus one compare;
  dynamic_cast walks a runtime type graph and may call strcmp.
```

The const-propagating return type (LLVM calls it `cast_retty`):

```cpp
template <typename To, typename From> struct CastReturnType { using type = To *; };
template <typename To, typename From> struct CastReturnType<To, const From> {
  using type = const To *;          // const in → const out: casts can't launder const away
};
```

| Real codebase | Where                                                                                                                                                       |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM          | `llvm/include/llvm/Support/Casting.h`; kind ranges in `llvm/include/llvm/IR/Value.def` and `Instruction.def`                                                |
| MLIR          | `isa<AddIOp>(op)`, `dyn_cast<AddIOp>(op)` on `Operation *`; `llvm::TypeSwitch` for multi-way dispatch; types and attributes use `TypeID` instead of an enum |
| Clang         | Same idiom over `Stmt`, `Decl`, `Type` (with no virtual functions at all)                                                                                   |

## 🎤 Interview angle

- "Why not `dynamic_cast`?" → `-fno-rtti` removes `type_info` data for every
  polymorphic class (binary size); `dynamic_cast` is an opaque library call
  that may compare mangled-name strings across shared libraries; `classof`
  inlines to a compare; range checks answer "is it any binary op?" in two
  compares; and it works on classes with no vtable.
- "`cast` vs `dyn_cast`?" → `cast` is an **assertion** (never null; UB in
  release if wrong). `dyn_cast` is a **query** (null is a normal answer).
  `if (cast<T>(p))` is always a code smell.
- "What does `dyn_cast` do with null?" → it asserts. Use
  `dyn_cast_if_present` (formerly `dyn_cast_or_null`) when null is legitimate.

## ⚠️ Common confusion

- **The enum order is the correctness.** Add a subclass outside its base's
  range, and `classof` silently gives wrong answers. The compiler cannot
  catch this.
- **`-fno-rtti` does not mean no virtual functions.** LLVM's `Value` still
  has virtual methods. Only `typeid` and `dynamic_cast` are disabled.

## 🔗 Related

- [Virtual dispatch and CRTP](virtual-dispatch-and-crtp.md)
- [Variant ASTs](variant-asts.md): the closed-union alternative
- [Pattern rewrite](../03-transformations/pattern-rewrite.md): `getDefiningOp<ReluOp>()` is a `dyn_cast`

---

✅ Verified against: compiler-mechanics-cpp `14818a3` · llvm-idioms-workbench
`454c234` (built, tested and run locally, with and without RTTI)
