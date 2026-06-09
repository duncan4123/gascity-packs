#!/bin/sh
# workspace-setup.sh — idempotent jj workspace creation for Gas City agents.
#
# Usage: workspace-setup.sh <rig-root> <target-dir> <agent-name> [--sync] [--bead <id>] [--title <title>] [--description <text>|--description-file <path>]
#
# Creates a jj workspace at <target-dir> linked to the rig repo at <rig-root>.
# Workspaces share the rig's commit graph so agents work in isolated sandboxes
# that can rebase into each other's lineages without merge commits.
#
# Base revision: resolves to the rig's default bookmark (origin/trunk) via jj.
# Falls back to the current working-copy revision if no remote bookmarks exist.
#
# Called from pre_start in pack configs. Runs before the session is created
# so the agent starts IN the workspace directory.

set -eu

RIG_ROOT="${1:?usage: workspace-setup.sh <rig-root> <target-dir> <agent-name> [--sync] [--bead <id>] [--title <title>] [--description <text>|--description-file <path>]}"
WT="${2:?missing target-dir}"
AGENT="${3:?missing agent-name}"
shift 3

SYNC=""
WORK_BEAD_ID="${LAZYJJ_WORK_BEAD_ID:-}"
WORK_TITLE="${LAZYJJ_WORK_TITLE:-}"
WORK_DESCRIPTION="${LAZYJJ_WORK_DESCRIPTION:-}"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --sync)
            SYNC="--sync"
            shift
            ;;
        --bead)
            WORK_BEAD_ID="${2:?--bead requires an id}"
            shift 2
            ;;
        --bead=*)
            WORK_BEAD_ID="${1#--bead=}"
            shift
            ;;
        --title)
            WORK_TITLE="${2:?--title requires text}"
            shift 2
            ;;
        --title=*)
            WORK_TITLE="${1#--title=}"
            shift
            ;;
        --description)
            WORK_DESCRIPTION="${2:?--description requires text}"
            shift 2
            ;;
        --description=*)
            WORK_DESCRIPTION="${1#--description=}"
            shift
            ;;
        --description-file)
            WORK_DESCRIPTION="$(cat "${2:?--description-file requires a path}")"
            shift 2
            ;;
        --description-file=*)
            WORK_DESCRIPTION="$(cat "${1#--description-file=}")"
            shift
            ;;
        *)
            echo "workspace-setup: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

explicit_bead_id() {
    if [ -n "$WORK_BEAD_ID" ]; then
        printf '%s\n' "$WORK_BEAD_ID"
        return 0
    fi
    return 1
}

