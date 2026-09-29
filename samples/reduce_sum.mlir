// A running sum carried through the loop with iter_args.
func.func @sum(%x: memref<?xf32>) -> f32 {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %zero = arith.constant 0.0 : f32
  %n = memref.dim %x, %c0 : memref<?xf32>
  %s = scf.for %i = %c0 to %n step %c1 iter_args(%acc = %zero) -> (f32) {
    %v = memref.load %x[%i] : memref<?xf32>
    %next = arith.addf %acc, %v : f32
    scf.yield %next : f32
  }
  return %s : f32
}
