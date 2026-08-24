#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/Scripts/metal_library.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/grotdown-metallib-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

if find_mlx_metallib "$TEST_ROOT" >/dev/null; then
  echo "expected an empty build tree to have no Metal library" >&2
  exit 1
fi

mkdir -p "$TEST_ROOT/release"
touch "$TEST_ROOT/release/mlx.metallib"

FOUND="$(find_mlx_metallib "$TEST_ROOT")"
if [[ "$FOUND" != "$TEST_ROOT/release/mlx.metallib" ]]; then
  echo "did not select the release Metal library" >&2
  exit 1
fi

echo "bundle Metal library checks passed"
