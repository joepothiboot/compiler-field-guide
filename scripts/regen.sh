#!/usr/bin/env bash
# Regenerates every compiler listing and measurement quoted in the guide from
# samples/. Output goes to samples/out/ (git-ignored). After a toolchain
# upgrade, compare it with the pages and update their "Verified against" lines.
#
# Needs:    Homebrew LLVM (clang, opt, llc, lli, mlir-opt, mlir-translate)
# Optional: MOJO_RUN=1        run the Mojo samples and emit PTX (uses this repo's pixi env)
#           TORCH_RUN=1       run the PyTorch samples (python3 with torch installed)
#           NANODSP_OPT=path  nanodsp-opt from nano-dsp-mlir, for samples/dsp_relu.mlir
set -euo pipefail

cd "$(dirname "$0")/.."
LLVM_BIN="${LLVM_BIN:-$(brew --prefix llvm)/bin}"
OUT=samples/out
S=samples
mkdir -p "$OUT"

strip_ll() { grep -v '^;\|^!\|^attributes\|^target\|^source_filename' || true; }
strip_asm() { grep -vE '^\s*\.|^;|^\s*//|^#|^$' || true; }
cc() { "$LLVM_BIN/clang" "$@" 2>/dev/null; }   # silences the macOS SDK sysroot warning
mlir() { "$LLVM_BIN/mlir-opt" "$@"; }

echo "LLVM $("$LLVM_BIN/llvm-config" --version)" > "$OUT/VERSIONS.txt"

# --- 00/01: front end, SSA, types, optimization levels ----------------------
"$LLVM_BIN/clang" -fsyntax-only -Xclang -dump-tokens "$S/max_or_zero.c" 2>&1 \
  | grep -v 'warning:' > "$OUT/max_or_zero.tokens.txt"      # clang prints tokens on stderr
cc -fsyntax-only -Xclang -ast-dump -fno-color-diagnostics "$S/max_or_zero.c" > "$OUT/max_or_zero.ast.txt"
for f in max_or_zero vadd; do
  cc -O0 -Xclang -disable-O0-optnone -S -emit-llvm "$S/$f.c" -o - \
    | "$LLVM_BIN/opt" -S -passes=mem2reg | strip_ll > "$OUT/$f.ssa.ll"
done
cc -O1 -S -emit-llvm "$S/types.c" -o - | strip_ll > "$OUT/types.ll"
cc -O2 -S -emit-llvm "$S/vadd.c" -o - | strip_ll > "$OUT/vadd.O2.ll"
cc -O2 -S "$S/vadd.c" -o - | strip_asm > "$OUT/vadd.O2.s"
"$LLVM_BIN/clang" -O2 -Rpass=loop-vectorize -c "$S/vadd.c" -o /dev/null 2>&1 \
  | grep remark > "$OUT/vadd.remarks.txt" || true
cc -O0 -Xclang -disable-O0-optnone -S -emit-llvm "$S/vadd.c" -o - \
  | "$LLVM_BIN/opt" -passes='mem2reg,loop-simplify,print<loops>,print<domtree>' \
    -disable-output > "$OUT/vadd.loops-domtree.txt" 2>&1

# --- 01/02/03: MLIR ----------------------------------------------------------
mlir "$S/bad_dominance.mlir" > "$OUT/bad_dominance.txt" 2>&1 || true   # expected to fail
mlir --mlir-print-value-users "$S/max_or_zero.scf.mlir" > "$OUT/max_or_zero.users.mlir"
M="$S/max_or_zero.scf.mlir"
mlir "$M" --canonicalize > "$OUT/max_or_zero.canonical.mlir"
mlir "$M" --convert-scf-to-cf > "$OUT/max_or_zero.cf.mlir"
mlir "$M" --convert-scf-to-cf --convert-to-llvm > "$OUT/max_or_zero.llvm.mlir"
"$LLVM_BIN/mlir-translate" --mlir-to-llvmir "$OUT/max_or_zero.llvm.mlir" | strip_ll > "$OUT/max_or_zero.from-mlir.ll"
mlir "$M" --convert-to-llvm 2>&1 | "$LLVM_BIN/mlir-translate" --mlir-to-llvmir \
  > "$OUT/legalization-leftover.txt" 2>&1 || true                       # expected to fail
