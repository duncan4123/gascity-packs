#!/bin/sh
set -eu

RIG_ROOT="${1:-}"
case "$RIG_ROOT" in
    ""|--*) RIG_ROOT="${GC_RIG_ROOT:-}" ;;
    *) shift ;;
esac
if [ -z "$RIG_ROOT" ]; then
    echo "usage: pack-workspace-setup.sh <rig-root> <target-dir> <agent-name> [pack-root] [args...]" >&2
    echo "packer workspace setup: missing rig root; pass it or set GC_RIG_ROOT" >&2
    exit 2
fi

TARGET_DIR="${1:-}"
case "$TARGET_DIR" in
    ""|--*) TARGET_DIR="${GC_DIR:-}" ;;
    *) shift ;;
esac
if [ -z "$TARGET_DIR" ]; then
    echo "packer workspace setup: missing target dir; pass it or set GC_DIR" >&2
    exit 2
fi

default_agent="${GC_AGENT:-${GC_TEMPLATE:-}}"
default_agent="${default_agent##*/}"
AGENT_NAME="${1:-}"
case "$AGENT_NAME" in
    ""|--*) AGENT_NAME="$default_agent" ;;
    *) shift ;;
esac
if [ -z "$AGENT_NAME" ]; then
    echo "packer workspace setup: missing agent name; pass it or set GC_AGENT" >&2
    exit 2
fi

PACK_ROOT="${1:-}"
case "$PACK_ROOT" in
    ""|--*) PACK_ROOT="" ;;
    *) shift ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACK_NAME="${GC_PACKER_PACK:-${PACKER_PACK:-}}"
EXTRA_PATTERNS="${GC_PACKER_SPARSE_ADD:-}"
TRIGGER_TITLE=""

show_trigger_bead_json() {
    bead_id="$1"
    if bd show "$bead_id" --json 2>/dev/null; then
        return 0
    fi
    case "${GC_TRIGGER_BEAD_STORE_REF:-}" in
        city)
            if [ -n "${GC_CITY_ROOT:-}" ]; then
                BEADS_DIR="$GC_CITY_ROOT/.beads" GC_BEADS_SCOPE_ROOT="$GC_CITY_ROOT" bd show "$bead_id" --json 2>/dev/null
                return $?
            fi
            ;;
        rig:*)
            if [ -n "${GC_RIG_ROOT:-}" ]; then
                BEADS_DIR="$GC_RIG_ROOT/.beads" GC_BEADS_SCOPE_ROOT="$GC_RIG_ROOT" bd show "$bead_id" --json 2>/dev/null
                return $?
            fi
            ;;
    esac
    if [ -n "${GC_RIG_ROOT:-}" ]; then
        BEADS_DIR="$GC_RIG_ROOT/.beads" GC_BEADS_SCOPE_ROOT="$GC_RIG_ROOT" bd show "$bead_id" --json 2>/dev/null
        return $?
    fi
    return 1
}

if [ -n "${GC_TRIGGER_BEAD_ID:-}" ]; then
    if command -v jq >/dev/null 2>&1; then
        if trigger_json=$(show_trigger_bead_json "$GC_TRIGGER_BEAD_ID"); then
            trigger_pack=$(printf '%s' "$trigger_json" | jq -r '((if type == "array" then .[0] else . end).metadata // {})["gc.pack"] // empty' 2>/dev/null || printf '')
            trigger_pack_root=$(printf '%s' "$trigger_json" | jq -r '((if type == "array" then .[0] else . end).metadata // {})["gc.pack_root"] // empty' 2>/dev/null || printf '')
            TRIGGER_TITLE=$(printf '%s' "$trigger_json" | jq -r '(if type == "array" then .[0] else . end).title // empty' 2>/dev/null || printf '')
            if [ -n "$trigger_pack" ]; then
                PACK_NAME="$trigger_pack"
            fi
            if [ -n "$trigger_pack_root" ]; then
                PACK_ROOT="$trigger_pack_root"
            fi
        else
            echo "packer workspace setup: warning: could not read trigger bead $GC_TRIGGER_BEAD_ID; using configured pack fallback" >&2
        fi
    else
        echo "packer workspace setup: warning: jq not found; cannot inspect trigger bead $GC_TRIGGER_BEAD_ID" >&2
    fi
fi

