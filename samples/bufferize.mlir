func.func @scale(%t: tensor<8xf32>, %s: f32) -> tensor<8xf32> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c8 = arith.constant 8 : index
  %r = scf.for %i = %c0 to %c8 step %c1 iter_args(%acc = %t) -> (tensor<8xf32>) {
    %x = tensor.extract %acc[%i] : tensor<8xf32>
    %y = arith.mulf %x, %s : f32
    %next = tensor.insert %y into %acc[%i] : tensor<8xf32>
    scf.yield %next : tensor<8xf32>
  }
  return %r : tensor<8xf32>
}
