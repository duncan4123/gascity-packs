# Gas City JJ Base Pack

`gascity-jj-base` is a thin extension pack over the upstream-owned Gas City base
pack. It imports `gascity` for the workflow contracts and `jjw` for jj workspace
support. It does not copy the base pack.

## Starting Contract

The first integration step is to keep Gas City workflow documents in the
`default@` checkout.

The live bead database remains DoltLite. Generated workflow documents are
normal files under the build artifact root in that checkout:

- requirements
- implementation plans
- decomposition/task documents
- review reports
- implementation summaries
- final reports

Use an `artifact_root` under the `default@` checkout, such as:

```sh
--var artifact_root=plans/<run-name>
```

The document owner is the default jj workspace. Later jj-specific formulas can
record the artifact path, jj change ID, and content hash back onto the workflow
root bead.

Source edits follow the packer workspace model, but the workspace setup remains
inside the formula graph instead of agent pre-start hooks. Formula steps create
or refresh a pack-named source workspace under
`.gc/workspaces/<rig>/packs/<pack>`, use optional child workspaces below that
path when `gc.pack_workspace` is present, and record both
`gc.docs.source_workspace` and `gc.docs.source_workspace_path` before source
describe/edit/review/publish steps run. Source workspaces land back through the
pack-named source workspace before any tested state moves to `default@`.

## Ownership Boundary

This pack should extend the imported `gascity` contracts instead of editing or
copying upstream-owned base formulas. JJ-specific behavior belongs here:

- default@ document conventions
- jj path and revset setup through `jjw`
- packer-style source workspace lanes driven by formula steps
- artifact path to jj change metadata
- source-editing semantics
- explicit bookmark and publish behavior

The imported `gascity` pack continues to own generic workflow schemas,
validators, base formulas, and default role surfaces.

## Mayor Overlay

This pack adds `gascity-jj-mayor`, a companion skill for the imported `mayor`
skill. It tells the Mayor to keep requirements, plans, reviews, reports, and
other workflow documents under the `default@` artifact root, pass
`manifest.json` between formulas, and record document paths/hashes/change IDs on
DoltLite beads.

## Formula Surface

See [Formula Improvement Plan](docs/formula-improvement-plan.md) for the
jj-native formula extension plan. This pack now provides the initial formula
surface:

- `jj-build`
- `jj-planning-base`
- `jj-decomposition-base`
- `jj-implement`
- `jj-do-work`
- `jj-do-work-item`
- `jj-review`
- `jj-fix-loop`
- `jj-publish`
