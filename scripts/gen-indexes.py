#!/usr/bin/env python3
"""Regenerates every chapter's README.md table from the pages' titles and
"One line" summaries. Run after adding or renaming a page:

    python3 scripts/gen-indexes.py
"""
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# (folder, heading, emoji, blurb, pages in reading order)
CHAPTERS = [
    ("00-bridge", "Bridge from FE/SWE", "🌉",
     "Things you already know from frontend and general software work, mapped onto compiler ideas.",
     ["babel-is-a-compiler", "ast-vs-ir", "bundler-plugins-vs-passes",
      "typescript-types-vs-ir-types", "v8-jit-tiers-vs-opt-levels"]),
    ("01-foundations", "Foundations", "🧱",
     "The core terms every later chapter assumes.",
     ["lexer-and-parser", "basic-block", "ssa", "dominance", "use-def-chains", "loops-in-ir"]),
    ("02-ir-design", "IR Design", "🌐",
     "How MLIR IR is built out of parts, and how it moves between levels.",
     ["dialect", "operation", "region", "types", "attributes-and-properties",
      "ods-and-tablegen", "legalization"]),
    ("03-transformations", "Transformations", "🔁",
     "What passes actually do to the IR.",
     ["pass-and-pass-manager", "pattern-rewrite", "canonicalization-and-folding", "cse-and-dce",
      "inlining", "fusion", "tiling", "vectorization", "bufferization"]),
    ("04-hardware", "Hardware", "🔩",
     "Why performance depends on the machine, not only the algorithm.",
     ["simd-and-vector-width", "cache-and-memory-hierarchy", "gpu-thread-warp-block-grid",
      "shared-memory-and-registers", "memory-coalescing", "occupancy", "tensor-cores"]),
    ("05-ml-compilers", "ML Compilers", "🧠",
     "What is specific to compiling ML workloads.",
     ["tensor-and-shape", "layout-and-strides", "kernel", "graph-vs-kernel-compiler",
      "triton-programming-model", "autotuning", "torch-compile"]),
    ("06-mojo", "Mojo", "🔥",
     "Mojo 1.1 language and library features that matter for writing fast, generic libraries.",
     ["def-struct-and-argument-conventions", "ownership-and-transfer", "traits",
      "parameters-vs-arguments", "comptime", "simd-and-dtype", "max-and-mojo-kernels"]),
    ("07-codegen-runtime", "Codegen and Runtime", "⚙️",
     "From the lowest IR to something that runs.",
     ["instruction-selection", "register-allocation", "jit-vs-aot",
      "abi-and-calling-conventions", "linking-and-object-files", "ptx-ptxas-and-sass"]),
    ("08-cpp-for-compilers", "C++ for Compilers", "🧰",
     "The C++ techniques LLVM and MLIR are written with, explained with runnable code from [codebases/](../codebases/).",
     ["ownership-and-arenas", "small-vector-and-arrayref", "virtual-dispatch-and-crtp",
      "llvm-style-rtti", "intrusive-lists", "variant-asts", "owning-slots-and-safe-rewrites",
      "llvm-coding-conventions"]),
    ("09-algorithms", "Compiler Algorithms by Hand", "🧮",
     "Classic compiler algorithms, implemented and tested in [codebases/compiler-mechanics-cpp](../codebases/compiler-mechanics-cpp/), explained step by step.",
     ["dominator-computation", "ssa-construction", "dataflow-analysis",
      "graph-coloring-register-allocation"]),
    ("maps", "Maps", "🗺️",
     "Full-page diagrams of how everything fits together.",
     ["the-whole-stack", "where-each-tool-sits", "tensor-journey-matmul-to-ptx"]),
    ("rosetta", "Rosetta", "🪨",
     "The same program in every tool, compared side by side, with real output and measurements.",
     ["vector-add-in-5-irs", "reduction-in-5-irs", "matmul-naive-tiled-fused"]),
    ("real-world", "Real-World Codebase Tours", "🏙️",
     "Where the concepts in this guide live in real repositories. Every path was checked on GitHub.",
     ["llvm-and-mlir-tour", "triton-tour", "pytorch-inductor-tour", "mojo-and-max-tour",
      "my-projects-tour"]),
]


def title_and_summary(path):
    text = open(path, encoding="utf-8").read()
    title = re.search(r"^# (.+)$", text, re.M).group(1).strip()
    quote = re.search(r"^> (.+?)(?=\n\n|\n#)", text, re.S | re.M)
    summary = ""
    if quote:
        summary = " ".join(l.lstrip("> ").strip() for l in quote.group(0).splitlines())
        summary = re.sub(r"^\*\*[^*]+:\*\*\s*", "", summary)  # drop a "**One line:**" label
        summary = summary.replace("**", "")
        summary = re.split(r"(?<=[\w`)\]][.!?])\s+(?=[A-Z])", re.sub(r"\s+", " ", summary))[0]
    return title, summary


def main():
    for folder, heading, emoji, blurb, pages in CHAPTERS:
        rows = []
        for page in pages:
            path = os.path.join(ROOT, folder, page + ".md")
            title, summary = title_and_summary(path)
            rows.append(f"| [{title}]({page}.md) | {summary} |")
        lines = [f"# {heading} {emoji}", "", blurb, "",
                 "| Page | In one line |", "| ---- | ----------- |", *rows, ""]
        if folder not in ("maps", "rosetta", "real-world"):
            lines += ["New pages start from [../_templates/term.md](../_templates/term.md).", ""]
        with open(os.path.join(ROOT, folder, "README.md"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        print(f"{folder}: {len(pages)} pages")


if __name__ == "__main__":
    main()
