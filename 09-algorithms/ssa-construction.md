# SSA Construction 🏗️

> **One line:** Converting a program with reassigned variables into SSA
> takes three steps: place **φ nodes** at the iterated dominance frontier of
> each variable's definitions, **rename** every definition and use by walking
> the dominator tree with a stack per variable, then **delete dead φs**. This
> is the Cytron et al. (1991) algorithm, and it is what LLVM's `mem2reg` does.

## 🖼️ Picture

```
 BEFORE (variables reassigned)          AFTER (SSA, real output of file 05)
 ─────────────────────────────          ───────────────────────────────────
 entry:  i = 0; s = 0                   entry:
         jmp header                       i_0 = const 0
 header: t = i < n                        s_0 = const 0
         br t, body, exit                 jmp header
 body:   s = s + i                      header:
         i = i + 1                        i_1 = phi [entry: i_0] [body: i_2]
         jmp header                       s_1 = phi [entry: s_0] [body: s_2]
 exit:   ret s                            t_1 = lt i_1 n_0
                                          br t_1, body, exit
 1. defSites: i → {entry, body}         body:
              s → {entry, body}           s_2 = add s_1 i_1
              t → {header}                i_2 = add i_1 1
 2. DF(body) = {header}                   jmp header
    → φ for i and s in header           exit:
    (a φ for t is placed too, then         ret s_1
     removed as dead: minimal → pruned)
```

## 🔧 In each tool

From [codebases/compiler-mechanics-cpp/05_ssa_construction.cpp](../codebases/compiler-mechanics-cpp/05_ssa_construction.cpp).

**Step 1: φ placement at the iterated dominance frontier.** A φ is itself a
definition, so it can require more φs further down:

```cpp
for (const auto &entry : defSites) {
  const std::string &var = entry.first;
  std::set<int> worklist = entry.second;
  std::set<int> placed;
  while (!worklist.empty()) {
    int b = *worklist.begin();
    worklist.erase(worklist.begin());
    for (int d : df[b]) {
      if (!placed.insert(d).second) continue;
      Phi phi; phi.var = var;
      f.blocks[d].phis.push_back(phi);
      if (!entry.second.count(d))
        worklist.insert(d);          // the φ is a new definition: iterate
    }
  }
}
```

**Step 2: renaming** with a stack of current names per variable, walking the
dominator tree:

```cpp
std::function<void(int)> rename = [&](int b) {
  std::vector<std::string> pushedHere;
  for (Phi &p : bb.phis) { p.dst = pushName(p.var); pushedHere.push_back(p.var); }
  for (Stmt &s : bb.stmts) {
    for (Operand &o : s.ops)
      if (!o.isConst) o.name = topName(o.name);     // uses read the CURRENT version
    std::string origDst = s.dst;
    s.dst = pushName(origDst);                       // the def creates the NEXT version
    pushedHere.push_back(origDst);
  }
  ...
  for (int s : successors(bb))                      // fill one φ operand per outgoing edge
    for (Phi &p : f.blocks[s].phis)
      p.args.emplace_back(b, topName(p.var));
  for (int child : domChildren[b]) rename(child);   // recurse down the DOMINATOR tree
  for (auto it = pushedHere.rbegin(); it != pushedHere.rend(); ++it)
    stacks[*it].pop_back();                         // leaving: restore outer versions
};
```

**Step 3: dead-φ elimination** (minimal → pruned SSA) repeats until
nothing changes, because deleting one φ can make another dead.

**The test that matters**: an interpreter runs the **original** and the
**SSA** form on several inputs and checks that they agree:

```cpp
for (long long n : {0LL, 1LL, 2LL, 5LL, 10LL, 37LL})
  CHECK_MSG(runOriginal(orig, n) == runSSA(form, n), "n=" + std::to_string(n));
CHECK(runSSA(form, 5) == 10);   // 0+1+2+3+4
```

The interpreter evaluates all φs of a block **simultaneously** on entry. A φ
must not see a sibling φ's new value: the classic "swap problem" that makes
naive φ elimination wrong.

The diamond test, real output:

```
diamond:
  entry:
    a_0 = const 1
    c_0 = lt a_0 b_0
    br c_0, then, else
  then:
    a_1 = add a_0 10
    jmp join
  else:
    a_2 = add a_0 20
    jmp join
  join:
    a_3 = phi [then: a_1] [else: a_2]
    r_0 = mul a_3 2
    ret r_0
```

| Real codebase | SSA construction                                                                                                                                                                       |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLVM          | `mem2reg` / SROA: `llvm/lib/Transforms/Utils/PromoteMemoryToRegister.cpp` (promotes `alloca`s, places φs with `IteratedDominanceFrontier.h`); `SSAUpdater.cpp` for incremental updates |
| MLIR          | Front ends usually emit SSA directly; `mlir/lib/Transforms/Mem2Reg.cpp` promotes memory slots to block arguments                                                                       |
| Clang → LLVM  | Emits `alloca`/`load`/`store` at `-O0` and relies on `mem2reg` (see [SSA](../01-foundations/ssa.md))                                                                                   |

## 🎤 Interview angle

- "Walk me through SSA construction." → dominators → dominance frontiers →
  φ at the iterated DF of the definition sites → rename via dominator-tree DFS
  with per-variable stacks → prune dead φs (or use liveness up front).
- "Why the _iterated_ frontier?" → a placed φ is a new definition and can
  need φs further along.
- "Minimal vs pruned SSA?" → minimal can place φs for variables dead at the
  join (the `t` temporary here). Pruned uses liveness to avoid them.
- "How do you get out of SSA?" → replace each φ with copies on the incoming
  edges, handling the swap/lost-copy problems (parallel copies).

## ⚠️ Common confusion

- **Rename order matters**: uses read the current name _before_ the
  definition pushes a new one. `s = s + i` reads `s_1` and defines `s_2`.
- **"undef" operands**: a variable not defined on some path gets an `undef`
  φ operand (LLVM `undef`/`poison`). The file checks none survive in its
  tests.

## 🔗 Related

- [SSA](../01-foundations/ssa.md)
- [Dominator computation](dominator-computation.md)
- [Dataflow analysis](dataflow-analysis.md)

---

✅ Verified against: compiler-mechanics-cpp `14818a3` (tests pass; output above
is real)
