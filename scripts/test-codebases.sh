#!/usr/bin/env bash
# Builds and tests every C++ codebase under codebases/, then runs the demos
# whose output the guide quotes. Build trees go to codebases/**/build/
# (git-ignored). Pass --asan to also run the suites under ASan + UBSan.
set -euo pipefail

cd "$(dirname "$0")/.."
ASAN=0
[[ "${1:-}" == "--asan" ]] && ASAN=1

build_and_test() {
  local src="$1" build="$1/build"
  echo "==> $src"
  cmake -S "$src" -B "$build" -DCMAKE_BUILD_TYPE=Debug >/dev/null
  cmake --build "$build" -j >/dev/null
  ctest --test-dir "$build" --output-on-failure | tail -n 3
  if [[ "$ASAN" == 1 ]]; then
    local abuild="$1/build-asan"
    cmake -S "$src" -B "$abuild" -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" >/dev/null
    cmake --build "$abuild" -j >/dev/null
    ctest --test-dir "$abuild" --output-on-failure | tail -n 3
  fi
}

build_and_test codebases/compiler-mechanics-cpp
for m in codebases/llvm-idioms-workbench/module*/; do
  build_and_test "${m%/}"
done

echo "==> demos"
for d in codebases/llvm-idioms-workbench/module*/build/module*-demo; do
  echo "--- $d"
  "$d" | head -n 8
done
