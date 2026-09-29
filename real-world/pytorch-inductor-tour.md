# PyTorch Inductor Codebase Tour 🔥

> **Where `torch.compile` lives in `pytorch/pytorch`.** Dynamo captures
> graphs, AOTAutograd splits forward and backward, and Inductor lowers,
> fuses and generates code. Paths were checked on GitHub in September 2026.

## 🗺️ The route through the source

```
torch.compile(fn)
   │
   ▼  torch/_dynamo/
   │    eval_frame.py         hooks CPython frame evaluation
   │    symbolic_convert.py   interprets bytecode, records tensor ops into an FX graph
   │    guards.py             builds the checks that decide when to recompile
   ▼  torch/fx/graph.py       the FX graph data structure (what TORCH_LOGS="graph_code" prints)
   ▼  torch/_functorch/aot_autograd.py   forward/backward graphs, functionalization
   ▼  torch/_inductor/
        decomposition.py      big ops → simpler ops
        lowering.py           aten ops → Inductor IR
        ir.py                 Inductor's loop-level IR
        scheduler.py          groups nodes into FUSED kernels
        codegen/triton.py     writes Triton kernels (GPU)
        codegen/cpp.py        writes C++ kernels (CPU; the Vectorized<float> code on the torch.compile page)
        codegen/wrapper.py    writes the host code (the `call(args)` function)
        select_algorithm.py   max-autotune: benchmarks templates / library kernels
        graph.py              ties it together (logs "Output code written to: ...")
```

## 🔎 Concept → file

| Concept (guide page)                                 | File                                                  |
| ---------------------------------------------------- | ----------------------------------------------------- |
| [torch.compile](../05-ml-compilers/torch-compile.md) | the whole route above                                 |
| Graph capture, guards                                | `torch/_dynamo/symbolic_convert.py`, `guards.py`      |
| [Fusion](../03-transformations/fusion.md)            | `torch/_inductor/scheduler.py`                        |
| [Kernel generation](../05-ml-compilers/kernel.md)    | `torch/_inductor/codegen/triton.py`, `codegen/cpp.py` |
| [Autotuning](../05-ml-compilers/autotuning.md)       | `torch/_inductor/select_algorithm.py`                 |
| Host wrapper                                         | `torch/_inductor/codegen/wrapper.py`                  |

## 📖 How to read it

1. Run [samples/torch_compile_demo.py](../samples/torch_compile_demo.py)
   with `TORCH_LOGS="graph_code,output_code"`. The log's last line gives
   the path of the generated file. Open it next to `codegen/cpp.py` and match
   the pieces (`cpp_fused_add_mul_relu_0`, `Vectorized<float>`).
2. Read `scheduler.py` for the fusion decisions: this is the graph-compiler
   half of [Graph vs kernel compiler](../05-ml-compilers/graph-vs-kernel-compiler.md).
3. Set `TORCH_LOGS="recompiles"` and call the compiled function with a
   different shape to see guards in action.

## 🔗 Related

- [torch.compile](../05-ml-compilers/torch-compile.md)
- [Triton tour](triton-tour.md)

---

✅ Paths verified on GitHub (`pytorch/pytorch`, default branch, 2026-09) ·
the `torch.compile` output quoted in this guide is from PyTorch 2.5.1, run locally
