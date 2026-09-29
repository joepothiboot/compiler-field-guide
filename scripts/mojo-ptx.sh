#!/usr/bin/env bash
# Cross-compiles the GPU kernels in a Mojo file to PTX for an NVIDIA target,
# without needing an NVIDIA GPU. Usage: scripts/mojo-ptx.sh file.mojo outdir [sm_80]
set -euo pipefail
src="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
out="$2"
arch="${3:-sm_80}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
cd "$(dirname "$0")/.."
pixi run mojo build --emit asm --target-accelerator="$arch" "$src" \
  -o "$out/$(basename "$src" .mojo).host.s" 2>&1 | { grep -E "error" -A3 || true; }
ls "$out"/*.ptx
