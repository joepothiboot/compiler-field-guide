# Vector Add in 5 IRs 🪨

> **One program, `c[i] = a[i] + b[i]`, shown at each level of the stack.**
> Use this page to connect terms from the other chapters.

## 🖼️ The two ways to split the work

```
 CPU / SIMD style (Mojo, MLIR loops)        GPU style (Triton, PTX)
 ─────────────────────────────────         ────────────────────────
 one thread walks the array,                many threads at once, each
 `width` elements per step                  handles its own slice

 a: [■■■■|■■■■|■■■■|■■]                     a: [■■■■|■■■■|■■■■|■■··]
     └┬─┘ └┬─┘ └┬─┘ └┤                          └┬─┘ └┬─┘ └┬─┘ └┬─┘
    step1 step2 step3 tail                     pid0  pid1  pid2  pid3
    (SIMD, 4 lanes)   (scalar)                 (BLOCK=4; pid3 masks the
                                                 2 out-of-range slots ··)
```

---

## 1️⃣ Triton: tile-level Python

Not run locally, because this machine has no NVIDIA GPU. The code follows
the pattern of Triton's official vector-add tutorial.

```python
@triton.jit
def add_kernel(x_ptr, y_ptr, out_ptr, n, BLOCK: tl.constexpr):
    pid = tl.program_id(axis=0)                 # which block am I?
    offs = pid * BLOCK + tl.arange(0, BLOCK)    # my BLOCK indices, as one vector
    mask = offs < n                             # turn off out-of-range slots
    x = tl.load(x_ptr + offs, mask=mask)
    y = tl.load(y_ptr + offs, mask=mask)
    tl.store(out_ptr + offs, x + y, mask=mask)
```

**What to notice:** there is no loop and no thread index. You write code
for a **whole block (tile)** at once, and Triton decides how to spread it
over the GPU's threads. That is the main idea in Triton.

## 2️⃣ Mojo: SIMD on CPU

[samples/vadd.mojo](../samples/vadd.mojo). Ran with Mojo 1.1.0, and
`simd_width_of[DType.float32]()` returned `4` on this Apple Silicon machine.

```mojo
def vadd(a: List[Float32], b: List[Float32], mut c: List[Float32]):
    comptime width = simd_width_of[DType.float32]()
    var n = len(a)
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()
    var i = 0
    while i + width <= n:  # SIMD body: `width` lanes per step
        pc.unsafe_store(i, pa.unsafe_load[width=width](i) + pb.unsafe_load[width=width](i))
        i += width
    while i < n:  # scalar tail for the leftovers
        pc[unsafe_offset=i] = pa[unsafe_offset=i] + pb[unsafe_offset=i]
        i += 1
```

**What to notice:** `comptime width` is known **at compile time**, so
`unsafe_load[width=width]` compiles to a single vector load instruction. The
square brackets `[...]` hold compile-time parameters. The parentheses
`(...)` hold runtime arguments.

## 3️⃣ MLIR: loops over memory

[samples/vadd.mlir](../samples/vadd.mlir), written by hand in upstream
dialects and checked with `mlir-opt`:

```mlir
func.func @vadd(%a: memref<?xf32>, %b: memref<?xf32>, %c: memref<?xf32>) {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %n = memref.dim %a, %c0 : memref<?xf32>
  scf.for %i = %c0 to %n step %c1 {
    %x = memref.load %a[%i] : memref<?xf32>
    %y = memref.load %b[%i] : memref<?xf32>
    %s = arith.addf %x, %y : f32
    memref.store %s, %c[%i] : memref<?xf32>
  }
  return
}
```

**What to notice:** four dialects appear at once (`func`, `arith`, `memref`,
`scf`). `memref<?xf32>` means "a buffer of f32 whose length is only known at
runtime". Passes such as vectorization could rewrite this into the SIMD form
that the Mojo version uses.

## 4️⃣ LLVM IR: one GPU thread's view

