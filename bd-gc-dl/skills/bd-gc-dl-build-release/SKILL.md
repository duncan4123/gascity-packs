---
name: bd-gc-dl-build-release
description: Use when building, validating, or releasing the plugin-backed DoltLite bd/gc stack across Beads, Gas City, backend plugin, and gascity-packs repos.
---

# BD GC DL Build And Release

Use this skill for end-to-end work on the plugin-backed DoltLite stack:

- building all binaries;
- explaining how the pieces fit together;
- validating a city is using the split backend-plugin architecture;
- preparing coordinated releases across the related repositories.

## Pack Conventions

This pack follows normal `gascity-packs` layout:

- commands live under `commands/<name>/`;
- skills live under `skills/<name>/SKILL.md`;
- reusable prompt text lives under `template-fragments/*.template.md`;
- specialist agents live under `agents/<name>/`.

The `bd-gc-dl-fixer` agent is the routed owner for repair work involving the
repos this pack manages. General agents should use the `bd-gc-dl-handoff`
template fragment to file or route focused failure beads instead of doing
incidental backend repair work.

## Current Architecture

There are four source surfaces:

- Beads core / `bd`: owns the CLI, backend-plugin client/protocol, Beads
  storage APIs, schema compatibility, and `.beads/metadata.json` handling.
- Backend plugin repo:
  `/data/projects/doltlite-gascity/rigs/beads-backend-doltlite-plugin`.
  Owns `bd-backend-doltlite`, `gc-doltlite-fastpath`, and `gc-doltlite`.
- Gas City:
  `/data/projects/doltlite-gascity/gascity`.
  Owns `gc`, `gc init`, backend launch/adapter code, city metadata use, and
  runtime orchestration.
- Gas City packs:
  `/data/projects/doltlite-gascity/gascity-packs`.
  Owns `beads-doltlite`, `beads-doltlite-init`, and `bd-gc-dl`.

The intended runtime shape is split-process:

```text
bd or gc
  -> reads .beads/metadata.json
  -> starts backend plugin process over newline-delimited JSON
  -> plugin process owns direct DoltLite/libdoltlite access
```

Main `bd` and `gc` should not need direct `libdoltlite` linkage in the target
shape. The backend plugin binaries do need `libdoltlite`.

## Runtime Binaries

The `bd-gc-dl` pack builds:

- `bd`
- `gc`
- `bd-backend-doltlite`
- `gc-doltlite-fastpath`
- `gc-doltlite`
- `doltlite-client`

Default runtime output:

```text
<city>/.gc/runtime/packs/bd-gc-dl/bin/
```

Default build cache and temp paths:

```text
<city>/.cache/go/build
<city>/.cache/go/mod
<city>/.cache/go/tmp
```

Do not put build outputs or temporary directories under `/tmp`.

## Build Commands

Build everything:

```bash
gc bd-gc-dl build all --install
```

Build only plugin servers:

```bash
gc bd-gc-dl build backend --install
```

Use explicit sources when doing coordinated local work:

```bash
gc bd-gc-dl build all --install \
  --bd-source /data/projects/doltlite-gascity/beads-doltlite \
  --gc-source /data/projects/doltlite-gascity/gascity \
  --plugin-source /data/projects/doltlite-gascity/rigs/beads-backend-doltlite-plugin \
  --lib /data/projects/doltlite-gascity/doltlite-work/build
```

The build command writes `last-build-*.json` under
`.gc/runtime/packs/bd-gc-dl/`.

## Basic Validation

After building:

```bash
ls -l .gc/runtime/packs/bd-gc-dl/bin
go version -m .gc/runtime/packs/bd-gc-dl/bin/bd-backend-doltlite
go version -m .gc/runtime/packs/bd-gc-dl/bin/gc-doltlite-fastpath
```

After metadata repair/startup:

```bash
bd list --json --limit 1
gc bd list --json --limit 1
tail -20 .gc/backend-plugin-trace.jsonl
tail -20 .gc/gascity-backend-plugin-trace.jsonl
```

Trace files should show calls through the plugin processes. Empty traces mean
the running CLI is not using plugin metadata or the scope metadata points
elsewhere.

## Coordinated Release Order

For a real release across all repos, release from the leaves inward:

1. Backend plugin repo:
   - run tests;
   - build `bd-backend-doltlite`, `gc-doltlite-fastpath`, `gc-doltlite`;
   - tag/release plugin binaries or record the commit consumed by packs.
2. Beads core / `bd`:
   - ensure backend-plugin protocol compatibility;
   - run storage and pluginprocess tests;
   - release or pin the `bd` build that understands the plugin metadata.
3. Gas City:
   - update builtin `beads-doltlite-init` if plugin paths or metadata shape
     changed;
   - update `gc init` imports when pack sources/versions change;
   - run init, backend, and city runtime tests;
   - release or pin `gc`.
4. Gas City packs:
   - update `beads-doltlite`, `beads-doltlite-init`, and `bd-gc-dl`;
   - update migration/build skills;
   - run `go test ./...`;
   - publish/tag the pack repo.
5. Smoke a fresh city and an existing-city migration using released artifacts.

Do not publish a pack version that points fresh `gc init` at binaries or
metadata paths the released `gc` cannot consume.

## Release Checklist

For each repo:

```bash
jj status
jj log -r 'trunk()..@'
go test ./...
```

Use the repo's own release workflow where present. If no workflow exists, create
a normal tagged release or PR according to that repo's conventions. Keep release
notes explicit about:

- plugin protocol compatibility;
- required `bd` version;
- required `gc` version;
- backend plugin binary commit/version;
- pack version or commit.

## Cross-Repo Compatibility Rule

Compatibility is determined by the metadata contract, not by repo names:

```json
{
  "backend_plugin_command": ".../bd-backend-doltlite",
  "backend_plugin_args": ["--trace", ".../backend-plugin-trace.jsonl", "serve"],
  "gascity_backend_command": ".../gc-doltlite-fastpath",
  "gascity_backend_args": ["--trace", ".../gascity-backend-plugin-trace.jsonl", "serve"]
}
```

Any release that changes these fields, protocol methods, schema expectations,
or binary names must be coordinated across all four source surfaces.
