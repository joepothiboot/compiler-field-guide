# Bundler Plugins vs Passes 🔌

> **One line:** A _pass_ is one transformation over the whole IR, and a
> _pipeline_ is an ordered list of passes. This is the same idea as a chain of
> bundler plugins or Babel plugins.

## 🌉 From frontend

In Vite or webpack, each plugin gets the module, changes it and passes it on.
The order matters: TypeScript has to be stripped before minification.
Compiler passes work the same way. The difference is that the compiler often
**repeats** some passes. Cleanup passes like canonicalize run many times,
because each lowering step leaves behind new things to simplify.

## 🖼️ Picture

```
 VITE                                    mlir-opt
 ────                                    ────────
 main.ts                                 input.mlir
   │                                        │
   ▼  plugin: esbuild (strip TS)            ▼  pass: --canonicalize
   ▼  plugin: react (JSX → calls)           ▼  pass: --convert-scf-to-cf
   ▼  plugin: terser (minify)               ▼  pass: --convert-to-llvm
   │                                        │
 bundle.js                               output.mlir ──mlir-translate──► .ll

 each plugin: module → module            each pass: IR → IR (same format in and out)
```

## 🔧 In each tool

| Concept                    | LLVM                              | MLIR                                    | Triton / Mojo                |
| -------------------------- | --------------------------------- | --------------------------------------- | ---------------------------- |
| Run passes by hand         | `opt -passes=mem2reg,instcombine` | `mlir-opt --canonicalize --cse`         | Internal, not user-facing    |
| Preset pipeline            | `-O0` … `-O3`                     | `--pass-pipeline="builtin.module(...)"` | Fixed by the compiler        |
| "Plugin API"               | New pass manager `PassInfoMixin`  | `OperationPass<>` + `RewritePattern`    | —                            |
| See the IR after each pass | `-print-after-all`                | `--mlir-print-ir-after-all`             | Triton: `MLIR_ENABLE_DUMP=1` |

Real example: a single `--canonicalize` pass on
[samples/max_or_zero.scf.mlir](../samples/max_or_zero.scf.mlir) spots that the
whole `if` / `else` is just "max of x and 0":

```mlir
// before
%r = scf.if %pos -> (i32) {
  scf.yield %x : i32
} else {
  scf.yield %zero : i32
}

// after  mlir-opt --canonicalize
%0 = arith.maxsi %arg0, %c0_i32 : i32
```

## ⚠️ Common confusion

- **Pass vs pattern.** In MLIR, a _pattern_ is a small local rewrite ("this
  op shape → that op shape"). A _pass_ is what drives many patterns over the
  whole IR, often repeating until nothing changes. A Babel plugin is closer
  to a pass. Each `visitor` method in it is closer to a pattern.
- **Order matters.** Running lowering passes out of order produces IR that
  mixes dialects the next pass does not understand. In `mlir-opt` this shows
  up as a "failed to legalize" error.

## 🔗 Related

- [Babel is a compiler](babel-is-a-compiler.md)
- [Dialect](../02-ir-design/dialect.md): what the conversion passes convert between
- [vizmlir](https://github.com/joepothiboot/vizmlir): shows the IR differences between passes

---

✅ Verified against: MLIR 23.1.1
