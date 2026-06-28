---
name: gascity-jj-doltlite
description: Use alongside beads-doltlite.doltlite when Mayor or JJ workflow work touches DoltLite-backed Gas City storage, beads-doltlite builds, linked gc/bd/doltlite-client binaries, native read fast path behavior, or DoltLite lock/maintenance diagnostics.
---

# Gas City JJ DoltLite

Use this skill with the imported `beads-doltlite.doltlite` skill. That imported
skill owns the canonical DoltLite storage and build contract; this extension
makes the contract explicit for `gascity-jj-base` Mayor and JJ workflow work.

## Required Activation

Activate this skill, and the imported `beads-doltlite.doltlite` skill, before
choosing commands for any work involving:

- DoltLite-backed Gas City or Beads storage.
- `beads-doltlite` pack code, scripts, or build outputs.
- Linked `gc`, `bd`, or `doltlite-client` binaries.
- DoltLite native read fast path behavior.
- DoltLite locks, maintenance, flatten, GC, backup, or direct SQL probes.

## Build Rule

Do not use plain `go install`, `make install`, or ad hoc Go build commands to
refresh runtime `gc`, `bd`, or `doltlite-client` binaries in this city. Those
paths can drop the DoltLite linkage and native-read build contract.

Use the beads-doltlite pack-managed build commands:

```bash
gc beads-doltlite build gc --install --no-restart
gc beads-doltlite build bd --install --no-restart
gc beads-doltlite build client --no-restart
gc beads-doltlite build all --install --no-restart
```

Use `gc beads-doltlite build all --install --no-restart` only for bootstrap or a
coordinated rebuild. For normal Gas City iteration, prefer
`gc beads-doltlite build gc --install --no-restart`.

## Diagnostics

Prefer `doltlite-client` for direct DoltLite reads and writes. Use the exact
operation being debugged when comparing behavior between `bd`, Gas City
controller queries, and DoltLite-backed storage.

Do not require a Dolt SQL server or runtime port for DoltLite-backed cities.
Before debugging lock issues, check for active `bd`, `doltlite-client`,
`gc session list`, and `gc-beads-bd` processes. Kill only probes you started or
processes the user has approved.
