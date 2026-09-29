; One warp-wide tensor core instruction: D (16x8 f32) = A (16x16 f16) x B (16x8 f16) + C.
; Each of the 32 threads holds a small fragment of A, B, C and D in registers.
target triple = "nvptx64-nvidia-cuda"

define ptx_kernel void @mma_16x8x16(ptr %out, <2 x half> %a0, <2 x half> %a1,
                                    <2 x half> %a2, <2 x half> %a3,
                                    <2 x half> %b0, <2 x half> %b1) {
  %d = call { float, float, float, float }
       @llvm.nvvm.mma.m16n8k16.row.col.f32.f32(
         <2 x half> %a0, <2 x half> %a1, <2 x half> %a2, <2 x half> %a3,
         <2 x half> %b0, <2 x half> %b1,
         float 0.0, float 0.0, float 0.0, float 0.0)
  %d0 = extractvalue { float, float, float, float } %d, 0
  store float %d0, ptr %out
  ret void
}

declare { float, float, float, float } @llvm.nvvm.mma.m16n8k16.row.col.f32.f32(
  <2 x half>, <2 x half>, <2 x half>, <2 x half>,
  <2 x half>, <2 x half>, float, float, float, float)
