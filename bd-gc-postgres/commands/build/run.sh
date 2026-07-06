#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: gc bd-gc-postgres build [backend] [--install] [--plugin-source DIR] [--output DIR]

Build the plugin-backed Postgres beads backend process.

Targets:
  backend   Build bd-backend-postgres (default)

Options:
  --plugin-source DIR   Standalone plugin source containing cmd/bd-backend-postgres.
                        Default: $BD_GC_POSTGRES_PLUGIN_SOURCE, else a cached
                        clone of duncan4123/beads-backend-postgres.
  --output DIR          Output directory. Default: pack runtime bin.
  --install             Kept for parity with other build packs; the output is
                        always written to the runtime bin directory unless
                        --output is supplied.
  --help                Show this help.
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

city_root="${GC_CITY_PATH:-$(pwd -P)}"
target="backend"
plugin_source="${BD_GC_POSTGRES_PLUGIN_SOURCE:-}"
output_dir="${BD_GC_POSTGRES_OUTPUT_DIR:-$city_root/.gc/runtime/packs/bd-gc-postgres/bin}"
plugin_repo="${BD_GC_POSTGRES_PLUGIN_REPO:-https://github.com/duncan4123/beads-backend-postgres.git}"
plugin_ref="${BD_GC_POSTGRES_PLUGIN_REF:-main}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    backend)
      target="$1"
      shift
      ;;
    --plugin-source)
      require_value "$1" "${2:-}"
      plugin_source="$2"
      shift 2
      ;;
    --output)
      require_value "$1" "${2:-}"
      output_dir="$2"
      shift 2
      ;;
    --install)
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[ "$target" = "backend" ] || die "unsupported target: $target"

if [ -z "$plugin_source" ]; then
  plugin_source="$city_root/.gc/cache/repos/beads-backend-postgres"
  if [ ! -d "$plugin_source/.git" ]; then
    command -v git >/dev/null 2>&1 || die "git is required to fetch $plugin_repo"
    mkdir -p "$(dirname "$plugin_source")"
    git clone "$plugin_repo" "$plugin_source"
  fi
  (
    cd "$plugin_source"
    git fetch --tags origin
    git checkout "$plugin_ref"
    git pull --ff-only origin "$plugin_ref" 2>/dev/null || true
  )
fi

[ -f "$plugin_source/go.mod" ] || die "plugin source missing go.mod: $plugin_source"
[ -d "$plugin_source/cmd/bd-backend-postgres" ] || die "plugin source missing cmd/bd-backend-postgres: $plugin_source"

mkdir -p "$output_dir"

cache_root="${BD_GC_POSTGRES_GO_CACHE_ROOT:-$city_root/.cache/go}"
mkdir -p "$cache_root/build" "$cache_root/mod" "$cache_root/tmp"

(
  cd "$plugin_source"
  GOCACHE="${GOCACHE:-$cache_root/build}" \
  GOMODCACHE="${GOMODCACHE:-$cache_root/mod}" \
  GOTMPDIR="${GOTMPDIR:-$cache_root/tmp}" \
  go build -o "$output_dir/bd-backend-postgres" ./cmd/bd-backend-postgres
)

chmod 755 "$output_dir/bd-backend-postgres"
echo "built $output_dir/bd-backend-postgres"
