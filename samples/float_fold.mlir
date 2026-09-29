// x + 0.0 is NOT folded (x = -0.0 would give +0.0); x + (-0.0) IS folded.
func.func @f(%x: f32, %i: i32) -> (f32, f32, i32) {
  %p = arith.constant 0.0 : f32
  %n = arith.constant -0.0 : f32
  %c5 = arith.constant 5 : i32
  %a = arith.addf %x, %p : f32
  %b = arith.addf %x, %n : f32
  %c = arith.addi %c5, %i : i32
  return %a, %b, %c : f32, f32, i32
}
