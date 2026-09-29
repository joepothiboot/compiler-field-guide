"""torch.compile on CPU: prints the captured graph and Inductor's generated kernel.

Run:  TORCH_LOGS="graph_code,output_code" python3 torch_compile_demo.py
"""
import torch


def add_relu_scale(a, b):
    return torch.relu(a + b) * 2.0


compiled = torch.compile(add_relu_scale)
a = torch.randn(1024)
b = torch.randn(1024)
out = compiled(a, b)
print("matches eager:", torch.allclose(out, add_relu_scale(a, b)))
