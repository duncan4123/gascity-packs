#!/bin/sh
set -eu

usage() {
    cat >&2 <<'EOF'
usage: create-pack-bead.sh --pack <pack> --title <title> [options]

Create a pack-routed implementation bead and sling it to packsmith.

Options:
  --pack <name>              Pack route key, for example jj-hunk
  --pack-root <path>         Pack directory relative to rig root (default: pack)
  --title <title>            Child bead title
  --description <text>       Child bead description
  --description-file <path>  Read child bead description from file
  --acceptance <text>        Acceptance criteria
  --parent <bead-id>         Parent/router bead
  --target <agent>           Sling target (default: <rig>/packer.packsmith)
  --dry-run                  Print commands without creating or slinging
EOF
}

PACK=""
PACK_ROOT=""
TITLE=""
DESCRIPTION=""
DESCRIPTION_FILE=""
ACCEPTANCE=""
PARENT=""
TARGET=""
DRY_RUN=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --pack)
            PACK="${2:-}"
            shift 2
            ;;
        --pack=*)
            PACK="${1#--pack=}"
            shift
            ;;
        --pack-root)
            PACK_ROOT="${2:-}"
            shift 2
            ;;
        --pack-root=*)
            PACK_ROOT="${1#--pack-root=}"
            shift
            ;;
        --title)
            TITLE="${2:-}"
            shift 2
            ;;
        --title=*)
            TITLE="${1#--title=}"
            shift
            ;;
        --description)
            DESCRIPTION="${2:-}"
            shift 2
            ;;
        --description=*)
            DESCRIPTION="${1#--description=}"
            shift
            ;;
        --description-file)
            DESCRIPTION_FILE="${2:-}"
            shift 2
            ;;
        --description-file=*)
            DESCRIPTION_FILE="${1#--description-file=}"
            shift
            ;;
        --acceptance)
            ACCEPTANCE="${2:-}"
            shift 2
            ;;
        --acceptance=*)
            ACCEPTANCE="${1#--acceptance=}"
            shift
            ;;
        --parent)
            PARENT="${2:-}"
            shift 2
            ;;
        --parent=*)
            PARENT="${1#--parent=}"
            shift
            ;;
        --target)
            TARGET="${2:-}"
            shift 2
            ;;
        --target=*)
            TARGET="${1#--target=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "create-pack-bead: unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
done

case "$PACK" in
    ""|.*|*/*|*' '*)
        echo "create-pack-bead: invalid or missing --pack: $PACK" >&2
        exit 2
        ;;
esac
if [ -z "$TITLE" ]; then
    echo "create-pack-bead: missing --title" >&2
    exit 2
fi
if [ -z "$PACK_ROOT" ]; then
    PACK_ROOT="$PACK"
fi

RIG_NAME="${GC_RIG:-}"
if [ -z "$RIG_NAME" ]; then
    RIG_NAME=$(basename "$(pwd -P)")
fi
if [ -z "$TARGET" ]; then
    TARGET="$RIG_NAME/packer.packsmith"
fi

metadata_file=$(mktemp)
trap 'rm -f "$metadata_file"' EXIT HUP INT TERM
python3 - "$metadata_file" "$PACK" "$PACK_ROOT" "$TARGET" <<'PY'
import json
import sys

path, pack, pack_root, target = sys.argv[1:5]
metadata = {
    "gc.pack": pack,
    "gc.pack_root": pack_root,
    "gc.formula": "mol-packer-work",
    "gc.route_target": target,
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(metadata, f, sort_keys=True)
PY

set -- create "$TITLE" --metadata "@$metadata_file" --silent
if [ -n "$DESCRIPTION_FILE" ]; then
    set -- "$@" --body-file "$DESCRIPTION_FILE"
elif [ -n "$DESCRIPTION" ]; then
    set -- "$@" --description "$DESCRIPTION"
fi
if [ -n "$ACCEPTANCE" ]; then
    set -- "$@" --acceptance "$ACCEPTANCE"
fi
if [ -n "$PARENT" ]; then
    set -- "$@" --parent "$PARENT"
fi

if [ -n "$DRY_RUN" ]; then
    printf 'bd'
    printf ' %s' "$@"
    printf '\n'
    printf 'gc sling %s <child-bead-id> --on mol-packer-work\n' "$TARGET"
    printf 'metadata: '
    cat "$metadata_file"
    printf '\n'
    exit 0
fi

child_id=$(bd "$@")
gc sling "$TARGET" "$child_id" --on mol-packer-work

if [ -n "$PARENT" ]; then
    bd note "$PARENT" "Created pack-routed child $child_id for pack $PACK -> $TARGET using mol-packer-work."
fi

printf '%s\n' "$child_id"
