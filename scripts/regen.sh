#!/usr/bin/env bash
# Regenerates every compiler output quoted in the guide from samples/.
# Output goes to samples/out/ (git-ignored). Compare it with the pages after a
# toolchain upgrade, then update the "Verified against" line on changed pages.
#
# Needs: Homebrew LLVM (clang, opt, llc, mlir-opt, mlir-translate).
# Optional: MOJO_PROJECT=<dir with a pixi.toml that pins mojo> for the Mojo sample.
set -euo pipefail

cd "$(dirname "$0")/.."
LLVM_BIN="${LLVM_BIN:-$(brew --prefix llvm)/bin}"
OUT=samples/out
mkdir -p "$OUT"

strip() { grep -v '^;\|^!\|^attributes\|^target\|^source_filename' || true; }

echo "LLVM $("$LLVM_BIN/llvm-config" --version)" > "$OUT/VERSIONS.txt"

# C -> LLVM IR (SSA form: -O0 then mem2reg only, so phis stay readable)
for f in max_or_zero vadd; do
  "$LLVM_BIN/clang" -O0 -Xclang -disable-O0-optnone -S -emit-llvm \
    "samples/$f.c" -o - 2>/dev/null \
    | "$LLVM_BIN/opt" -S -passes=mem2reg | strip > "$OUT/$f.ll"
done

# MLIR progressive lowering: scf -> cf -> llvm dialect -> LLVM IR
M=samples/max_or_zero.scf.mlir
"$LLVM_BIN/mlir-opt" "$M" --canonicalize > "$OUT/max_or_zero.canonical.mlir"
"$LLVM_BIN/mlir-opt" "$M" --convert-scf-to-cf > "$OUT/max_or_zero.cf.mlir"
"$LLVM_BIN/mlir-opt" "$M" --convert-scf-to-cf --convert-to-llvm \
  > "$OUT/max_or_zero.llvm.mlir"
"$LLVM_BIN/mlir-translate" --mlir-to-llvmir "$OUT/max_or_zero.llvm.mlir" \
  | strip > "$OUT/max_or_zero.from-mlir.ll"
"$LLVM_BIN/mlir-opt" samples/max_or_zero.blockargs.mlir > "$OUT/max_or_zero.blockargs.out.mlir"
"$LLVM_BIN/mlir-opt" samples/vadd.mlir --convert-scf-to-cf > "$OUT/vadd.cf.mlir"

# GPU kernel: LLVM IR -> PTX
"$LLVM_BIN/llc" -mcpu=sm_80 samples/vadd_gpu.ll -o - | grep -v '^//' > "$OUT/vadd_gpu.ptx"

# Mojo (optional)
if [[ -n "${MOJO_PROJECT:-}" ]]; then
  SAMPLE="$PWD/samples/vadd.mojo"
  (cd "$MOJO_PROJECT" && pixi run mojo --version && pixi run mojo run "$SAMPLE") \
    > "$OUT/vadd.mojo.txt" 2>&1
fi

echo "Wrote $(ls "$OUT" | wc -l | tr -d ' ') files to $OUT/"
