---
name: gascity-jj-mayor
description: Use alongside the imported mayor skill when a Gas City rig imports gascity-jj-base, or whenever Mayor work should create, route, or inspect workflow documents tracked under the default@ artifact root.
---

# Gas City JJ Mayor

Use this skill with the imported `mayor` skill. The upstream Mayor contract still
owns requirements interviews, implementation plans, bead creation, approval
gates, and formula launches. This extension changes where workflow documents
live and how the Mayor passes them between formulas.

## Document Location

When shaping new work, determine the target rig/root path, plan slug, root bead
or work root, and artifact root before creating beads or launching formulas.

Default generated workflow documents to the `default@` checkout. The live bead
database remains DoltLite; the artifact root and manifest are the durable
document/evidence surface.

Record these root-level fields on the workflow root bead when they are known:

- `gc.docs.workspace`
- `gc.docs.workspace_path`
- `gc.docs.base_revset=default@`
- `gc.docs.artifact_root`
- `gc.docs.manifest_path`
- `gc.docs.source_workspace`
- `gc.docs.source_workspace_path`
- `gc.docs.change_id`

Use an artifact root under the `default@` checkout, for example
`plans/<root-bead-id>/`. Keep paths concrete enough that later agents can open
the exact files without relying on prompt context.

## Document Handoff

Prefer a checked-in `manifest.json` over passing full document bodies through
bead notes, comments, or prompts. The manifest should name each workflow
document, its schema or phase, its path under the default@ artifact root, its hash,
and the jj change ID that last updated it.

For each generated document, record bead metadata using a metadata-safe document
key. Replace characters outside the Beads metadata key alphabet with
underscores; for example, the document `implementation-summary` uses
`implementation_summary` in metadata keys.

Record bead metadata using the pattern:

- `gc.docs.<name>.path`
- `gc.docs.<name>.schema`
- `gc.docs.<name>.hash`
- `gc.docs.<name>.change_id`

When launching formulas, pass the manifest path only when overriding the default
artifact root. Otherwise the jj formulas default to `docs_workspace=default` and
`docs_base_revset=default@`:

```bash
gc sling gc.run-operator <workflow-root-bead-id> --on <jj-formula-name> \
  --var artifact_root=plans/<root-bead-id>
```

Source edits should follow the packer-style workspace lane without relying on
agent pre-start hooks. The formula setup step creates or reuses a source
workspace under `.gc/workspaces/<rig>/packs/<pack>`, or a child workspace under
that pack when `gc.pack_workspace` is present, and records
`gc.docs.source_workspace` plus `gc.docs.source_workspace_path` before source
describe/edit/review/publish steps run. Keep workflow documents in `default@`.

## Fork Stack Template

Use this template when the rig is a fork that contributes changes back to an
upstream repository while carrying local integration work, such as a DoltLite
stack for Gas City. The goal is a clean, topical stack that can be repeatedly
rebased onto upstream `main`, tested, and split into PRs. As upstream accepts
pieces, the carried stack should get smaller.

Use the upstream remote as the rebase base and the fork remote as the push
target:

```toml
git.fetch = ["upstream"]
git.push = "origin"
revset-aliases."trunk()" = "main@upstream"
```

Keep the meanings stable:

- `main@upstream` is the upstream project `main` and the `trunk()` base.
- Local `main` should stay at parity with `main@upstream` when following the
  standard fork-contribution workflow.
- The fork's carried work should live on a separate stack bookmark, for example
  `gc/<topic>` or another review/integration bookmark, not as local `main`.
- `origin` is the publication target for that stack.

The normal maintenance loop is:

```bash
jj git fetch --remote upstream
jj bookmark set main -r main@upstream
jj rebase -s <stack-root-change-id> -d main@upstream
jj log -r 'main@upstream::<stack-head-change-id>' --no-graph
```

After the rebase, run the focused tests and local integration checks that prove
the stack still works. Publish from explicit stack bookmarks; do not rely on a
detached Git HEAD or an ambiguous bare `main`.

If `main` becomes conflicted because both `main@upstream` and `main@origin` are
tracked while the fork intentionally diverges, resolve the workflow first:
decide whether local `main` represents upstream parity or the fork integration
head, then move the local bookmark explicitly with `jj bookmark set main -r
<revision>`. For the standard contribution workflow, prefer upstream parity and
keep fork work on the separate stack bookmark.

## Formula Selection

Prefer the jj-aware formulas from this pack once they exist:

- `jj-build`
- `jj-planning-base`
- `jj-decomposition-base`
- `jj-implement`
- `jj-do-work`
- `jj-do-work-item`
- `jj-review`
- `jj-fix-loop`
- `jj-publish`

Use the imported base formulas only when a jj variant is absent or the user
explicitly asks for the generic Gas City path. If falling back, still keep
workflow documents under the default@ artifact root and record the manifest
fields.

## Parallel Work

For parallel drains, avoid multiple workers writing the same manifest or report
file at the same time. Use per-item document roots, then have the coordinating
formula integrate those documents into the root manifest.

## Mayor Response

When reporting work setup or a launch, include the DoltLite bead IDs plus the
artifact root, manifest path, and jj change ID if it is known. Do not infer
workflow completion from a successful launch.
