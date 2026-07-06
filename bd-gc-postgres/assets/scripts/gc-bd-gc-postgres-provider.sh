#!/bin/sh
# Provider bridge for the plugin-backed Postgres Beads backend.

set -e

die() {
    echo "$@" >&2
    exit 1
}

custom_types_default="molecule,convoy,message,event,gate,merge-request,agent,role,rig,session,spec,convergence,step"

first_nonempty() {
    for name in "$@"; do
        eval "value=\${$name:-}"
        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    done
    return 1
}

sanitize_database() {
    python3 - "$1" <<'PY'
import re
import sys

raw = sys.argv[1].strip().lower()
name = re.sub(r"[^a-z0-9_]+", "_", raw)
name = re.sub(r"_+", "_", name).strip("_")
if not name:
    name = "beads"
if not re.match(r"^[a-z_]", name):
    name = "beads_" + name
print(name[:63])
PY
}

op_init() {
    dir="${1:-}"
    prefix="${2:-}"
    database="${3:-}"
    [ -n "$dir" ] && [ -n "$prefix" ] || die "usage: gc-bd-gc-postgres-provider init <dir> <prefix> [database]"
    command -v python3 >/dev/null 2>&1 || die "python3 is required for bd-gc-postgres provider init"

    postgres_url="$(first_nonempty GC_POSTGRES_URL BEADS_POSTGRES_URL || true)"
    [ -n "$postgres_url" ] || die "postgres backend requires GC_POSTGRES_URL or BEADS_POSTGRES_URL"

    postgres_schema="$(first_nonempty GC_POSTGRES_SCHEMA BEADS_POSTGRES_SCHEMA || true)"
    if [ -z "$postgres_schema" ] && [ -n "$database" ]; then
        postgres_schema="$(sanitize_database "$database")"
    fi
    if [ -z "$postgres_schema" ]; then
        postgres_schema="$(sanitize_database "$prefix")"
    fi

    postgres_password="$(first_nonempty GC_POSTGRES_PASSWORD BEADS_PG_PASSWORD || true)"
    if [ -n "$postgres_password" ] && [ -z "${BEADS_PG_PASSWORD:-}" ]; then
        export BEADS_PG_PASSWORD="$postgres_password"
    fi

    plugin_command="$(resolve_plugin_command)"
    [ -x "$plugin_command" ] || die "bd-gc-postgres backend plugin is not executable: $plugin_command"

    mkdir -p "$dir/.beads" "$dir/.gc"
    chmod 700 "$dir/.beads" 2>/dev/null || true

    city_root="$(resolve_city_root)"
    trace="${BEADS_BACKEND_POSTGRES_TRACE:-$city_root/.gc/backend-postgres-plugin-trace.jsonl}"
    custom_types="${GC_BEADS_CUSTOM_TYPES:-${BEADS_CUSTOM_TYPES:-$custom_types_default}}"
    plugin_init "$dir" "$prefix" "$postgres_schema" "$custom_types" "$plugin_command" "$trace"
    normalize_metadata "$dir" "$postgres_url" "$postgres_schema" "$plugin_command" "$trace"
    write_local_trust "$dir" "$plugin_command" "$trace"
}

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
    if [ -n "${GC_POSTGRES_BACKEND_PLUGIN_COMMAND:-}" ]; then
        printf '%s\n' "$GC_POSTGRES_BACKEND_PLUGIN_COMMAND"
        return 0
    fi
    city_root="$(resolve_city_root)"
    printf '%s\n' "$city_root/.gc/runtime/packs/bd-gc-postgres/bin/bd-backend-postgres"
}

