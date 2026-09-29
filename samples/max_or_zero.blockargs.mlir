func.func @max_or_zero(%x: i32) -> i32 {
  %zero = arith.constant 0 : i32
  %pos = arith.cmpi sgt, %x, %zero : i32
  cf.cond_br %pos, ^merge(%x : i32), ^merge(%zero : i32)
^merge(%r: i32):
  return %r : i32
}
