#!/usr/bin/env bash
# Build the plugin-backed DoltLite bd/gc binary set.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: gc bd-gc-dl build [bd|gc|bd-backend|gc-backend|gc-helper|backend|client|all] [options]

Build plugin-backed bd/gc binaries and DoltLite backend plugin processes.
The default target is all.

Targets:
  bd          Build the normal bd CLI.
  gc          Build the normal gc CLI.
  bd-backend  Build bd-backend-doltlite.
  gc-backend  Build gc-doltlite-fastpath.
  gc-helper   Build gc-doltlite helper.
  backend     Build bd-backend, gc-backend, and gc-helper.
  client      Build the DoltLite diagnostic client.
  all         Build bd, gc, backend, and client.

Options:
  --bd-source DIR       Beads source checkout containing cmd/bd.
  --gc-source DIR       Gas City source checkout containing cmd/gc.
  --plugin-source DIR   Backend plugin source checkout.
  --lib DIR             Directory containing libdoltlite.
  --output DIR          Output directory. Default: pack runtime bin.
  --install             Install bd/gc entrypoints and plugin runtime binaries.
  --install-dir DIR     Install dir for bd/gc when no explicit path is set.
  --bd-install FILE     Install path for bd.
  --gc-install FILE     Install path for gc.
  --build-details-dir DIR
                         Directory for last-build-*.json.
  --version VALUE       Version string for gc. Default: dev.
  --bd-build VALUE      Build string for bd. Default: dev.
  --help                Show this help.

Environment overrides:
  BD_SRC, BEADS_DOLTLITE_SRC, GC_BEADS_DOLTLITE_SRC
  GASCITY_SRC, GC_GASCITY_SRC
  BACKEND_PLUGIN_SRC, GC_DOLTLITE_BACKEND_PLUGIN_SRC
  DOLTLITE_LIB, GC_DOLTLITE_LIB
  BD_GC_DL_OUTPUT_DIR, BD_GC_DL_BUILD_DETAILS_DIR
  BD_GC_DL_INSTALL, BD_GC_DL_INSTALL_DIR
  BD_GC_DL_BD_INSTALL, BD_GC_DL_GC_INSTALL
  BD_GC_DL_GO_CACHE_ROOT, GOCACHE, GOMODCACHE, GOTMPDIR, TMPDIR
  BD_BUILD, BD_COMMIT, BD_BRANCH
  GC_VERSION, GC_COMMIT, GC_BUILD_DATE
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

usage_error() {
  echo "$*" >&2
  usage >&2
  exit 2
}

require_value() {
  if [ -z "${2:-}" ] || [[ "${2:-}" == --* ]]; then
    usage_error "$1 requires a value"
  fi
}

abs_dir() {
  cd "$1" && pwd
}

has_bd_source() {
  [ -f "$1/go.mod" ] && [ -d "$1/cmd/bd" ]
}

has_gc_source() {
  [ -f "$1/go.mod" ] && [ -d "$1/cmd/gc" ]
}

has_plugin_source() {
  [ -f "$1/go.mod" ] && [ -d "$1/cmd/bd-backend-doltlite" ] && [ -d "$1/cmd/gc-doltlite-fastpath" ]
}

has_doltlite_lib() {
  [ -r "$1/libdoltlite.a" ] || [ -r "$1/libdoltlite.so" ] || [ -r "$1/libdoltlite.so.0" ] || [ -r "$1/libdoltlite.dylib" ]
}

find_bd_source() {
  for candidate in \
    "$CITY_ROOT/beads-doltlite" \
    "$CITY_ROOT/workspaces/beads-plugin-architecture" \
    "$CITY_ROOT/../beads-doltlite" \
    "$SCRIPT_CHECKOUT/../beads-doltlite" \
    "$SCRIPT_CHECKOUT"; do
    if [ -d "$candidate" ] && has_bd_source "$candidate"; then
      abs_dir "$candidate"
      return 0
    fi
  done
  return 1
}

find_gc_source() {
  for candidate in \
    "$CITY_ROOT/gascity" \
    "$CITY_ROOT/../gascity" \
    "$SCRIPT_CHECKOUT/../gascity" \
    "$SCRIPT_CHECKOUT"; do
    if [ -d "$candidate" ] && has_gc_source "$candidate"; then
      abs_dir "$candidate"
      return 0
    fi
  done
  return 1
}

