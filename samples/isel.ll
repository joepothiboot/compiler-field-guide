; (a + b) * c - a, and a float multiply-add, for instruction selection demos.
target triple = "arm64-apple-macosx"

define i64 @expr(i64 %a, i64 %b, i64 %c) {
  %s = add i64 %a, %b
  %m = mul i64 %s, %c
  %r = sub i64 %m, %a
  ret i64 %r
}

define float @madd(float %x, float %y, float %z) {
  %m = fmul contract float %x, %y
  %r = fadd contract float %m, %z
  ret float %r
}
