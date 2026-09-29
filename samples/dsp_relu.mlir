// Needs nanodsp-opt from nano-dsp-mlir (custom `dsp` dialect).
func.func @double_relu(%x: tensor<2x3xf32>) -> tensor<2x3xf32> {
  %a = dsp.relu %x : tensor<2x3xf32>
  %b = dsp.relu %a : tensor<2x3xf32>
  return %b : tensor<2x3xf32>
}
