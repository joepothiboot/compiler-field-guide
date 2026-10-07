# Register Allocation 🗃️

> **One line:** SSA gives you unlimited _virtual_ registers. The CPU has a
> few dozen _physical_ ones. Register allocation maps each virtual register
> to a physical one, so that two values alive at the same time never share
> a register. Values that don't fit are **spilled** to the stack.

## 🖼️ Picture

```
 live ranges (from liveness analysis)        interference graph
 ────────────────────────────────────        ──────────────────
   0  1  2  3  4  5  6  7                       a ─── b
 a ████████████                                 │   ╱
 b    ██████                                    │  ╱
 c       ███████████                            c ─── d
 d                ██████
                                              edge = "alive at the same time"
 at point 2, a, b and c are all alive          need 3 colors (registers);
 → 3 registers needed                          with 2 → one value spills

 color = physical register:  a→x0  b→x1  c→x2  d→x0 (a is dead by then: reuse)
```

## 🔧 In each tool

**LLVM, before vs after allocation.** Real `llc -O2` MIR for
[samples/isel.ll](../samples/isel.ll):

```
# after instruction selection (-stop-after=finalize-isel): virtual registers
%0:gpr64 = COPY $x0
%3:gpr64 = ADDXrr %0, %1
%4:gpr64 = MADDXrrr killed %3, %2, $xzr
%5:gpr64 = SUBSXrr killed %4, %0, implicit-def dead $nzcv
$x0 = COPY %5

# after register allocation (-stop-after=virtregrewriter): physical registers
renamable $x8 = ADDXrr renamable $x0, killed renamable $x1
renamable $x9 = SUBXrr $xzr, killed renamable $x0
renamable $x0 = MADDXrrr killed renamable $x8, killed renamable $x2, killed renamable $x9
```

- `%0` … `%5` became `$x0`, `$x8`, `$x9`. The COPYs from argument
  registers disappeared: the allocator chose the argument register itself
  (_coalescing_).
- `killed` marks a value's last use. After that, the register is free to reuse.
- The MIR header flips from `isSSA: true` / `noVRegs: false` to
  `isSSA: false` / `noVRegs: true`.

**By hand.** [Graph-coloring register allocation](../09-algorithms/graph-coloring-register-allocation.md)
walks through the Chaitin–Briggs allocator in
[codebases/compiler-mechanics-cpp/07_register_allocation.cpp](../codebases/compiler-mechanics-cpp/07_register_allocation.cpp),
including its real test output
`K=3 -> 3 colors, 0 spills; K=2 -> 1 spills` for the live ranges pictured above.

| Tool / target | Allocator                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| LLVM (CPU)    | **Greedy** allocator (default at `-O1+`): priority queue of live ranges with live-range splitting; **Fast** allocator at `-O0` |
| NVIDIA        | PTX has unlimited virtual registers (`%r<15>`); **`ptxas`** does the real allocation into SASS registers                       |
| Mojo, Triton  | Through LLVM (CPU) and then `ptxas` (NVIDIA)                                                                                   |
| Textbook      | Chaitin–Briggs graph coloring; linear scan (used by many JITs for speed)                                                       |

## ⚠️ Common confusion

- **Spilling is not failure**, it is a cost: a spilled value costs a store
  and loads. Allocators weigh spill cost by how often a value is used, with
  loop depth counted heavily, so loop variables stay in registers.
- **Register pressure on GPUs is special.** More registers per thread means
  fewer threads fit on the SM ([Occupancy](../04-hardware/occupancy.md)).
  GPU compilers therefore trade spills against occupancy.
- **Precolored registers.** Some values must be in specific registers
  (arguments in `x0`–`x7`, the return value in `x0`). They are fixed nodes
  in the graph. See the [ABI](abi-and-calling-conventions.md).

## 🔗 Related

- [Graph-coloring register allocation (by hand)](../09-algorithms/graph-coloring-register-allocation.md)
- [Dataflow analysis](../09-algorithms/dataflow-analysis.md): liveness feeds the allocator
- [Instruction selection](instruction-selection.md)

---

✅ Verified against: LLVM 23.1.1 (`llc`, AArch64) · compiler-mechanics-cpp `14818a3`
