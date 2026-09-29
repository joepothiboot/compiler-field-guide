// Intentionally invalid: %y is defined only on the "then" path,
// but used after the paths join.
func.func @bad(%c: i1, %x: i32) -> i32 {
  cf.cond_br %c, ^then, ^merge
^then:
  %y = arith.addi %x, %x : i32
  cf.br ^merge
^merge:
  return %y : i32
}
