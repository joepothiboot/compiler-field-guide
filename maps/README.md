# Maps 🗺️

Full-page diagrams of how everything fits together.

| Page | In one line |
| ---- | ----------- |
| [The Whole Stack 🗺️](the-whole-stack.md) | Each tool is a different entry point that eventually reaches the same few layers: MLIR, then LLVM IR, then machine code for a CPU or GPU. |
| [Where Each Tool Sits (Detailed) 🧩](where-each-tool-sits.md) | The pipeline inside each tool, stage by stage, with the command or flag that shows you that stage. |
| [A Tensor's Journey: `linalg.matmul` to PTX 🧳](tensor-journey-matmul-to-ptx.md) | One op, followed through every level of upstream MLIR down to NVIDIA PTX. |
