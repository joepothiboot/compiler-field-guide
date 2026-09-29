# Foundations 🧱

The core terms every later chapter assumes.

| Page                                        | In one line                                                                                                                                            |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Lexer and Parser 🔤](lexer-and-parser.md)  | The _lexer_ cuts source text into tokens (words).                                                                                                      |
| [Basic Block and CFG 🧱](basic-block.md)    | A _basic block_ is a run of instructions with one way in (the top) and one way out (a jump at the bottom).                                             |
| [SSA (Static Single Assignment) 🏷️](ssa.md) | Every value is assigned exactly once.                                                                                                                  |
| [Dominance 👑](dominance.md)                | Block A _dominates_ block B if every path from the function entry to B goes through A.                                                                 |
| [Use-Def Chains 🔗](use-def-chains.md)      | Every SSA value knows its one definition and the list of all its uses.                                                                                 |
| [Loops in IR 🔄](loops-in-ir.md)            | At the IR level a loop is a cycle in the CFG: a header block that decides whether to continue, a body, a latch that jumps back, and one or more exits. |

New pages start from [../_templates/term.md](../_templates/term.md).
