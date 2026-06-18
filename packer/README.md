# Packer

`packer` provides pack-routed agent workspaces for maintaining `gascity-packs`
one pack at a time.

## Model

- `packrouter` lives in the rig root and routes broad requests.
- `packsmith` lives in a sparse jj workspace and implements one pack bead.
- `pack` is the route key and workspace name, such as `jj-hunk`.
- `pack_root` is the pack directory inside the rig. In `gascity-packs`, the
  default layout is `pack_root = "{{.Pack}}"`.
- `work_dir` is the jj workspace created for the agent. It must resolve inside
  the `workspace_dir` declared by `jjw` for this rig. In `gascity-packs` that is
  `../.gc/workspaces/{{.Rig}}/jedi/{{.AgentBase}}`.
- `pre_start` delegates workspace creation to `jjw`, then sparse-checks out the
  target pack directory plus shared registry/test files.

This lets a formula route work to an agent in a workspace that contains
`jj-hunk/` without checking out every other pack directory.

## Router Agent

`packrouter` uses `mol-packer-route` from `{{.RigRoot}}`. It can inspect the
full packs repository, choose target packs, create child beads, and dispatch
each child bead to a pack-scoped worker.

Typical route shape:

```bash
gc sling <pack-agent-target> <child-bead-id> --on mol-packer-work
```

The child bead should name the target pack in its title and notes or metadata,
for example:

```text
gc.pack=jj-hunk
gc.pack_root=jj-hunk
```

## Per-Pack Agent Variants

Define or patch an agent per target pack:

```toml
pack = "jj-hunk"
pack_root = "{{.Pack}}"
work_dir = "../.gc/workspaces/{{.Rig}}/jedi/{{.AgentBase}}"
pre_start = ["GC_PACKER_PACK={{.Pack}} {{.PackRoot}}/assets/scripts/pack-workspace-setup.sh {{.RigRoot}} {{.WorkDir}} {{.AgentBase}} {{.PackRoot}} --sync"]
```

For repos that nest packs, use a different root:

```toml
pack = "jj-hunk"
pack_root = "packs/{{.Pack}}"
```

## Bead Routing

Pack-maintenance parent beads can be assigned to `packrouter`. Implementation
child beads should be assigned or slung to pack agents running
`mol-packer-work`.

Every implementation bead should name the target pack in the title, notes,
formula context, or metadata. `mol-packer-work` expects the claimed bead target
to match the session's `pack` route before editing.

When the target does not match the current sparse workspace, reroute the bead to
the correct pack agent instead of editing from the wrong checkout.
