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
