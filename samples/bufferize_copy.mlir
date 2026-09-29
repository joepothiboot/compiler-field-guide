// Same as bufferize.mlir, but the original %t is ALSO returned,
// so it must not be overwritten: bufferization has to copy.
func.func @scale_keep(%t: tensor<8xf32>, %s: f32) -> (tensor<8xf32>, tensor<8xf32>) {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c8 = arith.constant 8 : index
  %r = scf.for %i = %c0 to %c8 step %c1 iter_args(%acc = %t) -> (tensor<8xf32>) {
    %x = tensor.extract %acc[%i] : tensor<8xf32>
    %y = arith.mulf %x, %s : f32
    %next = tensor.insert %y into %acc[%i] : tensor<8xf32>
    scf.yield %next : tensor<8xf32>
  }
  return %t, %r : tensor<8xf32>, tensor<8xf32>
}
