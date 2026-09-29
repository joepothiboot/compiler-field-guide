// C += A x B on 64x64 buffers, starting from the highest-level op.
func.func @matmul(%A: memref<64x64xf32>, %B: memref<64x64xf32>, %C: memref<64x64xf32>) {
  linalg.matmul ins(%A, %B : memref<64x64xf32>, memref<64x64xf32>)
                outs(%C : memref<64x64xf32>)
  return
}
