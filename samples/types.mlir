func.func @types(
    %i: i32, %idx: index, %f: f32, %h: f16, %b: bf16,
    %v: vector<4xf32>,
    %t: tensor<4x?xf32>,
    %m: memref<4x8xf32>,
    %s: memref<4x8xf32, strided<[1, 4]>>) {
  return
}
