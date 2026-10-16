#!/usr/bin/env bash
# Every check the CI runs: formatting, lint, and the examples built and swept.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Formatting (StyLua)"
stylua --check src examples templates

echo "==> Lint (Selene)"
selene src examples templates

echo "==> Examples build"
lune run examples/anim build > /dev/null

echo "==> Examples preview"
for name in $(lune run examples/anim list); do
	lune run examples/anim preview "$name" > /dev/null
done

echo "==> Everything is fine"
