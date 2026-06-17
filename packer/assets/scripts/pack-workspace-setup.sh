#!/bin/sh
set -eu

RIG_ROOT="${1:?usage: pack-workspace-setup.sh <rig-root> <target-dir> <agent-name> [pack-root] [args...]}"
TARGET_DIR="${2:?missing target-dir}"
AGENT_NAME="${3:?missing agent-name}"
shift 3
PACK_ROOT="${1:-}"
case "$PACK_ROOT" in
    ""|--*) PACK_ROOT="" ;;
    *) shift ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACK_NAME="${GC_PACKER_PACK:-${PACKER_PACK:-$AGENT_NAME}}"
EXTRA_PATTERNS="${GC_PACKER_SPARSE_ADD:-}"

case "$PACK_NAME" in
    ""|.*|*/*|*' '*)
        echo "packer workspace setup: invalid pack name: $PACK_NAME" >&2
        exit 2
        ;;
esac

workspace_setup="$SCRIPT_DIR/../../../jjw/assets/scripts/workspace-setup.sh"
"$workspace_setup" "$RIG_ROOT" "$TARGET_DIR" "$AGENT_NAME" "$@"

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

set -- --clear
while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    set -- "$@" --add "$pattern"
done <"$patterns_file"

jj -R "$TARGET_DIR" sparse set "$@"