[samples/vadd_gpu.ll](../samples/vadd_gpu.ll), written by hand. This is
roughly the level Triton reaches after its own dialects:

```llvm
define ptx_kernel void @vadd(ptr %a, ptr %b, ptr %c, i32 %n) {
entry:
  %bid = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()   ; block index
  %bdim = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()   ; threads per block
  %tid = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()     ; thread index in block
  %base = mul i32 %bid, %bdim
  %i = add i32 %base, %tid                             ; my global index
  %inb = icmp slt i32 %i, %n
  br i1 %inb, label %body, label %exit                 ; the "mask", as a branch

body:
  %idx = sext i32 %i to i64
  %pa = getelementptr inbounds float, ptr %a, i64 %idx
  %pb = getelementptr inbounds float, ptr %b, i64 %idx
  %pc = getelementptr inbounds float, ptr %c, i64 %idx
  %x = load float, ptr %pa
  %y = load float, ptr %pb
  %s = fadd float %x, %y
  store float %s, ptr %pc
  br label %exit

exit:
  ret void
}
```

**What to notice:** at this level the tile is gone. Each thread handles
**one** element, and its index is `blockIdx * blockDim + threadIdx`. Triton's
`mask=` has become an ordinary `if` branch.

## 5️⃣ PTX: NVIDIA's virtual assembly

Real output of `llc -mcpu=sm_80 samples/vadd_gpu.ll`:

```
.visible .entry vadd(
	.param .u64 .ptr .align 1 vadd_param_0,
	.param .u64 .ptr .align 1 vadd_param_1,
	.param .u64 .ptr .align 1 vadd_param_2,
	.param .u32 vadd_param_3
)
{
	...
	mov.u32 	%r2, %ctaid.x;
	mov.u32 	%r3, %ntid.x;
	mov.u32 	%r4, %tid.x;
	mad.lo.s32 	%r5, %r2, %r3, %r4;        // i = ctaid*ntid + tid in one instruction
	setp.ge.s32 	%p1, %r5, %r1;          // p1 = (i >= n)
	@%p1 bra 	$L__BB0_2;                   // if p1, skip to exit
	mul.wide.s32 	%rd10, %r5, 4;          // byte offset = i * sizeof(float)
	...
	ld.global.b32 	%r6, [%rd1];
	ld.global.b32 	%r7, [%rd2];
	add.rn.f32 	%r8, %r6, %r7;            // .rn = round to nearest
	st.global.b32 	[%rd3], %r8;
$L__BB0_2:
	ret;
}
```

**What to notice:** `.entry` marks a kernel the CPU can launch. `ld.global`
reads from GPU global memory. `mad.lo` is one multiply-add instruction. PTX
is still not what the GPU runs: NVIDIA's `ptxas` turns it into SASS machine
code.

---

## 🔁 The same idea at each level

| Idea               | Triton               | Mojo                    | MLIR            | LLVM IR            | PTX               |
| ------------------ | -------------------- | ----------------------- | --------------- | ------------------ | ----------------- |
| Which elements?    | `pid*BLOCK + arange` | `i` stepping by `width` | `scf.for %i`    | `ctaid*ntid + tid` | `mad.lo.s32`      |
| Out-of-range guard | `mask=`              | scalar tail loop        | loop bound `%n` | `icmp` + `br`      | `setp` + `@p bra` |
| Load               | `tl.load`            | `unsafe_load[width=]`   | `memref.load`   | `load float`       | `ld.global.b32`   |
| Add                | `x + y` (tile)       | SIMD `+`                | `arith.addf`    | `fadd float`       | `add.rn.f32`      |

## 🔗 Related

- [The whole stack](../maps/the-whole-stack.md)
- [Basic block and CFG](../01-foundations/basic-block.md)
- [Dialect](../02-ir-design/dialect.md)

---

✅ Verified against: LLVM/MLIR 23.1.1 · Mojo 1.1.0 · Triton: follows the
official tutorial, not run locally
