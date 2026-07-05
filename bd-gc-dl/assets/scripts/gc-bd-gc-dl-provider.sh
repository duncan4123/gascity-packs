#!/bin/sh
# Provider bridge for the plugin-backed bd-gc-dl pack.
#
# The backend plugin owns DoltLite schema creation and migrations. This script
# only writes GC/Beads scope files and calls the trusted plugin init endpoint.

set -e

die() {
    echo "$@" >&2
    exit 1
}

custom_types_default="molecule,convoy,message,event,gate,merge-request,agent,role,rig,session,spec,convergence,step"

resolve_city_root() {
    if [ -n "${GC_CITY_PATH:-}" ]; then
        printf '%s\n' "$GC_CITY_PATH"
        return 0
    fi
    pwd -P
}

resolve_plugin_command() {
    if [ -n "${GC_BEADS_BACKEND_PLUGIN_COMMAND:-}" ]; then
        printf '%s\n' "$GC_BEADS_BACKEND_PLUGIN_COMMAND"
        return 0
    fi
    if [ -n "${GC_DOLTLITE_BACKEND_PLUGIN_COMMAND:-}" ]; then
        printf '%s\n' "$GC_DOLTLITE_BACKEND_PLUGIN_COMMAND"
        return 0
    fi
    city_root=$(resolve_city_root)
    printf '%s\n' "$city_root/.gc/runtime/packs/bd-gc-dl/bin/bd-backend-doltlite"
}

