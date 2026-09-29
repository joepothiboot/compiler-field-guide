# Instruction Selection 🎯

> **One line:** Instruction selection (isel) turns target-independent IR
> operations (`add`, `mul`, `fmul`) into real machine instructions of one
> CPU or GPU, often combining several IR operations into one instruction
> (`mul` + `add` → `madd`).

## 🌉 From frontend

Like a CSS preprocessor emitting vendor-specific output: the same
`display: flex` becomes whatever each browser needs. Instruction selection
picks, for each target, the instructions that implement your IR, and
looks for combined forms the target offers, the way autoprefixer knows
which shorthand a browser supports.

## 🖼️ Picture

```
 LLVM IR (target-independent)          AArch64 machine instructions
 ────────────────────────────          ────────────────────────────
 %s = add i64 %a, %b        ─────►     ADDXrr   (64-bit add, register-register)
 %m = mul i64 %s, %c        ─┐
                             ├───►     MADDXrrr (multiply-add: one instruction)
 %r = sub i64 %m, %a        ─┘         or SUB after it, depending on later passes

 %m = fmul contract float %x, %y ─┐
 %r = fadd contract float %m, %z ─┴──► FMADDSrrr (fused multiply-add, single precision)
                                       "contract" permits fusing: the result is rounded once

 after isel the code is "Machine IR" (MIR): real opcodes, but still VIRTUAL
 registers (%0, %1 ...) — register allocation comes next
```

## 🔧 In each tool

Real output of `llc -O2 -stop-after=finalize-isel` on
[samples/isel.ll](../samples/isel.ll) (target `arm64-apple-macosx`):

```
bb.0 (%ir-block.0):
  liveins: $x0, $x1, $x2
  %2:gpr64 = COPY $x2                           ← arguments arrive in x0..x2 (the ABI)
  %1:gpr64 = COPY $x1
  %0:gpr64 = COPY $x0
  %3:gpr64 = ADDXrr %0, %1                      ← a + b
  %4:gpr64 = MADDXrrr killed %3, %2, $xzr       ← (a+b) * c + 0   (xzr = zero register)
  %5:gpr64 = SUBSXrr killed %4, %0, implicit-def dead $nzcv
  $x0 = COPY %5                                 ← result goes back in x0
  RET_ReallyLR implicit $x0
```

```
%3:fpr32 = contract nofpexcept FMADDSrrr %0, %1, %2, implicit $fpcr
```

The final assembly (`llc -O2`):

```asm
_expr:
	add	x8, x0, x1
	neg	x9, x0
	madd	x0, x8, x2, x9       ; x0 = x8 * x2 + x9   → (a+b)*c + (-a)
	ret
_madd:
	fmadd	s0, s0, s1, s2
	ret
```

Notice that the final code differs from the isel output: a later machine
pass (the _machine combiner_) rewrote `mul` + `sub` into `neg` + `madd`,
which is shorter on this CPU. Isel is one stage of several.

| Tool   | Instruction selection                                                                                                                         |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM   | **SelectionDAG** (default on most targets) or **GlobalISel** (AArch64 at `-O0`, and growing); patterns written in TableGen `.td` target files |
| MLIR   | No isel of its own: lowers to the `llvm` / `nvvm` dialects and lets LLVM select                                                               |
| Triton | Through LLVM's NVPTX/AMDGPU backends; `tt.dot` is lowered to `mma` intrinsics _before_ LLVM                                                   |
| Mojo   | Through LLVM backends (CPU, NVPTX, AMDGPU, Apple)                                                                                             |
| NVIDIA | Two stages: LLVM selects **PTX** instructions; `ptxas` selects real **SASS**                                                                  |

## ⚠️ Common confusion

- **"contract" matters.** Without the `contract` (or `fast`) flag, LLVM
  may not fuse `fmul` + `fadd` into `fmadd`, because the fused version rounds
  once instead of twice and can give a slightly different result.
- **MIR is still SSA** right after isel (`isSSA: true` in the dump), with
  virtual registers. After register allocation it no longer is
  (`isSSA: false`, `noVRegs: true`).
- **`$xzr`** is AArch64's zero register: reads give 0, writes are
  discarded. Isel uses it to express `mul` as `madd ..., 0`.

## 🔗 Related

- [Register allocation](register-allocation.md)
- [Legalization](../02-ir-design/legalization.md)
- [ODS and TableGen](../02-ir-design/ods-and-tablegen.md): TableGen also describes targets

---

✅ Verified against: LLVM 23.1.1 (`llc`, AArch64)
