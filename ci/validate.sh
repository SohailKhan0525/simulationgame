#!/usr/bin/env bash
set -euo pipefail
engine=${GODOT:-godot}
log=$(mktemp)
trap 'rm -f "$log"' EXIT
check() {
  "$engine" --headless "$@" 2>&1 | tee "$log"
  if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:' "$log"; then exit 1; fi
}
check --editor --import
check --quit-after 5
check --script res://tests/suite.gd
check --script res://tests/conservation.gd
