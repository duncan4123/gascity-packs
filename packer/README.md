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
- Triggered pool work defaults to the pack workspace itself. Set
  `gc.pack_workspace` only when a bead needs a named workspace below that pack,
  such as a task-specific workspace.
- `pre_start` reads the trigger bead metadata, delegates workspace creation to
  `jjw`, then sparse-checks out the target pack directory plus shared
  registry/test files.

This lets a formula route work to an agent in a workspace that contains
`jj-hunk/` without checking out every other pack directory.

Workflow diagrams:

- [Pack workspace reuse](docs/diagrams/pack-workspace-reuse.md)
- [Task workspace](docs/diagrams/task-workspace.md)

## Router Agent

`packrouter` uses `mol-packer-route` from `{{.RigRoot}}`. It can inspect the
full packs repository, choose target packs, create child beads, and dispatch
each child bead to the shared packsmith pool.

Typical route shape:

```bash
gc sling <pack-agent-target> <child-bead-id> --on mol-packer-work
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

The jj bookmark for that workspace uses a flat pack namespace:

```text
gc/<pack>.<workspace>
```

Do not use `gc/<pack>/<workspace>`; it conflicts with existing Git refs such as
`gc/packer`.

For work that needs a named workspace below the pack, add:

```text
gc.pack_workspace=existing-workspace
```

`gc.pack_workspace` is a workspace key under the pack directory. It is not a
path and must not contain slashes.

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
`gc sling <rig>/packer.packsmith <child-bead-id> --on mol-packer-work`.

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
