func.func @attrs(%x: i32, %y: f32) -> (i32, f32) {
  // `value` and `predicate` are properties: part of the op's definition.
  %c5 = arith.constant 5 : i32
  %gt = arith.cmpi sgt, %x, %c5 : i32
  // `fastmath` is a property too; `guide.note` is a discardable attribute.
  %s = arith.addf %y, %y fastmath<fast> {guide.note = "any dialect can attach me"} : f32
  %r = arith.select %gt, %x, %c5 : i32
  return %r, %s : i32, f32
}
