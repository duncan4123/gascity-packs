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

scope_postgres_database() {
    explicit="$(first_nonempty GC_POSTGRES_DATABASE BEADS_POSTGRES_DATABASE || true)"
    if [ -n "$explicit" ]; then
        sanitize_database "$explicit"
        return 0
    fi

    city_database="$(city_metadata_value postgres_database || true)"
    if [ -z "$city_database" ]; then
        city_database="gc_$(sanitize_database "$(basename "$(resolve_city_root)")")"
    fi
    city_database="$(sanitize_database "$city_database")"

    scope_kind="$(first_nonempty GC_BEADS_SETUP_SCOPE_KIND GC_BEADS_SCOPE_KIND || true)"
    scope_resource="$(first_nonempty GC_BEADS_SCOPE_RESOURCE || true)"
    namespace="$(first_nonempty GC_BEADS_SETUP_NAMESPACE GC_BEADS_SCOPE_NAMESPACE || true)"
    if [ -z "$namespace" ]; then
        namespace="${1:-}"
    fi
    namespace="$(sanitize_database "$namespace")"

    if [ "$scope_resource" = "database" ] && [ "$scope_kind" != "city" ] && [ -n "$namespace" ]; then
        sanitize_database "${city_database}_${namespace}"
        return 0
    fi
    printf '%s\n' "$city_database"
}

city_metadata_value() {
    key="$1"
    city_root="$(resolve_city_root)"
    metadata="$city_root/.beads/metadata.json"
    [ -f "$metadata" ] || return 1
    python3 - "$metadata" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1:3]
with open(path, "r", encoding="utf-8") as f:
    value = json.load(f).get(key) or ""
if value:
    print(value)
PY
}

postgres_url_with_password() {
    dsn="$1"
    password="$2"
    [ -n "$password" ] || {
        printf '%s\n' "$dsn"
        return 0
    }
    python3 - "$dsn" "$password" <<'PY'
import sys
from urllib.parse import quote, urlparse, urlunparse

dsn, password = sys.argv[1:3]
if not dsn.startswith(("postgres://", "postgresql://")):
    print(dsn)
    raise SystemExit(0)
u = urlparse(dsn)
if u.password:
    print(dsn)
    raise SystemExit(0)
host = u.hostname or ""
if ":" in host and not host.startswith("["):
    host = f"[{host}]"
if u.port:
    host = f"{host}:{u.port}"
if u.username:
    netloc = f"{quote(u.username)}:{quote(password)}@{host}"
else:
    netloc = host
print(urlunparse((u.scheme, netloc, u.path, u.params, u.query, u.fragment)))
PY
}

postgres_dsn_has_password() {
    dsn="$1"
    python3 - "$dsn" <<'PY'
import re
import sys
from urllib.parse import parse_qs, urlparse

dsn = sys.argv[1]
has_password = False
if dsn.startswith(("postgres://", "postgresql://")):
    u = urlparse(dsn)
    has_password = bool(u.password)
    if not has_password:
        has_password = bool(parse_qs(u.query).get("password"))
else:
    has_password = bool(re.search(r"(^|\\s)password=('[^']*'|\\S+)", dsn, re.I))
raise SystemExit(0 if has_password else 1)
PY
}

generate_postgres_password() {
    python3 - <<'PY'
import secrets

print(secrets.token_urlsafe(32))
PY
}

