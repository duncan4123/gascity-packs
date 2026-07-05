---
name: bd-gc-dl-migrate
description: Use when migrating an existing DoltLite-backed Gas City to the plugin-backed bd/gc build pack and backend plugin binaries.
---

# BD GC DL Migration

Use this skill when an existing city already uses `[beads] backend = "doltlite"`
and needs to move onto the plugin-backed build layout provided by the
`bd-gc-dl` pack.

## Goal

The migrated city should have:

- `pack.toml` importing `bd-gc-dl`.
- backend plugin binaries built under `.gc/runtime/packs/bd-gc-dl/bin`.
- `.beads/metadata.json` in every DoltLite scope pointing at executable plugin
  commands.
- Go build cache and temp paths under the city root, not `/tmp`.

## Routing Rule

If migration exposes a Beads, Gas City, backend plugin, or pack wiring bug that
is larger than the migration itself, route a focused bead to `bd-gc-dl-fixer`.
That agent owns repair work across the repos managed by this pack. Do not turn
the migration into broad backend surgery.

## Inspect First

From the city root:

```bash
gc status
gc import tree
grep -n 'backend = "doltlite"' city.toml
find . -path '*/.beads/metadata.json' -maxdepth 5 -print
```

Confirm the backend is DoltLite before making changes. Do not migrate managed
Dolt or external Postgres cities with this skill.

## Add The Pack

Prefer `gc import add` when available so `packs.lock` is updated normally:

```bash
gc import add bd-gc-dl https://github.com/gastownhall/gascity-packs/tree/main/bd-gc-dl --version ref:main
gc import install
```

For local development, use the local pack path instead:

```bash
gc import add bd-gc-dl /data/projects/doltlite-gascity/gascity-packs/bd-gc-dl
gc import install
```

Remove `beads-doltlite-init` and `beads-doltlite` imports for plugin-backed
cities. `bd-gc-dl` owns both the build layout and the provider bridge for this
architecture.

## Build Plugin Binaries

Build into city-local runtime/cache paths:

```bash
gc bd-gc-dl build backend --install
```

The command must report paths like:

```text
GOCACHE=<city>/.cache/go/build
GOMODCACHE=<city>/.cache/go/mod
GOTMPDIR=<city>/.cache/go/tmp
TMPDIR=<city>/.cache/go/tmp
```

Do not pass `/tmp` output or build-detail paths.

## Repair Plugin Trust

Run the DoltLite provider readiness path so existing scopes are rewritten with
descriptive metadata and local plugin trust:

```bash
gc import check
gc doctor
```

If a scope still lacks plugin trust, repair it explicitly by running the
provider ensure-ready path through normal Gas City startup/reload. Committed
`.beads/metadata.json` should identify the backend; `.beads/config.local.yaml`
authorizes the executable and is gitignored.

Expected committed metadata:

```json
{
  "backend": "doltlite",
  "database": "doltlite",
  "dolt_database": "<scope database>"
}
```

Expected local trust:

```yaml
backend_plugins:
  doltlite:
    command: <city>/.gc/runtime/packs/bd-gc-dl/bin/bd-backend-doltlite
    args: ["--trace", "<city>/.gc/backend-plugin-trace.jsonl", "serve"]
```

## Verify

Use normal commands first:

```bash
bd list --json --limit 1
gc bd list --json --limit 1
tail -20 .gc/backend-plugin-trace.jsonl
tail -20 .gc/gascity-backend-plugin-trace.jsonl
```

The trace files should show plugin calls after the migration. If traces stay
empty, inspect `.beads/config.local.yaml` and confirm the installed `bd` build
uses local backend plugin trust.

## Rollback

Rollback is config-based:

- Remove or stop using the `bd-gc-dl` import.
- Remove `.beads/config.local.yaml`, or set `GC_DOLTLITE_BACKEND_PLUGIN_COMMAND`
  and `GC_DOLTLITE_GASCITY_BACKEND_PLUGIN_COMMAND` to known-good binaries.
- Do not delete `.beads/doltlite` data during rollback.
