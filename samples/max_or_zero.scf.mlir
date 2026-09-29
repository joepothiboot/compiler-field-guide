func.func @max_or_zero(%x: i32) -> i32 {
  %zero = arith.constant 0 : i32
  %pos = arith.cmpi sgt, %x, %zero : i32
  %r = scf.if %pos -> (i32) {
    scf.yield %x : i32
  } else {
    scf.yield %zero : i32
  }
  return %r : i32
}