find_plugin_source() {
  for candidate in \
    "$CITY_ROOT/rigs/beads-backend-doltlite-plugin" \
    "$CITY_ROOT/.gc/workspaces/beads-backend-doltlite-plugin" \
    "$CITY_ROOT/beads-backend-doltlite-plugin" \
    "$CITY_ROOT/../beads-backend-doltlite-plugin" \
    "$SCRIPT_CHECKOUT/../beads-backend-doltlite-plugin"; do
    if [ -d "$candidate" ] && has_plugin_source "$candidate"; then
      abs_dir "$candidate"
      return 0
    fi
  done
  return 1
}

find_doltlite_lib() {
  for candidate in \
    "$CITY_ROOT/doltlite-work/build" \
    "$CITY_ROOT/doltlite/build" \
    "$CITY_ROOT/doltlite" \
    "$CITY_ROOT/.gc/runtime/packs/beads-doltlite/doltlite/0.11.23/linux-x64" \
    "$CITY_ROOT/../doltlite-work/build" \
    "$CITY_ROOT/../doltlite/build"; do
    if [ -d "$candidate" ] && has_doltlite_lib "$candidate"; then
      abs_dir "$candidate"
      return 0
    fi
  done
  return 1
}

revision_for() {
  local dir="$1"
  if command -v jj >/dev/null 2>&1 && [ -d "$dir/.jj" ]; then
    jj -R "$dir" log -r @ --no-graph -T 'commit_id.short()' 2>/dev/null || true
    return 0
  fi
  git -C "$dir" rev-parse --short=12 HEAD 2>/dev/null || true
}

branch_for() {
  local dir="$1"
  if command -v jj >/dev/null 2>&1 && [ -d "$dir/.jj" ]; then
    jj -R "$dir" log -r @ --no-graph -T 'bookmarks.join(" ")' 2>/dev/null || true
    return 0
  fi
  git -C "$dir" branch --show-current 2>/dev/null || true
}

default_install_path() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  echo "$HOME/.local/bin/$name"
}

install_binary() {
  local source="$1" dest="$2" label="$3"
  [ -x "$source" ] || die "$label build output is not executable: $source"
  mkdir -p "$(dirname "$dest")"
  if [ "$(cd "$(dirname "$source")" && pwd)/$(basename "$source")" != "$(cd "$(dirname "$dest")" && pwd)/$(basename "$dest")" ]; then
    cp -f "$source" "$dest"
  fi
  chmod 0755 "$dest"
  echo "installed $label: $dest"
}

go_version_m() {
  local bin="$1"
  go version -m "$bin" 2>/dev/null | sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g' || true
}

