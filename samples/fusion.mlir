#id = affine_map<(d0) -> (d0)>
// y = relu(a + b): two elementwise ops, so two loops over memory.
func.func @add_relu(%a: tensor<1024xf32>, %b: tensor<1024xf32>) -> tensor<1024xf32> {
  %zero = arith.constant 0.0 : f32
  %e0 = tensor.empty() : tensor<1024xf32>
  %sum = linalg.generic {indexing_maps = [#id, #id, #id], iterator_types = ["parallel"]}
      ins(%a, %b : tensor<1024xf32>, tensor<1024xf32>) outs(%e0 : tensor<1024xf32>) {
  ^bb0(%x: f32, %y: f32, %o: f32):
    %s = arith.addf %x, %y : f32
    linalg.yield %s : f32
  } -> tensor<1024xf32>
  %e1 = tensor.empty() : tensor<1024xf32>
  %out = linalg.generic {indexing_maps = [#id, #id], iterator_types = ["parallel"]}
      ins(%sum : tensor<1024xf32>) outs(%e1 : tensor<1024xf32>) {
  ^bb0(%x: f32, %o: f32):
    %r = arith.maximumf %x, %zero : f32
    linalg.yield %r : f32
  } -> tensor<1024xf32>
  return %out : tensor<1024xf32>
}
