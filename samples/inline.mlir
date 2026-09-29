func.func private @square(%v: f32) -> f32 {
  %r = arith.mulf %v, %v : f32
  return %r : f32
}

func.func @sum_of_squares(%a: f32, %b: f32) -> f32 {
  %x = func.call @square(%a) : (f32) -> f32
  %y = func.call @square(%b) : (f32) -> f32
  %s = arith.addf %x, %y : f32
  return %s : f32
}
