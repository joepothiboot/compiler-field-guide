func.func @vadd(%a: memref<1024xf32>, %b: memref<1024xf32>, %c: memref<1024xf32>) {
  affine.for %i = 0 to 1024 {
    %x = affine.load %a[%i] : memref<1024xf32>
    %y = affine.load %b[%i] : memref<1024xf32>
    %s = arith.addf %x, %y : f32
    affine.store %s, %c[%i] : memref<1024xf32>
  }
  return
}
