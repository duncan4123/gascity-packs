#!/usr/bin/env bash
set -euo pipefail

PACK="${1:-}"
AGENT="${2:-}"
FORMULA="${3:-}"

if [[ -z "$PACK" ]]; then
  echo "usage: gc packer pack-check <pack> [agent] [formula]" >&2
  exit 2
fi

gc lint "$PACK"

if [[ -n "$AGENT" ]]; then
  gc prime "$AGENT" --strict >/dev/null
fi

if [[ -n "$FORMULA" ]]; then
  gc formula show "$FORMULA" >/dev/null
fi

echo "pack-check: ok"