write_bead_change_description() {
    bead_id="${1:-}"
    out="${2:?missing output path}"

    if [ -n "$WORK_TITLE" ]; then
        title=$(printf '%s' "$WORK_TITLE" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')
        body=$(printf '%s' "$WORK_DESCRIPTION" | sed '/^[[:space:]]*$/d')
        {
            printf 'work: %s\n' "$title"
            if [ -n "$body" ]; then
                printf '\n%s\n' "$body"
            fi
        } > "$out"
        return 0
    fi

    if [ -z "$bead_id" ] || ! command -v bd >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    bead_json=$(bd show "$bead_id" --json 2>/dev/null || true)
    if [ -z "$bead_json" ]; then
        return 1
    fi

    title=$(printf '%s' "$bead_json" | jq -r '.[0].title // .title // empty' 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')
    body=$(printf '%s' "$bead_json" | jq -r '.[0].description // .[0].notes // .description // .notes // empty' 2>/dev/null | sed '/^[[:space:]]*$/d')
    if [ -z "$title" ]; then
        title="$bead_id"
    fi

    {
        printf 'work: %s %s\n' "$bead_id" "$title"
        if [ -n "$body" ]; then
            printf '\n%s\n' "$body"
        fi
    } > "$out"
}

describe_workspace_change_from_bead() {
    if ! bead_id=$(explicit_bead_id); then
        return 0
    fi

    is_empty=$(jj -R "$WT" log -r @ --no-graph --template 'if(empty, "1", "0")' 2>/dev/null || printf '0')
    current_desc=$(jj -R "$WT" log -r @ --no-graph --template 'description.first_line()' 2>/dev/null || true)
    if [ "$is_empty" != "1" ] && [ -n "$current_desc" ]; then
        return 0
    fi

    desc_file=$(mktemp)
    if write_bead_change_description "$bead_id" "$desc_file"; then
        jj -R "$WT" describe --stdin < "$desc_file" >/dev/null 2>&1 || true
    fi
    rm -f "$desc_file"
}

write_workspace_runtime_files() {
    # Bead redirect: point .beads at the rig's bead store so bd commands work
    # from inside the workspace without a separate bead database.
    mkdir -p "$WT/.beads"
    echo "$RIG_ROOT/.beads" > "$WT/.beads/redirect"

    # Write .jjignore for Gas City runtime clutter.
    cat > "$WT/.jjignore" <<'JJIGNORE'
.beads/redirect
.beads/hooks/
.beads/formulas/
.logs/
.claude/
.codex/
.gemini/
.opencode/
.github/hooks/
.github/copilot-instructions.md
__pycache__/
state.json
JJIGNORE
}

# Idempotent: skip if workspace already exists.
if [ -d "$WT/.jj" ]; then
    write_workspace_runtime_files
    if [ "$SYNC" = "--sync" ]; then
        jj -R "$WT" git fetch 2>/dev/null || true
    fi
    describe_workspace_change_from_bead
    exit 0
fi

mkdir -p "$(dirname "$WT")"

# Stage any pre-existing content in the target directory so it isn't lost
# when jj checks out the workspace revision.
STAGE=""
if [ -d "$WT" ] && [ "$(find "$WT" -mindepth 1 -maxdepth 1 | head -n 1)" ]; then
    STAGE=$(mktemp -d "$(dirname "$WT")/.gascity-workspace-stage.XXXXXX")
    find "$WT" -mindepth 1 -maxdepth 1 -exec mv {} "$STAGE"/ \;
    trap 'restore_stage' EXIT HUP INT TERM
fi
rmdir "$WT" 2>/dev/null || true

restore_stage() {
    if [ -n "${STAGE:-}" ] && [ -d "$STAGE" ]; then
        find "$STAGE" -mindepth 1 -maxdepth 1 | while read -r f; do
            mv "$f" "$WT/" 2>/dev/null || true
        done
        rm -rf "$STAGE"
    fi
}

# Fetch latest from remotes so the workspace starts from a fresh revision.
jj -R "$RIG_ROOT" git fetch 2>/dev/null || true

# Resolve the base revision for the new workspace.
# Prefer trunk()@origin (jj's built-in default-branch revset).
# Fall back through common bookmark names, then the rig's current @.
REVSET=""
if jj -R "$RIG_ROOT" log -r 'trunk()@origin' --no-graph -T '' >/dev/null 2>&1; then
    REVSET="trunk()@origin"
else
    for candidate in main master trunk; do
        if jj -R "$RIG_ROOT" log -r "$candidate@origin" --no-graph -T '' >/dev/null 2>&1; then
            REVSET="$candidate@origin"
            break
        fi
    done
fi
if [ -z "$REVSET" ]; then
    REVSET="@"
fi

SAFE_AGENT=$(printf '%s' "$AGENT" | tr -c 'A-Za-z0-9._-' '-')
WT_HASH=$(printf '%s' "$WT" | cksum | awk '{print $1}')
WORKSPACE_NAME="${SAFE_AGENT}-${WT_HASH}"

if ! jj -R "$RIG_ROOT" workspace add --name "$WORKSPACE_NAME" "$WT" -r "$REVSET" --sparse-patterns full; then
    echo "workspace-setup: failed to create jj workspace at $WT from $RIG_ROOT (revset $REVSET)" >&2
    restore_stage
    exit 1
fi

# Merge staged non-repo content back into the workspace.
if [ -n "$STAGE" ]; then
    find "$STAGE" -mindepth 1 -maxdepth 1 | while read -r f; do
        rel="${f#$STAGE/}"
        if [ -d "$f" ]; then
            mv "$f" "$WT/$rel" 2>/dev/null || true
        else
            if [ ! -e "$WT/$rel" ]; then
                mv "$f" "$WT/$rel" 2>/dev/null || true
            fi
        fi
    done
    rm -rf "$STAGE"
    STAGE=""
fi
trap - EXIT HUP INT TERM

write_workspace_runtime_files
describe_workspace_change_from_bead

if [ "$SYNC" = "--sync" ]; then
    jj -R "$WT" git fetch 2>/dev/null || true
fi

exit 0
