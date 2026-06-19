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
PACK_NAME="${GC_PACKER_PACK:-${PACKER_PACK:-$AGENT_NAME}}"
EXTRA_PATTERNS="${GC_PACKER_SPARSE_ADD:-}"
TRIGGER_TITLE=""

show_trigger_bead_json() {
    bead_id="$1"
    if bd show "$bead_id" --json 2>/dev/null; then
        return 0
    fi
    if [ "${GC_TRIGGER_BEAD_STORE_REF:-}" = "city" ] && [ -n "${GC_CITY_ROOT:-}" ]; then
        BEADS_DIR="$GC_CITY_ROOT/.beads" GC_BEADS_SCOPE_ROOT="$GC_CITY_ROOT" bd show "$bead_id" --json 2>/dev/null
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
            echo "packer workspace setup: warning: could not read trigger bead $GC_TRIGGER_BEAD_ID; using configured pack" >&2
        fi
    else
        echo "packer workspace setup: warning: jq not found; cannot inspect trigger bead $GC_TRIGGER_BEAD_ID" >&2
    fi
fi

case "$PACK_NAME" in
    ""|.*|*/*|*' '*)
        echo "packer workspace setup: invalid pack name: $PACK_NAME" >&2
        exit 2
        ;;
esac

PACK_WORKSPACE_DIR="$(dirname "$TARGET_DIR")/$PACK_NAME"
PACK_WORKSPACE_PARENT=$(python3 - "$RIG_ROOT" "$(dirname "$PACK_WORKSPACE_DIR")" <<'PY'
import os, sys
print(os.path.relpath(os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[1])))
PY
)

workspace_setup="$SCRIPT_DIR/../../../jjw/assets/scripts/workspace-setup.sh"
if [ -n "${GC_TRIGGER_BEAD_ID:-}" ]; then
	if [ -n "$TRIGGER_TITLE" ]; then
		GC_JJW_WORKSPACE_DIR="$PACK_WORKSPACE_PARENT" "$workspace_setup" "$RIG_ROOT" "$PACK_WORKSPACE_DIR" "$PACK_NAME" --bead "$GC_TRIGGER_BEAD_ID" --title "$TRIGGER_TITLE" "$@"
	else
		GC_JJW_WORKSPACE_DIR="$PACK_WORKSPACE_PARENT" "$workspace_setup" "$RIG_ROOT" "$PACK_WORKSPACE_DIR" "$PACK_NAME" --bead "$GC_TRIGGER_BEAD_ID" "$@"
	fi
else
	GC_JJW_WORKSPACE_DIR="$PACK_WORKSPACE_PARENT" "$workspace_setup" "$RIG_ROOT" "$PACK_WORKSPACE_DIR" "$PACK_NAME" "$@"
fi

# `PACK_NAME` is the route/workspace key. `PACK_ROOT` is the resolved pack
# directory from Gas City's {{.PackRoot}} template. Convert it back into a jj
# sparse pattern relative to the rig root so layouts like:
#
#   pack = "jj-hunk"
#   pack_root = "{{.Pack}}"
#
# sparse-checkout `jj-hunk/`, while layouts like:
#
#   pack = "jj-hunk"
#   pack_root = "packs/{{.Pack}}"
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
rig_root = os.path.realpath(sys.argv[1])
pack_pattern = sys.argv[2].rstrip('/')
pack_toml = sys.argv[3]
pack_dir = os.path.dirname(os.path.realpath(pack_toml))

def is_remote_source(source):
    # Skip remote/URL imports explicitly. Anything with a URL scheme or git SSH
    # form is not a local pack directory and must not become a sparse pattern.
    if '://' in source:
        return True
    if source.startswith('git@'):
        return True
    return False

try:
    with open(pack_toml, 'rb') as f:
        data = tomllib.load(f)
except Exception:
    sys.exit(0)

imports = data.get('imports', {})
if not isinstance(imports, dict):
    sys.exit(0)
for key, val in imports.items():
    if isinstance(val, dict):
        source = val.get('source', '')
    elif isinstance(val, str):
        source = val
    else:
        continue
    if not isinstance(source, str) or not source.strip():
        continue
    if is_remote_source(source):
        continue
    if source.startswith('/'):
        abs_source = source
    else:
        abs_source = os.path.normpath(os.path.join(pack_dir, source))
    try:
        abs_source = os.path.realpath(abs_source)
    except OSError:
        continue
    # Validate that resolved local import paths live inside the rig root.
    try:
        common = os.path.commonpath([rig_root, abs_source])
    except ValueError:
        continue
    if common != rig_root:
        continue
    try:
        rel = os.path.relpath(abs_source, rig_root)
    except ValueError:
        continue
    # Avoid bogus sparse patterns from empty, current-dir, or parent-traversal paths.
    if not rel or rel == '.' or rel.startswith('..') or '/../' in rel + '/' or any(part == '..' for part in rel.split(os.sep)):
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