resolve_gascity_plugin_command() {
    if [ -n "${GC_GASCITY_BACKEND_PLUGIN_COMMAND:-}" ]; then
        printf '%s\n' "$GC_GASCITY_BACKEND_PLUGIN_COMMAND"
        return 0
    fi
    if [ -n "${GC_DOLTLITE_GASCITY_BACKEND_PLUGIN_COMMAND:-}" ]; then
        printf '%s\n' "$GC_DOLTLITE_GASCITY_BACKEND_PLUGIN_COMMAND"
        return 0
    fi
    city_root=$(resolve_city_root)
    printf '%s\n' "$city_root/.gc/runtime/packs/bd-gc-dl/bin/gc-doltlite-fastpath"
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

write_scope_files() {
    dir="$1"
    prefix="$2"
    database="$3"
    custom_types="$4"
    command="$5"
    trace="$6"
    gascity_command="$7"
    gascity_trace="$8"

    mkdir -p "$dir/.beads/doltlite" "$dir/.gc"
    chmod 700 "$dir/.beads" 2>/dev/null || true

    python3 - "$dir" "$prefix" "$database" "$custom_types" "$command" "$trace" "$gascity_command" "$gascity_trace" <<'PY'
import json
import os
import shlex
import sys

dir_path, prefix, database, custom_types, command, trace, gascity_command, gascity_trace = sys.argv[1:9]
beads_dir = os.path.join(dir_path, ".beads")
project_id = os.path.basename(os.path.abspath(dir_path)) or prefix
backend_args = shlex.split(os.environ.get("GC_BEADS_BACKEND_PLUGIN_ARGS") or os.environ.get("GC_DOLTLITE_BACKEND_PLUGIN_ARGS") or "serve")
if "--trace" not in backend_args:
    backend_args = ["--trace", trace] + backend_args
gascity_args = shlex.split(os.environ.get("GC_GASCITY_BACKEND_PLUGIN_ARGS") or os.environ.get("GC_DOLTLITE_GASCITY_BACKEND_PLUGIN_ARGS") or "serve")
if "--trace" not in gascity_args:
    gascity_args = ["--trace", gascity_trace] + gascity_args
metadata = {
    "attached_databases": [{"alias": "ops", "path": os.path.join(dir_path, ".gc", "ops.sqlite")}],
    "backend": "doltlite",
    "backend_plugin_args": backend_args,
    "backend_plugin_command": command,
    "database": "doltlite",
    "dolt_database": database,
    "gascity_backend_args": gascity_args,
    "gascity_backend_command": gascity_command,
    "project_id": project_id,
}
with open(os.path.join(beads_dir, "metadata.json"), "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2, sort_keys=True)
    f.write("\n")
os.chmod(os.path.join(beads_dir, "metadata.json"), 0o600)

with open(os.path.join(beads_dir, "config.yaml"), "w", encoding="utf-8") as f:
    f.write(f"issue_prefix: {prefix}\n")
    f.write(f"issue-prefix: {prefix}\n")
    f.write("dolt.auto-start: false\n")
    f.write("dolt:\n")
    f.write("  disable-event-flush: true\n")
    f.write("export.auto: false\n")
    f.write("backup.enabled: false\n")
    f.write(f"types.custom: {custom_types}\n")
os.chmod(os.path.join(beads_dir, "config.yaml"), 0o600)

local_cfg = os.path.join(beads_dir, "config.local.yaml")
with open(local_cfg, "w", encoding="utf-8") as f:
    f.write("backend_plugins:\n")
    f.write("  doltlite:\n")
    f.write(f"    command: {json.dumps(command)}\n")
    f.write(f"    args: {json.dumps(backend_args)}\n")
os.chmod(local_cfg, 0o600)

gitignore = os.path.join(beads_dir, ".gitignore")
existing = ""
if os.path.exists(gitignore):
    with open(gitignore, "r", encoding="utf-8") as f:
        existing = f.read()
if "config.local.yaml" not in existing.splitlines():
    with open(gitignore, "a", encoding="utf-8") as f:
        if existing and not existing.endswith("\n"):
            f.write("\n")
        f.write("config.local.yaml\n")
os.chmod(gitignore, 0o600)
PY
}

plugin_init() {
    dir="$1"
    prefix="$2"
    database="$3"
    custom_types="$4"
    command="$5"
    trace="$6"
    args="${GC_BEADS_BACKEND_PLUGIN_ARGS:-${GC_DOLTLITE_BACKEND_PLUGIN_ARGS:-serve}}"

    [ -x "$command" ] || die "bd-gc-dl backend plugin is not executable: $command"
    command -v python3 >/dev/null 2>&1 || die "python3 is required for bd-gc-dl provider init"

    python3 - "$command" "$args" "$dir/.beads" "$database" "$prefix" "$custom_types" "$trace" <<'PY'
import json
import shlex
import subprocess
import sys

command, args_text, beads_dir, database, prefix, custom_types, trace = sys.argv[1:8]
args = shlex.split(args_text or "serve")
if "--trace" not in args:
    args = ["--trace", trace] + args
proc = subprocess.Popen([command] + args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
counter = 0

def call(method, params=None):
    global counter
    counter += 1
    req = {"id": f"gc-{counter}", "method": method}
    if params is not None:
        req["params"] = params
    proc.stdin.write(json.dumps(req, separators=(",", ":")) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        raise SystemExit(f"backend plugin did not answer {method}: {proc.stderr.read().strip()}")
    resp = json.loads(line)
    if not resp.get("ok"):
        err = resp.get("error") or {}
        raise SystemExit(f"backend plugin {method} failed: {err.get('code', 'error')}: {err.get('message', '')}")
    return resp.get("result") or {}

try:
    hello = proc.stdout.readline()
    if not hello:
        raise SystemExit("backend plugin did not send hello: " + proc.stderr.read().strip())
    opened = call("init", {
        "beads_dir": beads_dir,
        "database": database,
        "branch": "main",
        "prefix": prefix,
        "actor": "gascity",
    })
    session_id = opened.get("session_id")
    if custom_types and session_id:
        tx = call("begin_transaction", {"session_id": session_id, "commit_msg": "gc init custom types"}).get("tx_id")
        call("tx_set_config", {"session_id": tx, "key": "types.custom", "value": custom_types})
        call("commit_transaction", {"tx_id": tx})
    if session_id:
        call("close", {"session_id": session_id})
finally:
    try:
        proc.stdin.close()
    except Exception:
        pass
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=5)
PY
}

op_init() {
    dir="${1:-}"
    prefix="${2:-}"
    database="${3:-$prefix}"
    [ -n "$dir" ] && [ -n "$prefix" ] || die "usage: gc-bd-gc-dl-provider init <dir> <prefix> [database]"
    custom_types="${GC_BEADS_CUSTOM_TYPES:-$custom_types_default}"
    command=$(resolve_plugin_command)
    gascity_command=$(resolve_gascity_plugin_command)
    city_root=$(resolve_city_root)
    trace="${GC_DOLTLITE_BACKEND_PLUGIN_TRACE:-$city_root/.gc/backend-plugin-trace.jsonl}"
    gascity_trace="${GC_DOLTLITE_GASCITY_BACKEND_PLUGIN_TRACE:-$city_root/.gc/gascity-backend-plugin-trace.jsonl}"

    write_scope_files "$dir" "$prefix" "$database" "$custom_types" "$command" "$trace" "$gascity_command" "$gascity_trace"
    plugin_init "$dir" "$prefix" "$database" "$custom_types" "$command" "$trace"
}

case "${1:-}" in
    init)
        shift
        op_init "$@"
        ;;
    start|ensure-ready|stop|shutdown|recover|health|probe)
        exit 0
        ;;
    *)
        die "usage: gc-bd-gc-dl-provider <init|start|ensure-ready|stop|shutdown|recover|health|probe> ..."
        ;;
esac
