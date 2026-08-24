#!/bin/zsh

find_mlx_metallib() {
  local build_root="$1"
  local project_root="${2:-}"
  local candidate
  local -a candidates

  candidates=(
    "$build_root/arm64-apple-macosx/release/mlx.metallib"
    "$build_root/release/mlx.metallib"
  )

  if [[ -n "$project_root" ]]; then
    candidates+=(
      "$project_root/../bench/.build/arm64-apple-macosx/debug/mlx.metallib"
      "$project_root/../bench/.build/debug/mlx.metallib"
    )
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}
