func.func @fold_cse(%x: i32) -> (i32, i32) {
  %c2 = arith.constant 2 : i32
  %c3 = arith.constant 3 : i32
  %c0 = arith.constant 0 : i32
  %five = arith.addi %c2, %c3 : i32      // constant folding: 2 + 3
  %same = arith.addi %x, %c0 : i32       // x + 0 = x
  %a = arith.muli %same, %five : i32
  %b = arith.muli %same, %five : i32     // same as %a: CSE
  %dead = arith.subi %a, %b : i32        // never used: DCE
  return %a, %b : i32, i32
}