case "$PACK_NAME" in
    ""|.*|*/*|*' '*)
        echo "packer workspace setup: missing or invalid pack name: $PACK_NAME" >&2
        echo "packer workspace setup: routed beads must set gc.pack; manual runs may set GC_PACKER_PACK" >&2
        exit 2
        ;;
esac

PACK_WORKSPACE_DIR="$TARGET_DIR"
PACK_WORKSPACE_NAME=$(basename "$PACK_WORKSPACE_DIR")
PACK_WORKSPACE_PARENT=$(python3 - "$RIG_ROOT" "$(dirname "$PACK_WORKSPACE_DIR")" <<'PY'
import os, sys
print(os.path.relpath(os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[1])))
PY
)
PACK_WORKSPACE_PARENT_NAME=$(basename "$(dirname "$PACK_WORKSPACE_DIR")")
GC_JJW_WORKSPACE_DIR="$PACK_WORKSPACE_PARENT"
export GC_JJW_WORKSPACE_DIR
if [ -z "${GC_JJW_BOOKMARK_PATTERN:-}" ] && [ "$PACK_WORKSPACE_PARENT_NAME" = "$PACK_NAME" ]; then
	GC_JJW_BOOKMARK_PATTERN="gc/$PACK_NAME.{name}"
	export GC_JJW_BOOKMARK_PATTERN
fi

workspace_setup="$SCRIPT_DIR/../../../jjw/assets/scripts/workspace-setup.sh"
if [ -n "${GC_TRIGGER_BEAD_ID:-}" ]; then
	if [ -n "$TRIGGER_TITLE" ]; then
		"$workspace_setup" "$RIG_ROOT" "$PACK_WORKSPACE_DIR" "$PACK_WORKSPACE_NAME" --bead "$GC_TRIGGER_BEAD_ID" --title "$TRIGGER_TITLE" "$@"
	else
		"$workspace_setup" "$RIG_ROOT" "$PACK_WORKSPACE_DIR" "$PACK_WORKSPACE_NAME" --bead "$GC_TRIGGER_BEAD_ID" "$@"
	fi
else
	"$workspace_setup" "$RIG_ROOT" "$PACK_WORKSPACE_DIR" "$PACK_WORKSPACE_NAME" "$@"
fi

# `PACK_NAME` is the route/workspace key. `PACK_ROOT` is the resolved pack
# directory from trigger bead metadata. Convert it back into a jj sparse
# pattern relative to the rig root so metadata like:
#
#   gc.pack=jj-hunk
#   gc.pack_root=jj-hunk
#
# sparse-checkout `jj-hunk/`, while layouts like:
#
#   gc.pack=jj-hunk
#   gc.pack_root=packs/jj-hunk
#
# sparse-checkout `packs/jj-hunk/`.
if [ -z "$PACK_ROOT" ]; then
    PACK_ROOT="$RIG_ROOT/$PACK_NAME"
fi
case "$PACK_ROOT" in
    "$RIG_ROOT"/*)
        PACK_PATTERN="${PACK_ROOT#"$RIG_ROOT"/}"
        ;;
    "$RIG_ROOT")
        echo "packer workspace setup: pack root must name a pack directory, got rig root: $PACK_ROOT" >&2
        exit 2
        ;;
    /*)
        echo "packer workspace setup: pack root is outside rig root: $PACK_ROOT" >&2
        exit 2
        ;;
    *)
        PACK_PATTERN="$PACK_ROOT"
        ;;
esac
if [ -z "$PACK_PATTERN" ]; then
    echo "packer workspace setup: empty sparse pack pattern for pack $PACK_NAME" >&2
    exit 2
fi
case "$PACK_PATTERN" in
    */) ;;
    *) PACK_PATTERN="$PACK_PATTERN/" ;;
esac

patterns_file=$(mktemp)
trap 'rm -f "$patterns_file"' EXIT HUP INT TERM

cat >"$patterns_file" <<EOF
$PACK_PATTERN
README.md
registry.toml
validate_registry.py
go.mod
.gitignore
tests/
EOF

if [ -n "$EXTRA_PATTERNS" ]; then
    printf '%s\n' "$EXTRA_PATTERNS" >>"$patterns_file"
fi

# Add imported pack directories to the sparse checkout so `gc lint` can resolve
# pack.toml imports and helper scripts can reference sibling pack assets.
pack_toml="$RIG_ROOT/$PACK_PATTERN/pack.toml"
if [ -f "$pack_toml" ]; then
    python3 - "$RIG_ROOT" "$PACK_PATTERN" "$pack_toml" <<'PY' >>"$patterns_file"
import os, sys, tomllib
rig_root = sys.argv[1]
pack_pattern = sys.argv[2].rstrip('/')
pack_toml = sys.argv[3]
pack_dir = os.path.dirname(os.path.abspath(pack_toml))
try:
    with open(pack_toml, 'rb') as f:
        data = tomllib.load(f)
except Exception:
    sys.exit(0)
imports = data.get('imports', {})
for key, val in imports.items():
    source = val.get('source', '') if isinstance(val, dict) else val
    if not source:
        continue
    if source.startswith('/'):
        abs_source = source
    else:
        abs_source = os.path.normpath(os.path.join(pack_dir, source))
    try:
        rel = os.path.relpath(abs_source, os.path.abspath(rig_root))
    except ValueError:
        continue
    if rel.startswith('..'):
        continue
    print(rel.rstrip('/') + '/')
PY
fi

set -- --clear
while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    set -- "$@" --add "$pattern"
done <"$patterns_file"

jj -R "$PACK_WORKSPACE_DIR" sparse set "$@"
