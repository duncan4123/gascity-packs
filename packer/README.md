# Packer

`packer` provides pack-routed agent workspaces for maintaining `gascity-packs`
one pack at a time.

## Model

- `packrouter` lives in the rig root and routes broad requests.
- `packsmith` is one shared pool template. It implements one routed pack bead
  per session from a sparse jj workspace.
- `gc.pack` on the bead is the route key, such as `jj-hunk`.
- `gc.pack_root` on the bead is the pack directory inside the rig. In
  `gascity-packs`, the default value is the same as `gc.pack`.
- `work_dir` is a neutral anchor for the shared pool template. GC rewrites the
  concrete session work dir from bead metadata before `pre_start` runs.
- Triggered pool work defaults to the pack-named integration workspace. Set
  `gc.pack_workspace` only when a bead needs a child workspace below that pack,
  such as a task-specific workspace.
- `pre_start` reads the trigger bead metadata, delegates workspace creation to
  `jjw`, then sparse-checks out the target pack directory plus shared
  registry/test files.

This lets a formula route work to an agent in a workspace that contains
`jj-hunk/` without checking out every other pack directory.

Workflow diagrams:

- [Pack workflow overview](docs/diagrams/workflow-overview.md)
- [Release workflow](docs/diagrams/release-workflow.md)
- [Bookmark lifecycle](docs/diagrams/bookmark-lifecycle.md)
- [Pack workspace reuse](docs/diagrams/pack-workspace-reuse.md)
- [Task workspace](docs/diagrams/task-workspace.md)

## Workflows

### 1. Packsmith work

Packsmiths run `mol-packer-work` from sparse jj workspaces. Each logical change
passes through `mol-jj-change`. The pack-named workspace
`.gc/workspaces/<rig>/packs/<pack>` is the integration lane for that pack.
Child workspaces under it land back into the pack workspace. When the pack
workspace is complete, `mol-packer-complete` integrates the pack work onto
`default@` so it can be tested in a running Gas City.

Rebase onto `default@` only when the bead, formula step, or situation requires
it. Do not rebase after every trivial change by default.

### 2. Local integration test

After packsmiths integrate work onto `default@`, run Gas City from the rig-root
default workspace and have agents use the pack. `default@` is the local
integration and testing head, not the release target.

### 3. Release to GitHub

The release workflow runs from `default@` after live testing. It fetches,
rebases local `main` onto `main@origin` if needed, merges the tested `default@`
state, moves `main`, verifies, and pushes.

See [Workflow overview](docs/diagrams/workflow-overview.md) and
[Release workflow](docs/diagrams/release-workflow.md) for diagrams.

## Router Agent

`packrouter` uses `mol-packer-route` from `{{.RigRoot}}`. It can inspect the
full packs repository, choose target packs, create child beads, and dispatch
each child bead to the shared packsmith pool.

Typical route shape:

```bash
gc sling <pack-agent-target> <child-bead-id>
```

The child bead should name the target pack in its title and metadata. For the
default reusable pack workspace, omit `gc.pack_workspace`:

```text
gc.pack=jj-hunk
gc.pack_root=jj-hunk
```

GC derives the workspace path from the pack:

```text
.gc/workspaces/<rig>/packs/<pack>
```

The jj bookmark for the pack-named integration workspace is:

```text
gc/<pack>
```

Child workspace bookmarks use a flat pack namespace:

```text
gc/<pack>.<workspace>
```

Do not use `gc/<pack>/<workspace>`; it conflicts with existing Git refs such as
`gc/packer`.

For work that needs a named child workspace below the pack, add:

```text
gc.pack_workspace=existing-workspace
```

`gc.pack_workspace` is a workspace key under the pack directory. It is not a
path and must not contain slashes. The child workspace starts from the pack
integration head when available and lands back into the pack-named workspace.

## Shared Packsmith Agent

The bundled packsmith agent is intentionally not per-pack:

```toml
work_dir = ".gc/workspaces/{{.Rig}}/packs/__packsmith__"
pre_start = ["\"$GC_RIG_ROOT/packer/assets/scripts/pack-workspace-setup.sh\" --sync"]
```

Do not create one packsmith agent per pack for normal routing. The child bead
selects the actual pack with `gc.pack` and `gc.pack_root`. `GC_PACKER_PACK` is
only a manual/debug fallback for running the setup script outside a routed bead.