plugin_init() {
    dir="$1"
    prefix="$2"
    schema="$3"
    custom_types="$4"
    command="$5"
    trace="$6"

    BEADS_POSTGRES_URL="$postgres_url" \
    GC_POSTGRES_SCHEMA="$schema" \
    python3 - "$command" "$dir/.beads" "$schema" "$prefix" "$custom_types" "$trace" <<'PY'
import json
import subprocess
import sys

command, beads_dir, schema, prefix, custom_types, trace = sys.argv[1:7]
proc = subprocess.Popen(
    [command, "--trace", trace, "serve"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
counter = 0

def call(method, params=None):
    global counter
    counter += 1
    req = {"id": f"gc-pg-{counter}", "method": method}
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
        "database": schema,
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

normalize_metadata() {
    dir="$1"
    dsn="$2"
    schema="$3"
    command="$4"
    trace="$5"

    python3 - "$dir" "$dsn" "$schema" "$command" "$trace" "$postgres_password" <<'PY'
import json
import os
import re
import sys
from urllib.parse import parse_qs, unquote, urlparse

dir_path, dsn, schema, command, trace, password = sys.argv[1:7]
metadata_path = os.path.join(dir_path, ".beads", "metadata.json")
args = ["--trace", trace, "serve"]

def parse_postgres_dsn(raw):
    raw = (raw or "").strip()
    out = {"host": "", "port": "", "user": "", "database": "", "password": ""}
    if raw.startswith(("postgres://", "postgresql://")):
        u = urlparse(raw)
        out["host"] = u.hostname or ""
        out["port"] = str(u.port or 5432)
        out["user"] = unquote(u.username or "")
        out["database"] = unquote((u.path or "").lstrip("/"))
        out["password"] = unquote(u.password or "")
        query = parse_qs(u.query)
        if not out["password"] and query.get("password"):
            out["password"] = query["password"][0]
        return out
    for key, value in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=('[^']*'|\\S+)", raw):
        value = value.strip("'")
        k = key.lower()
        if k == "host":
            out["host"] = value
        elif k == "port":
            out["port"] = value
        elif k == "user":
            out["user"] = value
        elif k == "dbname":
            out["database"] = value
        elif k == "password":
            out["password"] = value
    if not out["port"]:
        out["port"] = "5432"
    return out

parsed = parse_postgres_dsn(dsn)
with open(metadata_path, "r", encoding="utf-8") as f:
    metadata = json.load(f)

metadata.update({
    "database": metadata.get("database") or schema,
    "backend": "postgres",
    "postgres_host": parsed["host"],
    "postgres_port": parsed["port"],
    "postgres_user": parsed["user"],
    "postgres_database": parsed["database"] or schema,
    "backend_plugin_command": command,
    "backend_plugin_args": args,
})

with open(metadata_path, "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2, sort_keys=True)
    f.write("\n")
os.chmod(metadata_path, 0o600)

password = password or parsed["password"]
if password:
    env_path = os.path.join(dir_path, ".beads", ".env")
    quoted = "'" + password.replace("'", "'\"'\"'") + "'"
    with open(env_path, "w", encoding="utf-8") as f:
        f.write("BEADS_PG_PASSWORD=" + quoted + "\n")
    os.chmod(env_path, 0o600)
PY
}

write_local_trust() {
    dir="$1"
    command="$2"
    trace="$3"
    python3 - "$dir" "$command" "$trace" <<'PY'
import json
import os
import sys

dir_path, command, trace = sys.argv[1:4]
beads_dir = os.path.join(dir_path, ".beads")
local_cfg = os.path.join(beads_dir, "config.local.yaml")
args = ["--trace", trace, "serve"]
with open(local_cfg, "w", encoding="utf-8") as f:
    f.write("backend_plugins:\n")
    f.write("  postgres:\n")
    f.write(f"    command: {json.dumps(command)}\n")
    f.write(f"    args: {json.dumps(args)}\n")
os.chmod(local_cfg, 0o600)

gitignore = os.path.join(beads_dir, ".gitignore")
existing = ""
if os.path.exists(gitignore):
    with open(gitignore, "r", encoding="utf-8") as f:
        existing = f.read()
lines = set(existing.splitlines())
with open(gitignore, "a", encoding="utf-8") as f:
    if existing and not existing.endswith("\n"):
        f.write("\n")
    for entry in ("config.local.yaml", ".env"):
        if entry not in lines:
            f.write(entry + "\n")
os.chmod(gitignore, 0o600)
PY
}

op_health() {
    dir="${1:-.}"
    metadata="$dir/.beads/metadata.json"
    [ -f "$metadata" ] || die "postgres backend metadata not found: $metadata"
    python3 - "$metadata" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
if data.get("backend") != "postgres":
    raise SystemExit(f"metadata backend is {data.get('backend')!r}, want 'postgres'")
if not str(data.get("postgres_dsn", "")).strip():
    raise SystemExit("postgres metadata missing postgres_dsn")
if not str(data.get("postgres_schema", "")).strip():
    raise SystemExit("postgres metadata missing postgres_schema")
PY
}

case "${1:-}" in
    init)
        shift
        op_init "$@"
        ;;
    health|probe)
        shift
        op_health "$@"
        ;;
    start|ensure-ready|stop|shutdown|recover)
        exit 0
        ;;
    *)
        die "usage: gc-bd-gc-postgres-provider <init|health|probe|start|ensure-ready|stop|shutdown|recover> ..."
        ;;
esac
