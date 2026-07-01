# gascity-jj-base Sling Review Fix Plan

Schema: `gc.review.fix-plan.v1`
Source workspace: `gascity-packs`
Source workspace path: `/data/projects/doltlite-gascity/gascity-packs`
Reviewed source change: `tynmlvxmoqkw` (`a8e075e1dc58`)
Current source fix change: `wwppnzmw` (`a62e1259ad7a`)
Review document: `gascity-jj-base/reviews/pack-review-2026-06-22-sling/review.md`
Review change: `xylxutzm`
Fix-plan document change: `vquuztqrwtmzxqpmunrrmruorsquzsqk`
Manifest: `gascity-jj-base/reviews/pack-review-2026-06-22-sling/manifest.json`

## Intent

Apply the single P2 review finding from the sling review: the `jj-fix-loop`
document-scoped describe steps must carry the document workspace metadata
required by `describe-jj-change.md`.

The source workspace and change identities above are authoritative for this
handoff. `tynmlvxmoqkw` is the reviewed source change; `wwppnzmw` is the source
fix change recorded in the manifest after fix application.

## Required Source Fix

Update `gascity-jj-base/formulas/jj-fix-loop.formula.toml`:

- In step `describe-fix-plan-change`, add:
  - `gc.docs.workspace_key = "gc.docs.workspace,gc.var.docs_workspace"`
  - `gc.docs.workspace_path_key = "gc.docs.workspace_path,gc.var.docs_workspace_path"`
- In step `describe-re-review-change`, add the same two metadata keys.

Preserve the existing `gc.docs.manifest_path_keys` and
`gc.docs.source_change_id_key` metadata. Do not change the source-scoped
`describe-source-fix-change` step; it already uses source workspace metadata.

## Required Regression Test

Extend `gascity-jj-base/tests/test_gascity_jj_base_pack.py`, preferably in or
next to `test_every_formula_has_concrete_describe_step`, so every describe step
with `gc.jj.describe_scope == "document"` must declare:

- `gc.docs.workspace_key`
- `gc.docs.workspace_path_key`

Assert the canonical values exactly:

- `gc.docs.workspace,gc.var.docs_workspace`
- `gc.docs.workspace_path,gc.var.docs_workspace_path`

The test should fail on the current `jj-fix-loop.formula.toml` before the
formula metadata is patched, and pass after both document-scoped describe steps
are fixed.

## Verification

Run the focused pack test:

```bash
pytest -q gascity-jj-base/tests/test_gascity_jj_base_pack.py
```

## Manifest Handoff

Keep the manifest at
`gascity-jj-base/reviews/pack-review-2026-06-22-sling/manifest.json` as the
handoff document. Downstream fix application must keep `documents.fix_plan`
present, update `source.change_id` and `source.commit_id` if the source fix is
rewritten, and refresh implementation/re-review document entries without
removing this fix-plan entry.