For repos that nest packs, put the nested path in bead metadata, for example
`gc.pack_root=packs/jj-hunk`.

## Bead Routing

Pack-maintenance parent beads can be assigned to `packrouter`. Implementation
child beads should be assigned or slung to the shared packsmith pool running
`mol-packer-work`.

Every implementation bead should name the target pack in the title, notes,
formula context, or metadata. `mol-packer-work` expects the sparse checkout to
match the bead's `gc.pack` route before editing.

Use the router helper to create implementation beads:

```bash
packer/assets/scripts/create-pack-bead.sh \
  --parent <parent-bead-id> \
  --pack jj-hunk \
  --pack-root jj-hunk \
  --title "jj-hunk: fix sparse hunk workspace setup" \
  --description "Make the hunk workspace setup deterministic." \
  --acceptance "gc lint jj-hunk passes"
```

The helper reuses the pack workspace by default. It writes `gc.pack` /
`gc.pack_root` metadata, then runs
`gc sling <rig>/packer.packsmith <child-bead-id>`. Do not add
`--on mol-packer-work`: `packer.packsmith` already declares that formula, and
`--on` launches through a formula root that does not carry the child bead's pack
metadata before `pre_start` needs it.

To route work into an explicit named workspace, add:

```bash
--workspace existing-workspace
```

That writes `gc.pack_workspace=existing-workspace` on the child bead. To force a
workspace named from the child bead id and title, add:

```bash
--task-workspace
```

When the target does not match the current sparse workspace, stop and report the
mismatch instead of editing from the wrong checkout.

## Pack `packer_mode` Self-Review

Imported packs can use the packer-provided self-review and handoff formulas
instead of reimplementing pack routing:

- `mol-packer-self-review` writes structured pack-improvement findings.
- `mol-packer-improvement-handoff` turns concrete findings into normal
  `mol-packer-work` beads routed to packsmith.

The shared mode variable is `packer_mode`:

| value | behavior |
| --- | --- |
| `off` | do not run packer self-review or handoff behavior |
| `self-review` | inspect the pack and write findings only |
| `handoff` | consume existing findings and create packsmith work beads |
| `self-review-handoff` | write findings, then hand concrete findings to packsmith |

These values are exact. `normal`, `dev`, `self_review`, and other spellings are
not accepted aliases; use `off` when an imported workflow should behave
normally without packer review or handoff work.

The top-level `gc.packer.pack-improvement-findings.v1` artifact is the
canonical handoff contract for imported packs. Individual findings inside the
artifact use `gc.packer.pack-improvement-finding.v1` so handoff code can route
claim-sized child beads without treating each finding as a standalone contract.

Findings use this top-level JSON shape:

```json
{
  "schema": "gc.packer.pack-improvement-findings.v1",
  "packer_mode": "self-review",
  "source": {
    "pack": "target-pack",
    "pack_root": "target-pack",
    "workspace": "optional-source-workspace",
    "change_id": "optional-source-change-id"
  },
  "findings": [
    {
      "schema": "gc.packer.pack-improvement-finding.v1",
      "id": "PKR-001",
      "severity": "P2",
      "title": "target-pack: fix concrete pack issue",
      "pack": "target-pack",
      "pack_root": "target-pack",
      "pack_workspace": "optional-child-workspace",
      "description": "Specific work for packsmith to perform.",
      "acceptance": "gc lint target-pack passes",
      "evidence": [
        {"path": "target-pack/file", "line": 12, "note": "Why this matters."}
      ]
    }
  ]
}
```

`pack_workspace` is optional. Omit it when the follow-up should use the
pack-named integration workspace; set it only for a named child workspace.

The handoff formula writes `gc.pack`, `gc.pack_root`, `gc.formula`,
`gc.route_target`, and optional `gc.pack_workspace` only on generated child
beads. Generated child beads may also carry `gc.packer.finding_id`,
`gc.packer.findings_path`, `gc.packer.findings_schema`, and `gc.packer.mode`
when they came from a findings artifact. Its own review and handoff steps use
`gc.packer.*` metadata plus the `gc.docs.source_*` keys used by
gascity-jj-base document workflows, so ordinary non-pack workflow steps do not
inherit pack workdir routing.
