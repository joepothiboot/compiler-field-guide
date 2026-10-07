# Linking and Object Files 🧷

> **One line:** The compiler turns each source file into an **object file**
> (machine code plus a list of symbols it defines and needs). The **linker**
> combines object files, resolves every needed symbol to a definition and
> patches the addresses (**relocations**).

## 🖼️ Picture

```
 link_main.c ──clang -c──► link_main.o          link_lib.c ──clang -c──► link_lib.o
                           ┌────────────────┐                            ┌────────────────┐
                           │ T _main        │ defines                    │ T _square      │
                           │ U _square      │ needs  ───────────┐        │ S _call_count  │
                           │ U _call_count  │ needs  ─────────┐ │        └────────────────┘
                           │ U _printf      │ needs ─┐        │ │               ▲
                           └────────────────┘        │        └─┴── resolved ───┘
                                                     └── resolved from libSystem (libc)
                                    │
                                    ▼  ld
                              a.out (executable): every U resolved,
                              every relocation patched with a real address
```

## 🔧 In each tool

Real symbols (`llvm-nm`) for [samples/link_main.c](../samples/link_main.c)
and [samples/link_lib.c](../samples/link_lib.c):

```
link_main.o:                              link_lib.o:
                 U _call_count            0000000000000038 S _call_count
0000000000000000 T _main                  0000000000000000 T _square
                 U _printf
                 U _square
```

`T` = defined code (text), `S` = defined data, `U` = undefined (needed from
elsewhere). The `static` helper in `link_lib.c` does not appear at all: it
is file-private, and the compiler inlined it into `square`.

Linking only `link_main.o` fails, with a real error:

```
Undefined symbols for architecture arm64:
  "_call_count", referenced from:
      _main in link_main.o
  "_square", referenced from:
      _main in link_main.o
ld: symbol(s) not found for architecture arm64
```

Linking both works: `square(7) = 49, calls = 1`.

Relocations are the "holes" left for the linker (`llvm-objdump -d -r`, trimmed):

```
      10:  bl    0x10 <ltmp0+0x10>
           0000000000000010:  ARM64_RELOC_BRANCH26          _square      ← call target TBD
      14:  adrp  x8, 0x0 <ltmp0>
           0000000000000014:  ARM64_RELOC_GOT_LOAD_PAGE21   _call_count  ← address TBD
      2c:  bl    0x2c <ltmp0+0x2c>
           000000000000002c:  ARM64_RELOC_BRANCH26          _printf
```

The `bl 0x10` instruction currently branches to itself. The linker
overwrites its offset with the real location of `_square`.

| Concept           | Where it shows up in ML compilers                                                                         |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| Object file       | `mojo build --emit object`, `llc -filetype=obj`, CUDA `.cubin`                                            |
| Linking bitcode   | `llvm-link` merges `.bc` modules; used to link device libraries (libdevice) into GPU kernels              |
| Dynamic loading   | Triton and Inductor compile kernels to shared objects / cubins and load them at runtime                   |
| Symbol visibility | `static` / `private` functions can be inlined and deleted ([Inlining](../03-transformations/inlining.md)) |

## ⚠️ Common confusion

- **The leading underscore** (`_square`) is macOS's C symbol prefix. On
  Linux the symbol is just `square`.
- **"Undefined symbol" is a link error, not a compile error.** Each file
  compiled fine on its own. Only the combination was incomplete.
- **Static vs dynamic linking.** `printf` was resolved from a shared
  library (libSystem) at load time. `_square` was copied into the executable.

## 🔗 Related

- [ABI and calling conventions](abi-and-calling-conventions.md)
- [JIT vs AOT](jit-vs-aot.md)

---

✅ Verified against: Apple clang 21 + `ld` (macOS 27, arm64) · LLVM 23.1.1
tools (`llvm-nm`, `llvm-objdump`)