provision_local_postgres() {
    schema="$1"
    app_database="$(scope_postgres_database "$schema")"

    app_user="$(first_nonempty GC_POSTGRES_USER BEADS_POSTGRES_USER || true)"
    if [ -z "$app_user" ]; then
        app_user="$(city_metadata_value postgres_user || true)"
    fi
    if [ -z "$app_user" ]; then
        app_user="$app_database"
    else
        app_user="$(sanitize_database "$app_user")"
    fi

    app_host="$(first_nonempty GC_POSTGRES_HOST BEADS_POSTGRES_HOST || true)"
    if [ -z "$app_host" ]; then
        app_host="$(city_metadata_value postgres_host || true)"
    fi
    [ -n "$app_host" ] || app_host="127.0.0.1"
    app_port="$(first_nonempty GC_POSTGRES_PORT BEADS_POSTGRES_PORT || true)"
    if [ -z "$app_port" ]; then
        app_port="$(city_metadata_value postgres_port || true)"
    fi
    [ -n "$app_port" ] || app_port="5432"

    postgres_password="$(first_nonempty GC_POSTGRES_PASSWORD BEADS_PG_PASSWORD || true)"
    [ -n "$postgres_password" ] || postgres_password="$(generate_postgres_password)"
    export BEADS_PG_PASSWORD="$postgres_password"

    command -v psql >/dev/null 2>&1 || die "postgres backend local provisioning requires psql"
    python3 - "$app_database" "$app_user" "$postgres_password" "$schema" "$app_host" "$app_port" <<'PY'
import os
import re
import subprocess
import sys
from urllib.parse import urlparse, urlunparse

database, user, password, schema, host, port = sys.argv[1:7]
admin_url = os.environ.get("GC_POSTGRES_ADMIN_URL") or os.environ.get("BEADS_POSTGRES_ADMIN_URL")
name_re = re.compile(r"^[a-z_][a-z0-9_]{0,62}$")

for kind, value in (("database", database), ("user", user), ("schema", schema)):
    if not name_re.match(value):
        raise SystemExit(f"invalid postgres {kind} name after sanitization: {value!r}")

def ident(value):
    return '"' + value.replace('"', '""') + '"'

def lit(value):
    return "'" + value.replace("'", "''") + "'"

def admin_dsn(dbname):
    if not admin_url:
        return None
    parsed = urlparse(admin_url)
    if not parsed.scheme:
        return admin_url
    return urlunparse((parsed.scheme, parsed.netloc, "/" + dbname, parsed.params, parsed.query, parsed.fragment))

def psql_cmd(dbname, quiet=True, tuples_only=False):
    cmd = ["psql", "-X", "-v", "ON_ERROR_STOP=1"]
    if quiet:
        cmd.append("-q")
    if tuples_only:
        cmd.append("-At")
    dsn = admin_dsn(dbname)
    if dsn:
        cmd.append(dsn)
    else:
        cmd.extend(["-d", dbname])
    return cmd

def run(dbname, sql):
    subprocess.run(psql_cmd(dbname), input=sql, text=True, check=True)

def scalar(dbname, sql):
    out = subprocess.check_output(psql_cmd(dbname, tuples_only=True), input=sql, text=True)
    return out.strip()

if scalar("postgres", f"SELECT 1 FROM pg_roles WHERE rolname = {lit(user)}") == "1":
    run("postgres", f"ALTER ROLE {ident(user)} WITH LOGIN PASSWORD {lit(password)};\n")
else:
    run("postgres", f"CREATE ROLE {ident(user)} LOGIN PASSWORD {lit(password)};\n")

if scalar("postgres", f"SELECT 1 FROM pg_database WHERE datname = {lit(database)}") != "1":
    run("postgres", f"CREATE DATABASE {ident(database)} OWNER {ident(user)} TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C';\n")
else:
    run("postgres", f"ALTER DATABASE {ident(database)} OWNER TO {ident(user)};\n")

run(database, "\n".join([
    f"CREATE SCHEMA IF NOT EXISTS {ident(schema)} AUTHORIZATION {ident(user)};",
    f"ALTER SCHEMA {ident(schema)} OWNER TO {ident(user)};",
    f"GRANT ALL PRIVILEGES ON DATABASE {ident(database)} TO {ident(user)};",
    f"GRANT USAGE, CREATE ON SCHEMA {ident(schema)} TO {ident(user)};",
    "",
]))
PY
    echo "bd-gc-postgres: provisioned local Postgres database \"$app_database\" role \"$app_user\" schema \"$schema\"" >&2
    provisioned_postgres_url="postgres://$app_user@$app_host:$app_port/$app_database?sslmode=disable"
}

