"""Shapes, strides and views in PyTorch (CPU only)."""
import torch

x = torch.arange(12, dtype=torch.float32).reshape(3, 4)
print("x.shape      ", tuple(x.shape), " x.stride()", x.stride(), " contiguous:", x.is_contiguous())
t = x.t()
print("x.t().shape  ", tuple(t.shape), " stride    ", t.stride(), " contiguous:", t.is_contiguous())
print("same storage:", t.data_ptr() == x.data_ptr())
c = t.contiguous()
print("t.contiguous()", tuple(c.shape), " stride    ", c.stride(), " same storage:", c.data_ptr() == x.data_ptr())
s = x[:, 1]
print("x[:, 1]      ", tuple(s.shape), " stride    ", s.stride(), " offset:", s.storage_offset())
b = torch.ones(4).expand(3, 4)
print("expand(3,4)  ", tuple(b.shape), " stride    ", b.stride(), " (0 = broadcast, no copy)")
nchw = torch.zeros(1, 3, 2, 2)
nhwc = nchw.to(memory_format=torch.channels_last)
print("NCHW stride  ", nchw.stride(), "  channels_last stride", nhwc.stride())
