target triple = "nvptx64-nvidia-cuda"

define ptx_kernel void @vadd(ptr %a, ptr %b, ptr %c, i32 %n) {
entry:
  %bid = call i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
  %bdim = call i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
  %tid = call i32 @llvm.nvvm.read.ptx.sreg.tid.x()
  %base = mul i32 %bid, %bdim
  %i = add i32 %base, %tid
  %inb = icmp slt i32 %i, %n
  br i1 %inb, label %body, label %exit

body:
  %idx = sext i32 %i to i64
  %pa = getelementptr inbounds float, ptr %a, i64 %idx
  %pb = getelementptr inbounds float, ptr %b, i64 %idx
  %pc = getelementptr inbounds float, ptr %c, i64 %idx
  %x = load float, ptr %pa
  %y = load float, ptr %pb
  %s = fadd float %x, %y
  store float %s, ptr %pc
  br label %exit

exit:
  ret void
}

declare i32 @llvm.nvvm.read.ptx.sreg.ctaid.x()
declare i32 @llvm.nvvm.read.ptx.sreg.ntid.x()
declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()
