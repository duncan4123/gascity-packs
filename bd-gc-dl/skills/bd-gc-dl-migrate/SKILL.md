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

Keep `beads-doltlite-init` and `beads-doltlite`; `bd-gc-dl` is the build pack,
not the provider pack.

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

## Repair Metadata

Run the DoltLite provider readiness path so existing scopes are rewritten with
the new plugin command paths:

```bash
gc beads-doltlite health
gc doctor
```

If a scope still lacks plugin metadata, repair it explicitly by running the
provider ensure-ready path through normal Gas City startup/reload, or rewrite
the scope metadata only after preserving its existing `project_id` and
`dolt_database`.

Expected metadata fields:

```json
{
  "backend_plugin_command": "<city>/.gc/runtime/packs/bd-gc-dl/bin/bd-backend-doltlite",
  "backend_plugin_args": ["--trace", "<city>/.gc/backend-plugin-trace.jsonl", "serve"],
  "gascity_backend_command": "<city>/.gc/runtime/packs/bd-gc-dl/bin/gc-doltlite-fastpath",
  "gascity_backend_args": ["--trace", "<city>/.gc/gascity-backend-plugin-trace.jsonl", "serve"]
}
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
empty, inspect `.beads/metadata.json` and confirm the installed `bd` build
supports backend plugin metadata.

## Rollback

Rollback is config-based:

- Remove or stop using the `bd-gc-dl` import.
- Restore prior plugin command paths in `.beads/metadata.json`, or set
  `GC_DOLTLITE_BACKEND_PLUGIN_COMMAND` and
  `GC_DOLTLITE_GASCITY_BACKEND_PLUGIN_COMMAND` to known-good binaries.
- Do not delete `.beads/doltlite` data during rollback.