mlir "$S/max_or_zero.blockargs.mlir" > "$OUT/max_or_zero.blockargs.out.mlir"
mlir "$S/vadd.mlir" --convert-scf-to-cf > "$OUT/vadd.cf.mlir"
mlir --mlir-print-op-generic "$S/vadd.mlir" > "$OUT/vadd.generic.mlir"
mlir "$S/types.mlir" > "$OUT/types.out.mlir"
mlir --mlir-print-op-generic "$S/attributes.mlir" > "$OUT/attributes.generic.mlir"
mlir "$S/fold_cse.mlir" --canonicalize > "$OUT/fold_cse.canonical.mlir"
mlir "$S/fold_cse.mlir" --cse > "$OUT/fold_cse.cse.mlir"
mlir "$S/fold_cse.mlir" --canonicalize --cse > "$OUT/fold_cse.both.mlir"
mlir "$S/fold_cse.mlir" --pass-pipeline="builtin.module(func.func(canonicalize,cse))" \
  --mlir-timing -o /dev/null > "$OUT/fold_cse.timing.txt" 2>&1
mlir "$M" --convert-scf-to-cf --canonicalize --mlir-print-ir-after-all -o /dev/null \
  > "$OUT/print-ir-after-all.txt" 2>&1
mlir "$S/matmul_affine.mlir" --pass-pipeline="builtin.module(affine-loop-tile)" \
  > "$OUT/nesting-error.txt" 2>&1 || true                               # expected to fail
mlir "$S/float_fold.mlir" --canonicalize > "$OUT/float_fold.canonical.mlir"
mlir "$S/inline.mlir" --inline > "$OUT/inline.mlir"
mlir "$S/fusion.mlir" --linalg-fuse-elementwise-ops > "$OUT/fusion.fused.mlir"
mlir "$S/matmul_affine.mlir" --affine-loop-tile="tile-size=32" > "$OUT/matmul_affine.tiled.mlir"
mlir "$S/vadd_affine.mlir" --affine-super-vectorize="virtual-vector-size=4" > "$OUT/vadd_affine.vectorized.mlir"
mlir "$S/bufferize.mlir" --one-shot-bufferize="bufferize-function-boundaries" > "$OUT/bufferize.out.mlir"
mlir "$S/bufferize_copy.mlir" --one-shot-bufferize="bufferize-function-boundaries" > "$OUT/bufferize_copy.out.mlir"
mlir "$S/reduce_sum.mlir" --convert-scf-to-cf > "$OUT/reduce_sum.cf.mlir"
if [[ -n "${NANODSP_OPT:-}" ]]; then
  "$NANODSP_OPT" "$S/dsp_relu.mlir" --canonicalize > "$OUT/dsp_relu.canonical.mlir"
  "$NANODSP_OPT" "$S/dsp_relu.mlir" --canonicalize --convert-dsp-to-linalg > "$OUT/dsp_relu.linalg.mlir"
fi

# --- maps: linalg.matmul all the way to PTX ----------------------------------
J="$OUT/journey"; mkdir -p "$J"
mlir "$S/journey_matmul.mlir" --convert-linalg-to-parallel-loops > "$J/1_parallel.mlir"
mlir "$J/1_parallel.mlir" --gpu-map-parallel-loops --convert-parallel-loops-to-gpu > "$J/2_gpu.mlir"
mlir "$J/2_gpu.mlir" --lower-affine --gpu-kernel-outlining > "$J/3_outlined.mlir"
mlir "$J/3_outlined.mlir" --gpu-lower-to-nvvm-pipeline="cubin-format=isa cubin-chip=sm_80" > "$J/4_binary.mlir"
python3 - "$J/4_binary.mlir" "$J/5_kernel.ptx" <<'EOF'
import re, sys
s = open(sys.argv[1]).read()
i = s.index('assembly = "') + len('assembly = "')
ptx = re.sub(r'\\([0-9A-Fa-f]{2})', lambda m: chr(int(m.group(1), 16)), s[i:s.index('"', i)])
open(sys.argv[2], "w").write(ptx)
EOF

