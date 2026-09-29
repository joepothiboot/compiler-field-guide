# Codegen and Runtime ⚙️

From the lowest IR to something that runs.

| Page                                                             | In one line                                                                                                                                                                                                                           |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Instruction Selection 🎯](instruction-selection.md)             | Instruction selection (isel) turns target-independent IR operations (`add`, `mul`, `fmul`) into real machine instructions of one CPU or GPU, often combining several IR operations into one instruction (`mul` + `add` → `madd`).     |
| [Register Allocation 🗃️](register-allocation.md)                 | SSA gives you unlimited _virtual_ registers.                                                                                                                                                                                          |
| [JIT vs AOT ⚡](jit-vs-aot.md)                                   | AOT (ahead-of-time) compiles before the program runs and ships a binary.                                                                                                                                                              |
| [ABI and Calling Conventions 📞](abi-and-calling-conventions.md) | The ABI (application binary interface) is the contract that lets separately compiled code call each other: which registers hold the arguments and return value, how structs are passed, and which registers a function must preserve. |
| [Linking and Object Files 🧷](linking-and-object-files.md)       | The compiler turns each source file into an object file (machine code plus a list of symbols it defines and needs).                                                                                                                   |
| [PTX, ptxas and SASS 🟢](ptx-ptxas-and-sass.md)                  | PTX is NVIDIA's _virtual_ GPU assembly: stable, documented and what compilers emit. `ptxas` compiles PTX into SASS, the real machine code of one GPU generation.                                                                      |

New pages start from [../_templates/term.md](../_templates/term.md).
