# Gas City Pack Ownership Alignment Plan

## Goal

Make `gascity-packs` the canonical source repository for Gas City packs that are
owned by this project, with the root city using local pack bindings only as
live checkouts of that source. The `gascity` repo should stop being the source
for owned pack behavior; its `examples/` packs should either become fixtures or
be replaced by registry-backed `gascity-packs` imports.

## Current State

### Root city

`/data/projects/doltlite-gascity/city.toml` currently mixes sources:

- `beads-doltlite` rig includes:
  - `./gascity/examples/gastown/packs/gastown-jj`
  - `./gascity/examples/beads-doltlite`
  - `./gascity/examples/jj-spr`
- `gascity` rig includes:
  - `./packs/gastown-jj`
  - `./packs/gastown-lazyjj`
  - `./gascity/examples/beads-doltlite`
- `gascity-packs` rig has no pack includes.
- `city.toml` contains a local editing rule: edits must start in a new jj
  change, with a description explaining the intended `city.toml` edit.

### Root live pack bindings

`/data/projects/doltlite-gascity/packs` currently contains:

- `gastown-jj` -> `../gascity-packs/gastown-jj`
- `gastown-lazyjj` -> `/data/projects/doltlite-gascity/gascity-packs/gastown-lazyjj`
- `packer` -> `/data/projects/doltlite-gascity/gascity-packs/packer`
- `gascity-lazyjj` -> `/data/projects/doltlite-gascity/gascity-packs/gascity-lazyjj`
- `gastown-lazyjj.backup.20260610203210` as a copied backup directory

`gascity-lazyjj` currently has no `pack.toml`, so it should not be treated as a
valid pack binding until it is either removed or made real.

### Registry-owned packs

`gascity-packs/registry.toml` currently publishes these owned packs from
`https://github.com/gastownhall/gascity-packs/tree/main/<pack>`:

- `gascity-jj`
- `gastown-jj`
- `lazyjj-implementation`
- `gastown-lazyjj`
- `packer`

### Local packs missing from registry

These local `gascity-packs` directories have a `pack.toml` but no registry
entry:

- `cass`
- `discord`
- `gascity`
- `gastown`
- `github`
- `slack-channel`
- `slack-full`
- `slack-mini`

### Built-in example overlap

These pack names exist both in `gascity-packs` and in `gascity/examples`:

- `gastown`
- `gastown-jj`
- `gastown-lazyjj`

These packs exist only under `gascity/examples` today:

- `bd`
- `beads-doltlite`
- `dolt`
- `hyperscale`
- `jj-spr`
- `lifecycle`
- `maintenance`
- `swarm`
- `t3bridge-gastown`
- `t3demo`

## Target State

1. Every project-owned pack has one canonical source directory under
   `/data/projects/doltlite-gascity/gascity-packs/<pack>`.
2. Every project-owned pack has a registry entry using the dereferenceable
   GitHub tree URL:
   `https://github.com/gastownhall/gascity-packs/tree/main/<pack>`.
3. Root `/data/projects/doltlite-gascity/packs/<pack>` entries are local live
   bindings to `gascity-packs/<pack>`, not independent source copies.
4. Root `city.toml` uses `./packs/<pack>` for owned packs and stops importing
   owned workflow packs from `./gascity/examples/...`.
5. `gascity/examples` keeps only fixtures and runtime/system examples that are
   explicitly not owned by `gascity-packs`, or points readers to the registry
   canonical pack.
6. Registry validation remains the source of truth for release metadata:
   `python3 validate_registry.py` and
   `python3 -m pytest tests/test_validate_registry.py -q`.

## Proposed Work Beads

### 1. Classify pack ownership

Formula: `mol-polecat-lazyjj-work`

Description:
Create an ownership matrix that classifies every pack as one of:
`gascity-packs canonical`, `gascity example fixture`, or `runtime/system built-in`.

Acceptance criteria:

- The matrix covers every local `gascity-packs/*/pack.toml` directory.
- The matrix covers every `gascity/examples/**/pack.toml` directory.
- `bd`, `dolt`, `beads-doltlite`, and `maintenance` are explicitly classified
  before any migration changes are made.

Dependencies: none

Files:

- `gascity-packs/docs/design/`
- `gascity-packs/README.md`

Verification:

- Re-run the pack inventory script and confirm every manifest appears in the
  matrix exactly once.

### 2. Register all owned local packs

Formula: `mol-polecat-lazyjj-work`

Description:
Add registry entries for local packs that are confirmed as `gascity-packs`
owned and currently missing from `registry.toml`.

Initial candidates:

- `cass`
- `discord`
- `gascity`
- `gastown`
- `github`
- `slack-channel`
- `slack-full`
- `slack-mini`

Acceptance criteria:

- Each registered pack has a dereferenceable
  `https://github.com/gastownhall/gascity-packs/tree/main/<pack>` source.
- Each registered release has a version, ref, full lowercase commit SHA, pack
  content hash, and release description.
- Existing registered packs are not churned unless their release metadata is
  intentionally updated.

Dependencies:

- `Classify pack ownership`

Files:

- `gascity-packs/registry.toml`
- `gascity-packs/validate_registry.py`
- `gascity-packs/tests/test_validate_registry.py`

Verification:

- `python3 validate_registry.py`
- `python3 -m pytest tests/test_validate_registry.py -q`

### 3. Normalize root live pack bindings

Formula: `mol-polecat-lazyjj-work`

Description:
Make `/data/projects/doltlite-gascity/packs` contain only live bindings for
valid canonical packs from `gascity-packs`.

Acceptance criteria:

- `./packs/<pack>` paths used by `city.toml` resolve to the matching
  `gascity-packs/<pack>` source directory.
