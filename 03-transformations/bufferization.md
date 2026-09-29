# Bufferization 🪣

> **One line:** Bufferization converts value-style `tensor`s (immutable, no
> address) into `memref` buffers (memory that is read and written). It
> decides where memory is allocated, and when an update can happen in place
> or needs a copy.

## 🌉 From frontend

Immer lets you write `draft.items[0] = x` and produces a new immutable
state. Under the hood, it shares everything that did not change and only
copies what did. Bufferization is the reverse direction: you write
immutable tensor code, and the compiler figures out when it is safe to just
**overwrite the old buffer** and when it must copy.

## 🖼️ Picture

```
 TENSOR WORLD (values)                    MEMREF WORLD (buffers)
 ─────────────────────                    ──────────────────────
 %next = tensor.insert %y into %acc[%i]   memref.store %y, %buf[%i]
   "a new tensor, equal to %acc              "overwrite one slot of
    except at %i"                             an existing buffer"

 in place is safe when the old value      if the old value IS still needed
 is never read again:                     somewhere, copy it first:

   %t ──► insert ──► %next                   %t ────────────────► (still used)
   (dead after)                              copy ──► insert ──► %next
```

## 🔧 In each tool

**Case 1: in place.** Real `mlir-opt --one-shot-bufferize="bufferize-function-boundaries"`
on [samples/bufferize.mlir](../samples/bufferize.mlir), which scales a
tensor in a loop:

```mlir
// input (tensor)
%r = scf.for %i = %c0 to %c8 step %c1 iter_args(%acc = %t) -> (tensor<8xf32>) {
  %x = tensor.extract %acc[%i] : tensor<8xf32>
  %y = arith.mulf %x, %s : f32
  %next = tensor.insert %y into %acc[%i] : tensor<8xf32>
  scf.yield %next : tensor<8xf32>
}

// output (memref): no allocation, the input buffer is updated in place
%0 = scf.for %arg2 = %c0 to %c8 step %c1 iter_args(%arg3 = %arg0) -> (memref<8xf32, strided<[?], offset: ?>>) {
  %1 = memref.load %arg3[%arg2] : memref<8xf32, strided<[?], offset: ?>>
  %2 = arith.mulf %1, %arg1 : f32
  memref.store %2, %arg3[%arg2] : memref<8xf32, strided<[?], offset: ?>>
  scf.yield %arg3 : memref<8xf32, strided<[?], offset: ?>>
}
```

**Case 2: copy.** [samples/bufferize_copy.mlir](../samples/bufferize_copy.mlir)
is identical, except it _also returns the original_ `%t`. Overwriting it
would be wrong, so bufferization inserts an allocation and a copy (real
output, trimmed):

```mlir
%alloc = memref.alloc() {alignment = 64 : i64} : memref<8xf32>
memref.copy %arg0, %alloc : memref<8xf32, strided<[?], offset: ?>> to memref<8xf32>
%0 = scf.for ... iter_args(%arg3 = %alloc) -> (memref<8xf32>) {
...
return %arg0, %0 : ...                  ← original returned untouched
```

`strided<[?], offset: ?>` appears because, at a function boundary, the
compiler does not know the caller's buffer layout, so it assumes the most
general one.

| Tool    | Bufferization                                                                                   |
| ------- | ----------------------------------------------------------------------------------------------- |
| LLVM    | Not needed: LLVM IR only has memory (`ptr`, `load`, `store`)                                    |
| MLIR    | `--one-shot-bufferize` (whole-program analysis of which updates can be in place)                |
| Triton  | Not needed in the same way: kernels take pointers, and tiles live in registers or shared memory |
| Mojo    | Not needed: you work with buffers and pointers directly, with ownership rules for safety        |
| PyTorch | Eager mode allocates a new tensor for most ops; in-place ops end in `_` (`x.add_(y)`)           |

## ⚠️ Common confusion

- **Why use tensors at all, then?** Transformations such as fusion and
  tiling are much easier on values: no need to prove that two memory
  accesses do not conflict. So ML compilers optimize on tensors first and
  bufferize late.
- **Unnecessary copies are the main performance risk.** If an analysis
  cannot prove in-place is safe, it copies. Check bufferized IR for
  unexpected `memref.alloc` / `memref.copy`.
- **Deallocation** is a separate step (`--buffer-deallocation-pipeline`):
  bufferization allocates; something else must free.

## 🔗 Related

- [Types in MLIR](../02-ir-design/types.md): tensor vs memref
- [Tensor and shape](../05-ml-compilers/tensor-and-shape.md)
- [Ownership and transfer (Mojo)](../06-mojo/ownership-and-transfer.md)

---

✅ Verified against: MLIR 23.1.1
