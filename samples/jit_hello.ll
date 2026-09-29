; Run with the LLVM JIT:  lli jit_hello.ll   (no compile/link step)
@fmt = private constant [22 x i8] c"JIT says: 6 * 7 = %d\0A\00"

declare i32 @printf(ptr, ...)

define i32 @main() {
  %v = mul i32 6, 7
  %n = call i32 (ptr, ...) @printf(ptr @fmt, i32 %v)
  ret i32 0
}
