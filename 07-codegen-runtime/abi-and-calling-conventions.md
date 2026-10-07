# ABI and Calling Conventions 📞

> **One line:** The ABI (application binary interface) is the contract that
> lets separately compiled code call each other: which registers hold the
> arguments and return value, how structs are passed, and which registers a
> function must preserve.

## 🖼️ Picture

```
 AArch64 (Apple M-series, Linux ARM)          x86-64 (System V: Linux, macOS Intel)
 ───────────────────────────────────          ─────────────────────────────────────
 integer args   x0, x1, ..., x7               rdi, rsi, rdx, rcx, r8, r9
 float args     d0/s0 ... d7/s7               xmm0 ... xmm7
 return         x0 (x1)  /  d0/s0             rax (rdx)  /  xmm0
 small struct   in registers                  in registers
 large struct   by pointer (x0 = address)     by copy on the stack
```

## 🔧 In each tool

Real `clang -O1` output for [samples/abi.c](../samples/abi.c) on both targets:

```c
long add3(long x, long y, long z) { return x + y + z; }
double scale(double x, int n) { return x * n; }
struct Pair make_pair(long a, long b) { struct Pair p = {a, b}; return p; }
long sum_big(struct Big big) { return big.v[0] + big.v[3]; }   // struct Big { long v[4]; }
long call_add3(void) { return add3(1, 2, 3) + 10; }
```

```
            AArch64 (this M2)                 x86-64 (--target=x86_64-unknown-linux-gnu)
add3:       add  x8, x1, x0                   leaq (%rdi,%rsi), %rax
            add  x0, x8, x2                   addq %rdx, %rax
            ret                               retq

scale:      scvtf d1, w0      ; int→double    cvtsi2sd %edi, %xmm1
            fmul  d0, d0, d1                  mulsd    %xmm1, %xmm0
            ret                               retq
            (x in d0, n in w0: separate       (x in xmm0, n in edi)
             register files)

make_pair:  ret                               movq %rsi, %rdx
            (a, b already in x0, x1 =         movq %rdi, %rax
             the return registers!)           retq

sum_big:    ldr x8, [x0]                      movq 32(%rsp), %rax
            ldr x9, [x0, #24]                 addq 8(%rsp), %rax
            add x0, x9, x8                    retq
            (32-byte struct passed BY         (passed by COPY on the stack)
             POINTER in x0)

call_add3:  mov w0, #16                       movl $16, %eax
            ret                               retq
            (the call was inlined and folded: 1+2+3+10 = 16, so there's no call left)
```

`make_pair` is the most instructive: on AArch64 the function body is a bare
`ret`, because the arguments are already sitting in the return registers.

| Where the ABI shows up    | Why it matters                                                                                                           |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Register allocation       | Argument and return registers are _precolored_ nodes                                                                     |
| Inlining                  | Removes the ABI cost entirely (`call_add3` above)                                                                        |
| Mojo ↔ C / Python interop | Mojo calls C through `external_call` and must follow the C ABI                                                           |
| GPU kernels               | PTX `.param` space: kernel args are loaded with `ld.param` (see the [vector add PTX](../rosetta/vector-add-in-5-irs.md)) |
| MLIR → LLVM               | `memref` arguments expand into several scalars (pointer, offset, sizes, strides) at the function boundary                |

## ⚠️ Common confusion

- **The ABI depends on OS and CPU.** Windows x64 uses different registers
  (`rcx, rdx, r8, r9`) than Linux/macOS x86-64. Apple's AArch64 ABI differs
  from Linux AArch64 in small ways (e.g. variadic arguments).
- **Callee-saved vs caller-saved.** Some registers must be preserved by
  the callee (AArch64 `x19`–`x28`), others may be clobbered. That affects
  where the allocator puts long-lived values across calls.
- **C++ name mangling is part of the ABI too**, which is why interop uses
  `extern "C"` (as Inductor's generated `extern "C" void kernel(...)` does).

## 🔗 Related

- [Register allocation](register-allocation.md)
- [Linking and object files](linking-and-object-files.md)
- [Inlining](../03-transformations/inlining.md)

---

✅ Verified against: Clang 23.1.1 (AArch64 macOS and x86-64 Linux targets)
