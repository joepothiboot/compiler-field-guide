# Virtual Dispatch and CRTP 🔀

> **One line:** Virtual functions dispatch at runtime through a vtable, which
> is flexible and costs an indirect call. **CRTP** (the Curiously Recurring
> Template Pattern) dispatches at compile time: no vtable, calls inline.
> LLVM uses virtual dispatch at plugin boundaries and CRTP on hot paths.

## 🌉 From frontend

Virtual dispatch is like calling `obj.render()` on any component: the right
method is found at runtime. CRTP is like a build-time code generator that
writes the exact call for each component type, so nothing is looked up at
runtime. It is faster, but you can no longer put different types in one array.

## 🖼️ Picture

```
 VIRTUAL                                    CRTP
 ───────                                    ────
 struct TargetOp { virtual int latency(); } template <class Derived>
 struct MulOp : TargetOp { int latency()    struct ExprVisitor {
                      override {return 3;}}   int visit(const Expr &e) {
                                                switch (e.kind) {
 op->latency()                                  case Add: return self().visitAdd(...);
   │ load vptr → load slot → indirect call      ...
   ▼                                          Derived &self() {
 MulOp::latency                                 return *static_cast<Derived*>(this); }
                                            };
 + open set of types (plugins, backends)    struct CostVisitor : ExprVisitor<CostVisitor>
 + one container of mixed types             + direct call, inlines; no vtable (sizeof == 1)
 - indirect call, hard to inline            - no mixed-type containers; code per instantiation

 DELEGATION CHAIN (as in llvm::InstVisitor):
   visitAdd ──► visitBinary ──► visitDefault
   override at whatever level you care about; inherit the rest
```

## 🔧 In each tool

From [codebases/compiler-mechanics-cpp/02_polymorphism.cpp](../codebases/compiler-mechanics-cpp/02_polymorphism.cpp).

**The constructor trap.** A virtual call inside a base constructor resolves
to the **base** version, because the derived part doesn't exist yet:

```cpp
struct Base {
  std::string tagSeenInCtor;
  Base() { tagSeenInCtor = tag(); }          // vptr still points at Base's vtable
  virtual std::string tag() const { return "Base"; }
};
struct Derived : Base { std::string tag() const override { return "Derived"; } };

Derived der;
CHECK(der.tagSeenInCtor == "Base");          // the trap
CHECK(der.tag() == "Derived");               // after construction: normal dispatch
```

LLVM avoids doing real work in constructors, and uses factory functions
(`Foo::Create(...)`) instead.

**Why a member template can't be virtual.** A vtable is a fixed array of
slots laid out when the class is compiled. A template has an unbounded set
of instantiations, some created later in other translation units, so there
is no way to assign slots. Compilers choose one of three alternatives
instead:

| Option                             | Used by                                           | Tradeoff                                  |
| ---------------------------------- | ------------------------------------------------- | ----------------------------------------- |
| Double dispatch (`accept`/`visit`) | Closed, stable node sets                          | Adding a node type edits every visitor    |
| CRTP static visitor                | `llvm::InstVisitor`, `clang::RecursiveASTVisitor` | No vtable, inlines; code bloat            |
| Kind tag + `switch` / `dyn_cast`   | `mlir::TypeSwitch`, most LLVM passes              | See [LLVM-style RTTI](llvm-style-rtti.md) |

**CRTP visitor with delegation**, as in the file:

```cpp
template <typename Derived, typename ResultT = int>
class ExprVisitor {
public:
  ResultT visit(const Expr &e) {
    switch (e.kind) {
    case ExprKind::Const: return self().visitConst(static_cast<const ConstExpr &>(e));
    case ExprKind::Add:   return self().visitAdd(static_cast<const BinaryExpr &>(e));
    case ExprKind::Mul:   return self().visitMul(static_cast<const BinaryExpr &>(e));
    }
    return ResultT{};
  }
  ResultT visitAdd(const BinaryExpr &e) { return self().visitBinary(e); }   // default: delegate up
  ResultT visitBinary(const BinaryExpr &e) {
    return self().visit(*e.lhs) + self().visit(*e.rhs);
  }
  ResultT visitConst(const ConstExpr &) { return ResultT{}; }
protected:
  Derived &self() { return *static_cast<Derived *>(this); }    // the CRTP move
};

struct CostVisitor : ExprVisitor<CostVisitor> {                // override only 2 cases
  int visitAdd(const BinaryExpr &e) { return 1 + visitBinary(e); }
  int visitMul(const BinaryExpr &e) { return 3 + visitBinary(e); }
};
// (2*3)+4 → cost 4;  sizeof(CostVisitor) == 1  (no vptr)
```

**CRTP as a mixin** (like `llvm::PassInfoMixin`): the base supplies the loop,
the derived class supplies one hook:

```cpp
template <typename Derived>
class FunctionPassMixin {
public:
  bool runOnFunction(std::vector<int> &instructions) {
    bool changed = false;
    for (int &inst : instructions)
      changed |= static_cast<Derived *>(this)->runOnInstruction(inst);
    return changed;                    // LLVM's "did I change anything?" contract
  }
};
```

| Real codebase | Virtual                        | CRTP / static                                                                                                |
| ------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| LLVM          | `TargetMachine`, legacy `Pass` | `InstVisitor` (`llvm/include/llvm/IR/InstVisitor.h`), `PassInfoMixin` (`llvm/include/llvm/IR/PassManager.h`) |
| MLIR          | `Pass`, dialect interfaces     | `Op<ConcreteOp, Traits...>` (every op class is CRTP), `OpRewritePattern<T>`                                  |
| Mojo          | —                              | Traits + parameters: static by design ([Traits](../06-mojo/traits.md))                                       |

## 🎤 Interview angle

- "Why can't a template member be virtual?" → no fixed vtable slot for an
  unbounded set of instantiations.
- "Why does LLVM use CRTP so much?" → IR walks run millions of times per
  compile, and CRTP makes every visit a direct, inlinable call.
- "Every MLIR op is CRTP": `class ReluOp : public mlir::Op<ReluOp, ...traits>`,
  as in the TableGen output on the [ODS page](../02-ir-design/ods-and-tablegen.md).

## ⚠️ Common confusion

- **Virtual destructor.** Deleting through a base pointer without one is
  undefined behavior. Every polymorphic base needs `virtual ~Base() = default;`.
- **CRTP's `self()` cast is unchecked.** If you inherit from the wrong
  `Base<Other>`, the `static_cast` compiles and misbehaves.

## 🔗 Related

- [LLVM-style RTTI](llvm-style-rtti.md)
- [Traits (Mojo)](../06-mojo/traits.md)
- [Pass and pass manager](../03-transformations/pass-and-pass-manager.md)

---

✅ Verified against: compiler-mechanics-cpp `14818a3` (built and tested locally)