load_city_password_env() {
    city_root="$(resolve_city_root)"
    env_file="$city_root/.beads/.env"
    [ -f "$env_file" ] || return 0
    # The provider writes this file itself with a single shell-quoted password.
    # shellcheck disable=SC1090
    . "$env_file"
    if [ -n "${BEADS_PG_PASSWORD:-}" ]; then
        export BEADS_PG_PASSWORD
    fi
}

op_init() {
    dir="${1:-}"
    prefix="${2:-}"
    database="${3:-}"
    [ -n "$dir" ] && [ -n "$prefix" ] || die "usage: gc-bd-gc-postgres-provider init <dir> <prefix> [database]"
    command -v python3 >/dev/null 2>&1 || die "python3 is required for bd-gc-postgres provider init"

    load_city_password_env

    postgres_schema="$(first_nonempty GC_POSTGRES_SCHEMA BEADS_POSTGRES_SCHEMA || true)"
    if [ -z "$postgres_schema" ]; then
        postgres_schema="$(first_nonempty GC_BEADS_SETUP_NAMESPACE GC_BEADS_SCOPE_NAMESPACE || true)"
    fi
    if [ -z "$postgres_schema" ] && [ -n "$database" ]; then
        postgres_schema="$(sanitize_database "$database")"
    fi
    if [ -z "$postgres_schema" ]; then
        postgres_schema="$(city_metadata_value postgres_schema || true)"
    fi
    if [ -z "$postgres_schema" ]; then
        postgres_schema="$(sanitize_database "$prefix")"
    fi

    postgres_url_source=""
    postgres_url="$(first_nonempty GC_POSTGRES_URL BEADS_POSTGRES_URL || true)"
    if [ -n "$postgres_url" ]; then
        postgres_url_source="env"
    fi
    if [ -z "$postgres_url" ]; then
        postgres_url="$(city_metadata_value postgres_dsn || true)"
        if [ -n "$postgres_url" ]; then
            postgres_url_source="metadata"
        fi
    fi

    postgres_password="$(first_nonempty GC_POSTGRES_PASSWORD BEADS_PG_PASSWORD || true)"
    if [ -n "$postgres_password" ] && [ -z "${BEADS_PG_PASSWORD:-}" ]; then
        export BEADS_PG_PASSWORD="$postgres_password"
    fi

    mkdir -p "$dir/.beads" "$dir/.gc"
    chmod 700 "$dir/.beads" 2>/dev/null || true

    plugin_command="$(resolve_plugin_command)"
    gascity_plugin_command="$(resolve_gascity_plugin_command)"
    prepare_plugin_command_if_missing "$plugin_command"
    prepare_plugin_command_if_missing "$gascity_plugin_command"
    [ -x "$plugin_command" ] || die "bd-gc-postgres backend plugin is not executable: $plugin_command"
    [ -x "$gascity_plugin_command" ] || die "bd-gc-postgres gascity backend plugin is not executable: $gascity_plugin_command"

    if [ "$postgres_url_source" = "metadata" ] && [ -z "$postgres_password" ] && ! postgres_dsn_has_password "$postgres_url"; then
        postgres_url=""
    fi
    scope_resource="$(first_nonempty GC_BEADS_SCOPE_RESOURCE || true)"
    explicit_postgres_url="$(first_nonempty GC_POSTGRES_URL BEADS_POSTGRES_URL || true)"
    provision_scope_database=false
    if [ "$scope_resource" = "database" ] && [ -z "$explicit_postgres_url" ]; then
        provision_scope_database=true
    fi
    if [ -z "$postgres_url" ] || [ "$provision_scope_database" = "true" ]; then
        provision_local_postgres "$postgres_schema"
        postgres_url="$provisioned_postgres_url"
        postgres_password="${BEADS_PG_PASSWORD:-$postgres_password}"
    fi
    postgres_url="$(postgres_url_with_password "$postgres_url" "$postgres_password")"

    city_root="$(resolve_city_root)"
    trace="${BEADS_BACKEND_POSTGRES_TRACE:-$city_root/.gc/backend-postgres-plugin-trace.jsonl}"
    gascity_trace="${GASCITY_BACKEND_POSTGRES_TRACE:-$city_root/.gc/backend-postgres-gascity-trace.jsonl}"
    custom_types="${GC_BEADS_CUSTOM_TYPES:-${BEADS_CUSTOM_TYPES:-$custom_types_default}}"
    plugin_init "$dir" "$prefix" "$postgres_schema" "$custom_types" "$plugin_command" "$trace"
    normalize_metadata "$dir" "$postgres_url" "$postgres_schema" "$plugin_command" "$trace" "$gascity_plugin_command" "$gascity_trace"
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

resolve_gascity_plugin_command() {
    if [ -n "${GC_GASCITY_BACKEND_PLUGIN_COMMAND:-}" ]; then
        printf '%s\n' "$GC_GASCITY_BACKEND_PLUGIN_COMMAND"
        return 0
    fi
    if [ -n "${GC_POSTGRES_GASCITY_PLUGIN_COMMAND:-}" ]; then
        printf '%s\n' "$GC_POSTGRES_GASCITY_PLUGIN_COMMAND"
        return 0
    fi
    city_root="$(resolve_city_root)"
    printf '%s\n' "$city_root/.gc/runtime/packs/bd-gc-postgres/bin/gc-backend-postgres"
}

prepare_plugin_command_if_missing() {
    command_path="$1"
    [ -x "$command_path" ] && return 0

    script_path="$0"
    case "$script_path" in
        */*) ;;
        *) return 0 ;;
    esac
    script_dir="$(CDPATH= cd "$(dirname "$script_path")" 2>/dev/null && pwd -P)" || return 0
    pack_root="$(CDPATH= cd "$script_dir/../.." 2>/dev/null && pwd -P)" || return 0
    build_script="$pack_root/commands/build/run.sh"
    [ -x "$build_script" ] || return 0

    city_root="$(resolve_city_root)"
    echo "bd-gc-postgres: backend plugin missing; running pack prepare command" >&2
    GC_CITY_PATH="$city_root" "$build_script" backend --install
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
    gascity_command="$6"
    gascity_trace="$7"

    python3 - "$dir" "$dsn" "$schema" "$command" "$trace" "$gascity_command" "$gascity_trace" "$postgres_password" <<'PY'
import json
import os
import re
import sys
from urllib.parse import parse_qs, unquote, urlparse
from urllib.parse import quote, urlunparse

dir_path, dsn, schema, command, trace, gascity_command, gascity_trace, password = sys.argv[1:9]
metadata_path = os.path.join(dir_path, ".beads", "metadata.json")
args = ["--trace", trace, "serve"]
gascity_args = ["--trace", gascity_trace, "serve"]

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

def metadata_postgres_dsn(raw):
    raw = (raw or "").strip()
    if raw.startswith(("postgres://", "postgresql://")):
        u = urlparse(raw)
        host = u.hostname or ""
        if ":" in host and not host.startswith("["):
            host = f"[{host}]"
        if u.port:
            host = f"{host}:{u.port}"
        netloc = host
        if u.username:
            netloc = f"{quote(unquote(u.username))}@{host}"
        return urlunparse((u.scheme, netloc, u.path, u.params, u.query, u.fragment))
    if not raw:
        return raw
    parts = []
    for key, value in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=('[^']*'|\\S+)", raw):
        if key.lower() == "password":
            continue
        parts.append(f"{key}={value}")
    return " ".join(parts) if parts else raw

parsed = parse_postgres_dsn(dsn)
with open(metadata_path, "r", encoding="utf-8") as f:
    metadata = json.load(f)

metadata.update({
    "database": schema,
    "backend": "postgres",
    "postgres_dsn": metadata_postgres_dsn(dsn),
    "postgres_schema": schema,
    "postgres_host": parsed["host"],
    "postgres_port": parsed["port"],
    "postgres_user": parsed["user"],
    "postgres_database": parsed["database"] or schema,
    "backend_plugin_command": command,
    "backend_plugin_args": args,
    "gascity_backend_command": gascity_command,
    "gascity_backend_args": gascity_args,
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
