# Use-Def Chains 🔗

> **One line:** Every SSA value knows its one **definition** and the list of
> all its **uses**. Passes follow these links instead of searching the code.

## 🌉 From frontend

It is like "Find all references" and "Go to definition" in VS Code, but
built into the data structure and always up to date. In the compiler,
"rename this value everywhere" is one call (`replaceAllUsesWith`), because
each value already holds a list of its users.

## 🖼️ Picture

```
                 def                    uses
                 ───                    ────
 %c0 = arith.constant 0  ──────┬──►  arith.cmpi   (operand 1)
                               └──►  scf.yield    (in the else branch)

 %arg0 (function argument) ────┬──►  arith.cmpi   (operand 0)
                               └──►  scf.yield    (in the then branch)

 %1 = arith.cmpi ...  ─────────────► scf.if       (the condition)
 %2 = scf.if ...      ─────────────► func.return

 "use-def": from a use, jump to its single definition   (always 1)
 "def-use": from a definition, list all its uses        (0 or more)
 0 uses  →  the value is dead, and DCE can delete it (if it has no side effects)
```

## 🔧 In each tool

MLIR can print the users of every value as comments. Real output of
`mlir-opt --mlir-print-value-users` on
[samples/max_or_zero.scf.mlir](../samples/max_or_zero.scf.mlir):

```mlir
func.func @max_or_zero(%arg0: i32) -> i32 {
  // %arg0 is used by %4, %1
  %c0_i32 = arith.constant 0 : i32 // users: %4, %1
  %1 = arith.cmpi sgt, %arg0, %c0_i32 : i32 // user: %2
  %2 = scf.if %1 -> (i32) {
    scf.yield %arg0 : i32 // id: %4
  } else {
    scf.yield %c0_i32 : i32 // id: %4
  } // user: %3
  return %2 : i32 // id: %3
}
```

The `%4`, `%3` ids are labels the printer gives to ops that have no result
(like `scf.yield` and `return`), so they can appear in "used by" lists.
Both yields got `%4` here. This is how the printer labels them; it does
not mean they are the same op.

| Tool   | API                                                                             |
| ------ | ------------------------------------------------------------------------------- |
| LLVM   | `Value::users()`, `Value::uses()`, `replaceAllUsesWith(V)`                      |
| MLIR   | `Value::getUsers()`, `Value::getUses()`, `replaceAllUsesWith(V)`, `use_empty()` |
| Triton | Its passes are MLIR passes, so they use the MLIR API above                      |
| Mojo   | Not exposed to users; its internal MLIR passes use the same API                 |

## ⚠️ Common confusion

- **One def, many uses, always.** If you ever think a value has two
  definitions, it is really two values joined by a φ / block argument.
- **"Uses" counts operand slots, not ops.** `arith.addi %x, %x` is one
  user with two uses of `%x`.
- **Memory is not tracked this way.** A `store` to a pointer and a later
  `load` from it are not linked by use-def chains. Knowing whether they
  touch the same memory needs a separate _alias analysis_.

## 🔗 Related

- [SSA](ssa.md)
- [CSE and DCE](../03-transformations/cse-and-dce.md): both rely on use lists
- [Pattern rewrite](../03-transformations/pattern-rewrite.md): `replaceOp` updates all uses

---

✅ Verified against: MLIR 23.1.1