sha256_for() {
  sha256sum "$1" | awk '{print $1}'
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_build_details() {
  local target="$1" source="$2" output="$3" installed_to="$4" commit="$5" version="$6" tags="$7" doltlite_lib="$8"
  local file date go_version output_sha install_sha
  mkdir -p "$BUILD_DETAILS_DIR"
  file="$BUILD_DETAILS_DIR/last-build-$target.json"
  date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  go_version="$(go version 2>/dev/null || true)"
  output_sha="$(sha256_for "$output")"
  install_sha=""
  if [ -n "$installed_to" ] && [ -f "$installed_to" ]; then
    install_sha="$(sha256_for "$installed_to")"
  fi
  {
    printf '{\n'
    printf '  "schema_version": "1",\n'
    printf '  "pack": "bd-gc-dl",\n'
    printf '  "target": "%s",\n' "$(json_escape "$target")"
    printf '  "built_at": "%s",\n' "$(json_escape "$date")"
    printf '  "source": "%s",\n' "$(json_escape "$source")"
    printf '  "output": "%s",\n' "$(json_escape "$output")"
    printf '  "installed_to": "%s",\n' "$(json_escape "$installed_to")"
    printf '  "binary_path": "%s",\n' "$(json_escape "${installed_to:-$output}")"
    printf '  "output_sha256": "%s",\n' "$output_sha"
    printf '  "install_sha256": "%s",\n' "$install_sha"
    printf '  "commit": "%s",\n' "$(json_escape "$commit")"
    printf '  "version": "%s",\n' "$(json_escape "$version")"
    printf '  "tags": "%s",\n' "$(json_escape "$tags")"
    printf '  "doltlite_lib": "%s",\n' "$(json_escape "$doltlite_lib")"
    printf '  "go_version": "%s",\n' "$(json_escape "$go_version")"
    printf '  "go_version_m": "%s"\n' "$(go_version_m "${installed_to:-$output}")"
    printf '}\n'
  } > "$file"
  echo "wrote $file"
}

prepare_standard_go_env() {
  export CGO_ENABLED="${CGO_ENABLED:-1}"
  export GOCACHE="${GOCACHE:-$GO_CACHE_ROOT/build}"
  export GOMODCACHE="${GOMODCACHE:-$GO_CACHE_ROOT/mod}"
  export GOTMPDIR="${GOTMPDIR:-$GO_CACHE_ROOT/tmp}"
  case "${TMPDIR:-}" in
    ""|/tmp|/tmp/*)
      export TMPDIR="$GO_CACHE_ROOT/tmp"
      ;;
    *)
      export TMPDIR
      ;;
  esac
  mkdir -p "$GOCACHE" "$GOMODCACHE" "$GOTMPDIR" "$TMPDIR"
  if [ "$CACHE_REPORTED" != "1" ]; then
    echo "using Go cache root: $GO_CACHE_ROOT"
    echo "using GOCACHE=$GOCACHE"
    echo "using GOMODCACHE=$GOMODCACHE"
    echo "using GOTMPDIR=$GOTMPDIR"
    echo "using TMPDIR=$TMPDIR"
    CACHE_REPORTED=1
  fi
}

prepare_plugin_go_env() {
  [ -n "$DOLTLITE_LIB" ] || DOLTLITE_LIB="$(find_doltlite_lib || true)"
  [ -n "$DOLTLITE_LIB" ] || die "could not find libdoltlite; pass --lib or set DOLTLITE_LIB"
  has_doltlite_lib "$DOLTLITE_LIB" || die "libdoltlite not found in $DOLTLITE_LIB"
  DOLTLITE_LIB="$(abs_dir "$DOLTLITE_LIB")"
  prepare_standard_go_env
  export CGO_CFLAGS="${CGO_CFLAGS:-"-I${DOLTLITE_LIB}"}"
  if [ -r "$DOLTLITE_LIB/libdoltlite.a" ]; then
    export CGO_LDFLAGS="${CGO_LDFLAGS:-"-L${DOLTLITE_LIB} ${DOLTLITE_LIB}/libdoltlite.a -lz -lpthread -lm"}"
  else
    export CGO_LDFLAGS="${CGO_LDFLAGS:-"-L${DOLTLITE_LIB} -Wl,-rpath,${DOLTLITE_LIB} -ldoltlite -lz -lpthread -lm"}"
  fi
}

build_bd() {
  [ -n "$BD_SRC" ] || BD_SRC="$(find_bd_source || true)"
  [ -n "$BD_SRC" ] && has_bd_source "$BD_SRC" || die "could not find Beads source; pass --bd-source"
  BD_SRC="$(abs_dir "$BD_SRC")"
  local output commit branch ldflags installed_to
  output="$OUTPUT_DIR/bd"
  commit="${BD_COMMIT:-$(revision_for "$BD_SRC")}"
  branch="${BD_BRANCH:-$(branch_for "$BD_SRC")}"
  ldflags="-X main.Build=${BD_BUILD_VALUE} -X main.Commit=${commit:-unknown}"
  if [ -n "$branch" ]; then
    ldflags="$ldflags -X main.Branch=$branch"
  fi
  prepare_standard_go_env
  echo "building bd from $BD_SRC"
  (cd "$BD_SRC" && go build -ldflags "$ldflags" -o "$output" ./cmd/bd)
  installed_to=""
  if [ "$INSTALL" = "1" ]; then
    [ -n "$BD_INSTALL" ] || BD_INSTALL="${INSTALL_DIR:-$(default_install_path bd)}"
    install_binary "$output" "$BD_INSTALL" "bd"
    installed_to="$BD_INSTALL"
  fi
  write_build_details "bd" "$BD_SRC" "$output" "$installed_to" "${commit:-unknown}" "$BD_BUILD_VALUE" "" ""
}

build_gc() {
  [ -n "$GC_SRC" ] || GC_SRC="$(find_gc_source || true)"
  [ -n "$GC_SRC" ] && has_gc_source "$GC_SRC" || die "could not find Gas City source; pass --gc-source"
  GC_SRC="$(abs_dir "$GC_SRC")"
  local output commit date installed_to
  output="$OUTPUT_DIR/gc"
  commit="${GC_COMMIT:-$(revision_for "$GC_SRC")}"
  date="${GC_BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  prepare_standard_go_env
  echo "building gc from $GC_SRC"
  (cd "$GC_SRC" && go build -ldflags "-X main.version=${VERSION} -X main.commit=${commit:-unknown} -X main.date=${date}" -o "$output" ./cmd/gc)
  installed_to=""
  if [ "$INSTALL" = "1" ]; then
    [ -n "$GC_INSTALL" ] || GC_INSTALL="${INSTALL_DIR:-$(default_install_path gc)}"
    install_binary "$output" "$GC_INSTALL" "gc"
    installed_to="$GC_INSTALL"
  fi
  write_build_details "gc" "$GC_SRC" "$output" "$installed_to" "${commit:-unknown}" "$VERSION" "" ""
}

build_plugin_command() {
  local target="$1" package="$2" output="$3"
  [ -n "$PLUGIN_SRC" ] || PLUGIN_SRC="$(find_plugin_source || true)"
  [ -n "$PLUGIN_SRC" ] && has_plugin_source "$PLUGIN_SRC" || die "could not find backend plugin source; pass --plugin-source"
  PLUGIN_SRC="$(abs_dir "$PLUGIN_SRC")"
  local commit installed_to tags
  tags="${GO_TAGS:-libsqlite3 gms_pure_go}"
  commit="$(revision_for "$PLUGIN_SRC")"
  prepare_plugin_go_env
  echo "building $target from $PLUGIN_SRC"
  echo "linking libdoltlite from $DOLTLITE_LIB"
  (cd "$PLUGIN_SRC" && go build -tags "$tags" -o "$output" "$package")
  installed_to=""
  if [ "$INSTALL" = "1" ]; then
    install_binary "$output" "$PACK_INSTALL_BIN/$(basename "$output")" "$target"
    installed_to="$PACK_INSTALL_BIN/$(basename "$output")"
  fi
  write_build_details "$target" "$PLUGIN_SRC" "$output" "$installed_to" "${commit:-unknown}" "dev" "$tags" "$DOLTLITE_LIB"
}

build_bd_backend() {
  build_plugin_command "bd-backend-doltlite" "./cmd/bd-backend-doltlite" "$OUTPUT_DIR/bd-backend-doltlite"
}

build_gc_backend() {
  build_plugin_command "gc-doltlite-fastpath" "./cmd/gc-doltlite-fastpath" "$OUTPUT_DIR/gc-doltlite-fastpath"
}

build_gc_helper() {
  build_plugin_command "gc-doltlite" "./cmd/gc-doltlite" "$OUTPUT_DIR/gc-doltlite"
}

build_client() {
  [ -n "$GC_SRC" ] || GC_SRC="$(find_gc_source || true)"
  [ -n "$GC_SRC" ] && has_gc_source "$GC_SRC" || die "could not find Gas City source; pass --gc-source"
  GC_SRC="$(abs_dir "$GC_SRC")"
  [ -f "$GC_SRC/tools/doltlite-client/main.go" ] || die "could not find doltlite-client under $GC_SRC/tools/doltlite-client"
  local output commit tags
  output="$OUTPUT_DIR/doltlite-client"
  commit="$(revision_for "$GC_SRC")"
  tags="${CLIENT_GO_TAGS:-gascity_doltlite_lib,libsqlite3}"
  prepare_plugin_go_env
  export GOFLAGS="${GOFLAGS:-"-tags=${tags}"}"
  echo "building doltlite-client from $GC_SRC"
  (cd "$GC_SRC" && go build -o "$output" ./tools/doltlite-client)
  write_build_details "doltlite-client" "$GC_SRC" "$output" "$output" "${commit:-unknown}" "dev" "$tags" "$DOLTLITE_LIB"
}

CITY_ROOT="${GC_CITY_PATH:-${GC_CITY:-$(pwd)}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACK_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_CHECKOUT="$(cd "$PACK_DIR/../.." && pwd)"
PACK_STATE_DIR="${GC_PACK_STATE_DIR:-$CITY_ROOT/.gc/runtime/packs/bd-gc-dl}"
PACK_INSTALL_BIN="$PACK_STATE_DIR/bin"
TARGET="all"
BD_SRC="${BD_SRC:-${BEADS_DOLTLITE_SRC:-${GC_BEADS_DOLTLITE_SRC:-}}}"
GC_SRC="${GASCITY_SRC:-${GC_GASCITY_SRC:-}}"
PLUGIN_SRC="${BACKEND_PLUGIN_SRC:-${GC_DOLTLITE_BACKEND_PLUGIN_SRC:-}}"
DOLTLITE_LIB="${DOLTLITE_LIB:-${GC_DOLTLITE_LIB:-}}"
OUTPUT_DIR="${BD_GC_DL_OUTPUT_DIR:-$PACK_INSTALL_BIN}"
BUILD_DETAILS_DIR="${BD_GC_DL_BUILD_DETAILS_DIR:-$PACK_STATE_DIR}"
INSTALL="${BD_GC_DL_INSTALL:-0}"
INSTALL_DIR="${BD_GC_DL_INSTALL_DIR:-}"
BD_INSTALL="${BD_GC_DL_BD_INSTALL:-}"
GC_INSTALL="${BD_GC_DL_GC_INSTALL:-}"
VERSION="${GC_VERSION:-dev}"
BD_BUILD_VALUE="${BD_BUILD:-dev}"
GO_CACHE_ROOT="${BD_GC_DL_GO_CACHE_ROOT:-$CITY_ROOT/.cache/go}"
CACHE_REPORTED=0

if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
  TARGET="$1"
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --bd-source)
      require_value "$1" "${2:-}"
      BD_SRC="$2"
      shift 2
      ;;
    --gc-source)
      require_value "$1" "${2:-}"
      GC_SRC="$2"
      shift 2
      ;;
    --plugin-source)
      require_value "$1" "${2:-}"
      PLUGIN_SRC="$2"
      shift 2
      ;;
    --lib)
      require_value "$1" "${2:-}"
      DOLTLITE_LIB="$2"
      shift 2
      ;;
    --output)
      require_value "$1" "${2:-}"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --install)
      INSTALL=1
      shift
      ;;
    --install-dir)
      require_value "$1" "${2:-}"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --bd-install)
      require_value "$1" "${2:-}"
      BD_INSTALL="$2"
      shift 2
      ;;
    --gc-install)
      require_value "$1" "${2:-}"
      GC_INSTALL="$2"
      shift 2
      ;;
    --build-details-dir)
      require_value "$1" "${2:-}"
      BUILD_DETAILS_DIR="$2"
      shift 2
      ;;
    --version)
      require_value "$1" "${2:-}"
      VERSION="$2"
      shift 2
      ;;
    --bd-build)
      require_value "$1" "${2:-}"
      BD_BUILD_VALUE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage_error "unknown option: $1"
      ;;
  esac
done

case "$TARGET" in
  bd|gc|bd-backend|gc-backend|gc-helper|backend|client|all) ;;
  *) usage_error "unknown target: $TARGET" ;;
esac

mkdir -p "$OUTPUT_DIR" "$PACK_INSTALL_BIN" "$BUILD_DETAILS_DIR"
if ! command -v go >/dev/null 2>&1; then
  die "go is required"
fi

case "$TARGET" in
  bd)
    build_bd
    ;;
  gc)
    build_gc
    ;;
  bd-backend)
    build_bd_backend
    ;;
  gc-backend)
    build_gc_backend
    ;;
  gc-helper)
    build_gc_helper
    ;;
  backend)
    build_bd_backend
    build_gc_backend
    build_gc_helper
    ;;
  client)
    build_client
    ;;
  all)
    build_bd
    build_gc
    build_bd_backend
    build_gc_backend
    build_gc_helper
    build_client
    ;;
esac
