# torch.compile: Dynamo and Inductor 🔥

> **One line:** `torch.compile(fn)` captures the PyTorch operations your
> Python code performs into a graph (**TorchDynamo**), then hands that graph
> to a compiler backend (**Inductor** by default), which fuses operations
> and generates new kernels: Triton on GPUs, C++ on CPUs.

## 🌉 From frontend

Dynamo is like a bundler's dependency tracer that watches what your code
actually does. It works on the running Python bytecode, so it can see
through normal Python control flow. Inductor is the code generator that
emits an optimized bundle. **Guards** are the cache keys: if the input
shapes or types change, it recompiles, like a bundler rebuilding when an
input file changes.

## 🖼️ Picture

```
 def add_relu_scale(a, b):
     return torch.relu(a + b) * 2.0
            │
            │ TorchDynamo: intercepts Python bytecode, records tensor ops
            ▼
 FX graph:   add ──► relu ──► mul           + guards: "a is f32[1024], on cpu ..."
            │
            │ AOTAutograd (forward/backward graphs), decompositions
            ▼
 Inductor:  schedules and FUSES the three pointwise ops into one loop
            │
            ├── GPU: writes a Triton kernel ──► Triton ──► PTX
            └── CPU: writes C++ with at::vec::Vectorized ──► C++ compiler
```

## 🔧 In each tool

Real output on this Mac. Run
[samples/torch_compile_demo.py](../samples/torch_compile_demo.py) with
`TORCH_LOGS="graph_code,output_code"` (PyTorch 2.5.1, CPU):

**1. The captured graph** (Dynamo):

```python
def forward(self, L_a_: "f32[1024][1]cpu", L_b_: "f32[1024][1]cpu"):
    l_a_ = L_a_
    l_b_ = L_b_
    add: "f32[1024][1]cpu" = l_a_ + l_b_;  l_a_ = l_b_ = None
    relu: "f32[1024][1]cpu" = torch.relu(add);  add = None
    mul: "f32[1024][1]cpu" = relu * 2.0;  relu = None
    return (mul,)
```

**2. The generated kernel** (Inductor, CPU backend). Three ops became **one**
loop, named after what it fused:

```cpp
cpp_fused_add_mul_relu_0 = async_compile.cpp_pybinding(['const float*', 'const float*', 'float*'], '''
extern "C"  void kernel(const float* in_ptr0,
                       const float* in_ptr1,
                       float* out_ptr0)
{
    {
        for(int64_t x0=static_cast<int64_t>(0LL); x0<static_cast<int64_t>(1024LL); x0+=static_cast<int64_t>(8LL))
        {
            auto tmp0 = at::vec::Vectorized<float>::loadu(in_ptr0 + static_cast<int64_t>(x0), static_cast<int64_t>(8));
            auto tmp1 = at::vec::Vectorized<float>::loadu(in_ptr1 + static_cast<int64_t>(x0), static_cast<int64_t>(8));
            auto tmp2 = tmp0 + tmp1;
            auto tmp3 = at::vec::clamp_min(tmp2, decltype(tmp2)(0));
            auto tmp4 = static_cast<float>(2.0);
            auto tmp5 = at::vec::Vectorized<float>(tmp4);
            auto tmp6 = tmp3 * tmp5;
            tmp6.store(out_ptr0 + static_cast<int64_t>(x0));
        }
    }
}
''')
```

**3. The host wrapper**, which checks shapes/strides, allocates the output
once and calls the kernel:

```python
def call(args):
    arg0_1, arg1_1 = args
    assert_size_stride(arg0_1, (1024, ), (1, ))
    assert_size_stride(arg1_1, (1024, ), (1, ))
    buf0 = empty_strided_cpu((1024, ), (1, ), torch.float32)
    cpp_fused_add_mul_relu_0(arg0_1, arg1_1, buf0)
    return (buf0, )
```

The demo then prints `matches eager: True`.

Things to notice:

- Static shape `1024` is baked into the loop bound (it specialized).
- `Vectorized<float>` with step 8: Inductor's CPU vector abstraction.
- No intermediate buffers for `add` or `relu`: [fusion](../03-transformations/fusion.md).
- On a CUDA GPU, the same graph would produce a `@triton.jit` kernel
  instead (not run here: no NVIDIA GPU).

| Stage        | Component                    | Look at it with             |
| ------------ | ---------------------------- | --------------------------- |
| Capture      | TorchDynamo                  | `TORCH_LOGS="graph_code"`   |
| Autograd     | AOTAutograd                  | `TORCH_LOGS="aot_graphs"`   |
| Codegen      | Inductor                     | `TORCH_LOGS="output_code"`  |
| Recompiles   | Guards                       | `TORCH_LOGS="recompiles"`   |
| Graph breaks | Unsupported Python in Dynamo | `TORCH_LOGS="graph_breaks"` |

## ⚠️ Common confusion

- **Graph breaks.** Code Dynamo cannot trace (some Python features,
  `print` of tensor values, data-dependent control flow) splits the graph
  into pieces run eagerly in between. Fewer, bigger graphs mean more fusion.
- **The first call is slow.** It compiles. Measure the second call.
- **`torch.compile` is not Triton.** It _uses_ Triton as its GPU kernel
  language. You can also write Triton kernels by hand and call them from
  PyTorch.

## 🔗 Related

- [Graph compiler vs kernel compiler](graph-vs-kernel-compiler.md)
- [Fusion](../03-transformations/fusion.md)
- [PyTorch Inductor codebase tour](../real-world/pytorch-inductor-tour.md)

---

✅ Verified against: PyTorch 2.5.1 on macOS (CPU backend, run locally)