- `gascity-lazyjj` is either removed as a dead binding or promoted into a real
  pack with `pack.toml`.
- `gastown-lazyjj.backup.20260610203210` is moved out of the live pack binding
  directory or documented as an intentional backup outside runtime discovery.
- No `./packs` entry shadows a registry-owned pack with copied source.

Dependencies:

- `Classify pack ownership`

Files:

- `/data/projects/doltlite-gascity/packs/`
- `gascity-packs/README.md`

Verification:

- `find /data/projects/doltlite-gascity/packs -maxdepth 2 -name pack.toml`
- For each live binding, confirm the manifest name matches the directory name.

### 4. Switch root city includes to owned pack bindings

Formula: `mol-polecat-lazyjj-work`

Description:
Update root `city.toml` so project-owned workflow packs are loaded from
`./packs/<pack>` and not from `./gascity/examples/...`.

Proposed include direction:

- Replace `./gascity/examples/gastown/packs/gastown-jj` with
  `./packs/gastown-jj`.
- Replace owned LazyJJ/Gas Town workflow references with `./packs/<pack>`.
- Decide whether `beads-doltlite` and `jj-spr` should become registry-owned
  packs before replacing their example paths.

Acceptance criteria:

- The edit starts in a new jj change and the change description names the
  intended `city.toml` alignment.
- No owned workflow pack is imported from `./gascity/examples/...`.
- Remaining `./gascity/examples/...` includes are explicitly classified as
  fixtures or runtime/system built-ins.

Dependencies:

- `Classify pack ownership`
- `Normalize root live pack bindings`

Files:

- `/data/projects/doltlite-gascity/city.toml`

Verification:

- `gc config show`
- `gc prime`
- Search `city.toml` for remaining `./gascity/examples/` includes and confirm
  each one is intentionally classified.

### 5. Demote duplicate example packs to fixtures

Formula: `mol-polecat-lazyjj-work`

Description:
For packs duplicated between `gascity-packs` and `gascity/examples`, make the
`gascity-packs` copy the canonical source and update the example copy so it is
clearly a fixture or removed from runtime import paths.

Initial overlaps:

- `gastown`
- `gastown-jj`
- `gastown-lazyjj`

Acceptance criteria:

- Example copies do not carry newer behavior than the `gascity-packs` copy.
- Example docs point to the registry-owned canonical pack where appropriate.
- No root city include depends on the example copy for owned pack behavior.

Dependencies:

- `Switch root city includes to owned pack bindings`

Files:

- `/data/projects/doltlite-gascity/gascity/examples/gastown/`
- `/data/projects/doltlite-gascity/gascity/examples/gastown/packs/`
- `gascity-packs/gastown/`
- `gascity-packs/gastown-jj/`
- `gascity-packs/gastown-lazyjj/`

Verification:

- Compare manifests and key prompt/formula surfaces for the duplicate pack
  names.
- Confirm only the `gascity-packs` copies are used by the root city.

### 6. Decide and migrate example-only packs

Formula: `mol-polecat-lazyjj-work`

Description:
For each example-only pack, decide whether it should become a registry-owned
pack, stay as a built-in/runtime fixture, or stay as a product demo.

Example-only pack list:

- `bd`
- `beads-doltlite`
- `dolt`
- `hyperscale`
- `jj-spr`
- `lifecycle`
- `maintenance`
- `swarm`
- `t3bridge-gastown`
- `t3demo`

Acceptance criteria:

- Each pack has an explicit disposition.
- Packs needed by this city at runtime are either registered in
  `gascity-packs` or documented as intentionally loaded from `gascity/examples`.
- Migration candidates get follow-up registry and live-binding beads.

Dependencies:

- `Classify pack ownership`

Files:

- `gascity-packs/docs/design/`
- `/data/projects/doltlite-gascity/gascity/examples/`
- `/data/projects/doltlite-gascity/city.toml`

Verification:

- Inventory shows no unclassified `gascity/examples/**/pack.toml`.

### 7. Add an alignment check

Formula: `mol-polecat-lazyjj-work`

Description:
Add a focused validation check that flags source drift between registry-owned
packs, root live bindings, and `city.toml` includes.

Acceptance criteria:

- The check reports registry-owned packs without a local `gascity-packs`
  directory.
- The check reports local owned packs missing from `registry.toml`.
- The check reports root `city.toml` includes that point to
  `./gascity/examples/...` for packs classified as `gascity-packs canonical`.
- The check reports dead `./packs` bindings that lack `pack.toml`.

Dependencies:

- `Classify pack ownership`
- `Register all owned local packs`
- `Switch root city includes to owned pack bindings`

Files:

- `gascity-packs/scripts/`
- `gascity-packs/tests/`
- `gascity-packs/validate_registry.py`

Verification:

- `python3 -m pytest tests/test_validate_registry.py -q`
- Run the new alignment check against the current checkout.

## Dispatch Order

1. `Classify pack ownership`
2. `Normalize root live pack bindings`
3. `Register all owned local packs`
4. `Switch root city includes to owned pack bindings`
5. `Demote duplicate example packs to fixtures`
6. `Decide and migrate example-only packs`
7. `Add an alignment check`

## Open Decisions

- Should `beads-doltlite`, `bd`, `dolt`, and `maintenance` remain runtime
  built-ins under the `gascity` repo, or should this city consume them through
  `gascity-packs` as registry-owned packs?
- Should `jj-spr` be migrated into `gascity-packs`, or remain an example pack
  because LazyJJ replaces the intended workflow?
- Should Slack and Discord packs be registered immediately, or only after their
  service binaries and release hashes are ready for stable external use?
- Should root `/data/projects/doltlite-gascity/packs` allow backup directories,
  or should backups always live outside runtime pack discovery paths?

