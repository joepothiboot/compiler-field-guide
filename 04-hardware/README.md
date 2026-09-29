# Hardware 🔩

Why performance depends on the machine, not only the algorithm.

| Page                                                              | In one line                                                                                                                                                |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [SIMD and Vector Width 🧵](simd-and-vector-width.md)              | SIMD (single instruction, multiple data) registers hold several values side by side, called _lanes_.                                                       |
| [Cache and Memory Hierarchy 🏔️](cache-and-memory-hierarchy.md)    | Memory is a pyramid: a few very fast, tiny levels near the core (registers, L1, L2) and a large slow level far away (DRAM).                                |
| [GPU Thread, Warp, Block, Grid 🔲](gpu-thread-warp-block-grid.md) | A GPU kernel runs as a grid of blocks; each block is a group of threads that can share fast memory; threads execute in lockstep groups of 32 called warps. |
| [Shared Memory and Registers 🗄️](shared-memory-and-registers.md)  | Each GPU thread has private registers (fastest).                                                                                                           |
| [Memory Coalescing 🚚](memory-coalescing.md)                      | When the 32 threads of a warp load from neighboring addresses, the hardware combines them into a few wide memory transactions.                             |
| [Occupancy 📈](occupancy.md)                                      | Occupancy is how many warps are actually resident on a GPU core, compared with the maximum it could hold.                                                  |
| [Tensor Cores 🟩](tensor-cores.md)                                | Tensor cores are dedicated matrix-multiply units.                                                                                                          |

New pages start from [../_templates/term.md](../_templates/term.md).
