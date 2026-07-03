#!/usr/bin/env bash
# File and route a small repair task for bd-gc-dl managed functionality.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: gc bd-gc-dl file-fix-task --summary TEXT [options]

Create a task for the bd-gc-dl specialist agent and sling it immediately.

Options:
  --summary TEXT    Short symptom for the issue title. Required.
  --command TEXT    Failing command.
  --scope TEXT      Affected city, rig, repo, or bead scope.
  --evidence PATH   Evidence file or directory.
  --details TEXT    Extra context.
  --from-bead ID    Original bead blocked by the failure.
  --target NAME     Route target. Default: bd-gc-dl-fixer.
  --help            Show this help.
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

require_value() {
  if [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
    die "$1 requires a value"
  fi
}

json_field() {
  python3 -c '
import json
import sys

field = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
if isinstance(data, list):
    data = data[0] if data else {}
if not isinstance(data, dict):
    print("")
    raise SystemExit(0)
value = data.get(field, "")
print(value if isinstance(value, str) else str(value))
' "$1"
}

summary=""
command_text=""
scope=""
evidence=""
details=""
from_bead=""
target="bd-gc-dl-fixer"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --summary)
      require_value "$1" "${2:-}"
      summary="$2"
      shift 2
      ;;
    --command)
      require_value "$1" "${2:-}"
      command_text="$2"
      shift 2
      ;;
    --scope)
      require_value "$1" "${2:-}"
      scope="$2"
      shift 2
      ;;
    --evidence)
      require_value "$1" "${2:-}"
      evidence="$2"
      shift 2
      ;;
    --details)
      require_value "$1" "${2:-}"
      details="$2"
      shift 2
      ;;
    --from-bead)
      [ "$#" -ge 2 ] || die "$1 requires a value"
      from_bead="$2"
      shift 2
      ;;
    --target)
      require_value "$1" "${2:-}"
      target="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      die "unknown option: $1"
      ;;
    *)
      if [ -z "$summary" ]; then
        summary="$1"
        shift
      else
        die "unexpected argument: $1"
      fi
      ;;
  esac
done

[ -n "$summary" ] || {
  usage >&2
  exit 2
}

if ! command -v gc >/dev/null 2>&1; then
  die "gc is required"
fi
if ! command -v python3 >/dev/null 2>&1; then
  die "python3 is required"
fi

if [ -z "$evidence" ]; then
  mkdir -p .gc/diagnostics/bd-gc-dl
  evidence=".gc/diagnostics/bd-gc-dl/$(date -u +%Y%m%dT%H%M%SZ)-handoff.md"
  {
    printf '# bd-gc-dl failure handoff\n\n'
    printf 'summary: %s\n' "$summary"
    [ -n "$command_text" ] && printf 'command: %s\n' "$command_text"
    [ -n "$scope" ] && printf 'scope: %s\n' "$scope"
    [ -n "$from_bead" ] && printf 'from_bead: %s\n' "$from_bead"
    printf 'cwd: %s\n' "$PWD"
  } >"$evidence"
fi

description=$(cat <<EOF
Summary: $summary

Failing command: ${command_text:-unknown}
Affected scope: ${scope:-unknown}
Evidence: $evidence
Original bead: ${from_bead:-none}

Details:
${details:-none provided}
EOF
)

create_json=$(gc bd create "Fix bd-gc-dl managed failure: $summary" \
  --type=task \
  --description "$description" \
  --json)
bead_id=$(printf '%s' "$create_json" | json_field id)
[ -n "$bead_id" ] || die "could not parse created bead id"

gc sling "$target" "$bead_id"

printf 'BD_GC_DL_FIX_TASK=%s\n' "$bead_id"
printf 'BD_GC_DL_FIX_TARGET=%s\n' "$target"
printf 'BD_GC_DL_EVIDENCE=%s\n' "$evidence"