# --- 04/07/rosetta: LLVM codegen ---------------------------------------------
"$LLVM_BIN/llc" -mcpu=sm_80 "$S/vadd_gpu.ll" -o - | grep -v '^//' > "$OUT/vadd_gpu.ptx"
"$LLVM_BIN/llc" -mcpu=sm_80 "$S/tensor_core_mma.ll" -o - | grep -v '^//' > "$OUT/tensor_core_mma.ptx"
"$LLVM_BIN/llc" -O2 "$S/isel.ll" -stop-after=finalize-isel -o "$OUT/isel.after-isel.mir"
"$LLVM_BIN/llc" -O2 "$S/isel.ll" -stop-after=virtregrewriter -o "$OUT/isel.after-regalloc.mir"
"$LLVM_BIN/llc" -O2 "$S/isel.ll" -o - | strip_asm > "$OUT/isel.s"
cc -O1 -S "$S/abi.c" -o - | strip_asm > "$OUT/abi.arm64.s"
cc -O1 -S --target=x86_64-unknown-linux-gnu "$S/abi.c" -o - | strip_asm > "$OUT/abi.x86_64.s"
cc -O2 -S -emit-llvm "$S/reduce_sum.c" -o - | strip_ll > "$OUT/reduce_sum.O2.ll"
cc -O2 -ffast-math -S -emit-llvm "$S/reduce_sum.c" -o - | strip_ll > "$OUT/reduce_sum.fastmath.ll"
"$LLVM_BIN/lli" "$S/jit_hello.ll" > "$OUT/jit_hello.txt"

# Linking uses the system toolchain (it has the macOS SDK headers and ld).
L="$OUT/link"; mkdir -p "$L"
/usr/bin/clang -O1 -c "$S/link_main.c" -o "$L/link_main.o"
/usr/bin/clang -O1 -c "$S/link_lib.c" -o "$L/link_lib.o"
{ "$LLVM_BIN/llvm-nm" "$L/link_main.o"; echo; "$LLVM_BIN/llvm-nm" "$L/link_lib.o"; } > "$L/nm.txt"
/usr/bin/clang "$L/link_main.o" -o "$L/main_only" > "$L/link-error.txt" 2>&1 || true   # expected to fail
/usr/bin/clang "$L/link_main.o" "$L/link_lib.o" -o "$L/a.out" && "$L/a.out" > "$L/run.txt"
"$LLVM_BIN/llvm-objdump" -d -r --no-show-raw-insn "$L/link_main.o" > "$L/relocations.txt"

# --- Mojo (optional) ---------------------------------------------------------
if [[ "${MOJO_RUN:-0}" == 1 ]]; then
  pixi run mojo --version >> "$OUT/VERSIONS.txt"
  for f in vadd simd_basics cache_walk reduce_sum matmul_cpu mojo_arguments mojo_ownership \
           mojo_traits mojo_parameters mojo_comptime mojo_layout_tensor; do
    pixi run mojo run "$S/$f.mojo" > "$OUT/$f.mojo.txt" 2>&1
  done
  for f in gpu_vadd gpu_block_sum gpu_warp_and_coalescing; do
    ./scripts/mojo-ptx.sh "$S/$f.mojo" "$OUT/ptx-$f" > /dev/null
  done
fi

# --- PyTorch (optional) ------------------------------------------------------
if [[ "${TORCH_RUN:-0}" == 1 ]]; then
  python3 -c 'import torch; print("torch", torch.__version__)' >> "$OUT/VERSIONS.txt"
  python3 "$S/torch_strides.py" > "$OUT/torch_strides.txt"
  TORCH_LOGS="graph_code,output_code" python3 "$S/torch_compile_demo.py" > "$OUT/torch_compile.txt" 2>&1
fi

echo "Wrote $(find "$OUT" -type f | wc -l | tr -d ' ') files to $OUT/"
