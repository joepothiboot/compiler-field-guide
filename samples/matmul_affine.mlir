// C[i][j] += A[i][k] * B[k][j] for 256x256 matrices.
func.func @matmul(%A: memref<256x256xf32>, %B: memref<256x256xf32>, %C: memref<256x256xf32>) {
  affine.for %i = 0 to 256 {
    affine.for %j = 0 to 256 {
      affine.for %k = 0 to 256 {
        %a = affine.load %A[%i, %k] : memref<256x256xf32>
        %b = affine.load %B[%k, %j] : memref<256x256xf32>
        %c = affine.load %C[%i, %j] : memref<256x256xf32>
        %p = arith.mulf %a, %b : f32
        %s = arith.addf %c, %p : f32
        affine.store %s, %C[%i, %j] : memref<256x256xf32>
      }
    }
  }
  return
}
