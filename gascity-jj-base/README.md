# Gas City JJ Base Pack

`gascity-jj-base` is a thin extension pack over the upstream-owned Gas City base
pack. It imports `gascity` for the workflow contracts and `jjw` for jj
workspace support. It carries the tmux helper scripts its `session_live` hooks
use, but it does not copy the base pack.

## Quick Start

Prerequisites: Gas City installed, a city running, and the repository you want
to build in registered as a rig. If you have not done that yet:

```sh
brew install gascity
gc init ~/my-city
cd ~/my-city
gc start
mkdir proj && cd proj && jj git init && gc rig add .
```

1. **Import the pack at city scope.** From the city directory, add
   `gascity-jj-base`. This writes the city import, fetches the pack, and pins it
   in `packs.lock`:

   ```sh
   gc import add https://github.com/gastownhall/gascity-packs.git//gascity-jj-base
   ```

   Contributors working on the packs themselves can clone
   `https://github.com/gastownhall/gascity-packs` and point the city import at a
   local path instead:

   ```toml
   [imports.gascity-jj-base]
   source = "../gascity-packs/gascity-jj-base"
   ```

2. **Keep the pack-internal imports together.** `gascity-jj-base/pack.toml`
   imports the Gas City base contracts, jj workspace helpers, and packsmith
   routing formulas from sibling packs. Its `session_live` hooks use local
   tmux helper scripts in `gascity-jj-base/assets/scripts`, so the pack works
   from a git install without relying on an undeclared sibling checkout:

   ```toml
   [imports.gc]
   source = "../gascity"

   [imports.jjw]
   source = "../jjw"

   [imports.packer]
   source = "../packer"
   ```

   These are pack-internal imports. City users import `gascity-jj-base`; the
   pack brings `gc`, `jjw`, and `packer` with it. Keep the six local tmux
   helper scripts executable when publishing the pack: `tmux-theme.sh`,
   `tmux-keybindings.sh`, `status-line.sh`, `agent-menu.sh`, `bind-key.sh`,
   and `cycle.sh`.

3. **Import the rig roles in `city.toml`.** The target rig also needs the
   `gascity/roles` import so the `gc.*` role agents, including
   `gc.run-operator`, can execute work inside the rig:

   ```toml
   [rigs.imports.gc]
   source = "https://github.com/gastownhall/gascity-packs.git//gascity/roles"
   ```

   For local pack development, use the matching local roles path:

   ```toml
   [rigs.imports.gc]
   source = "../gascity-packs/gascity/roles"
   ```

   Run `gc import install` after editing imports so the city and rig resolve the
   new pack sources.

4. **Launch a JJ workflow through `gc.run-operator`.** `jj-build` is targeted
   (`target_required = true`), so create a bead for the goal and sling the
   formula at it from the target rig context:

   ```sh
   gc bd create "Move workflow documents into default@"
   gc sling gc.run-operator <bead-id> --on jj-build \
     --var docs_artifact_root=plans/jj-docs/build \
     --var drain_policy=separate
   ```

   The JJ formulas keep workflow documents under the `default@` artifact root
   while source edits move through packer-style jj workspaces.

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

Pack-aware entry points are available when the source edits themselves are pack
maintenance work. `jj-pack-build`, `jj-pack-implement`, and
`jj-pack-fix-loop` keep workflow documents in the same default@ manifest model
but route source implementation and follow-up fix steps to packsmith. The
lifecycle is:

1. The parent formula request supplies `pack`, `pack_root`, optional
   `pack_workspace`, `pack_route_target`, and `pack_route_formula` vars.
2. The pack-aware source step copies those vars into child/routed bead metadata
   as `gc.pack`, `gc.pack_root`, optional `gc.pack_workspace`,
   `gc.route_target`, and `gc.formula`.
3. Packsmith pre-start uses that metadata to select the sparse pack workspace.
4. Packsmith performs the source edits and records source workspace/change
   anchors.
5. The normal JJ summary, review, and fix-loop document steps consume those
   anchors from the manifest and bead metadata.
6. Follow-up pack fixes are routed back through the same pack metadata instead
   of re-deriving paths from titles or session names.

Pack-aware formulas also support an opt-in packer self-review layer. The
default `packer_mode=off` preserves normal behavior. `packer_mode=self-review`
asks the JJ workflow to finish the user task while evaluating the pack workflow
itself for concrete friction such as missing metadata, unclear handoffs, source
change visibility, workspace assumptions, prompt gaps, and check gaps.
`packer_mode=handoff` consumes an existing findings artifact, and
`packer_mode=self-review-handoff` writes findings and then routes concrete
follow-up work. Findings use the canonical
`gc.packer.pack-improvement-findings.v1` JSON artifact shape with
`gc.packer.pack-improvement-finding.v1` items. Handoff creates generated
packsmith child beads; `gc.pack`, `gc.pack_root`, optional
`gc.pack_workspace`, `gc.formula`, and `gc.route_target` belong on those child
beads, not on ordinary self-review or handoff steps.

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
- `jj-pack-build`
- `jj-pack-implement`
- `jj-pack-fix-loop`
