# Clean History Workflow Gap Analysis Source

Use this source document to evaluate what `gascity-jj-base` should support for
JJ clean-history workflows. The goal is to identify gaps between useful
clean-history scenarios, formula variables, workspace routing metadata, and
agent/task descriptions.

## Scenarios

### 1. Single Messy Local Change

Task description:

Split the current broad `@` change into a clean narrative stack. Preserve the
final diff exactly and report resulting change IDs.

Formula variables:

```text
source_workspace=<workspace-name>
source_workspace_path=<absolute-path>
source_change_id=<current-change-id>
target_revset=@
base_revset=trunk()
plan_path=<docs-path>/clean-history-plan.md
report_path=<docs-path>/clean-history-report.md
```

### 2. Existing Pack Workspace

Task description:

Clean the history in the existing pack workspace for `<pack>`. Reuse the
existing workspace; do not create a new lane.

Formula variables:

```text
source_workspace=<pack>
source_workspace_path=.gc/workspaces/<rig>/packs/<pack>
source_change_id=<change-id>
target_revset=@
base_revset=trunk()
pack=<pack>
pack_root=<pack-root>
pack_workspace=
```

### 3. Named Child Pack Workspace

Task description:

Clean history in the existing child workspace `<workspace>` under pack `<pack>`,
then report the cleaned stack for review.

Formula variables:

```text
source_workspace=<workspace>
source_workspace_path=.gc/workspaces/<rig>/packs/<pack>/<workspace>
source_change_id=<change-id>
target_revset=@
base_revset=gc/<pack>
pack=<pack>
pack_root=<pack-root>
pack_workspace=<workspace>
```

### 4. Review-Split Workspace

Task description:

Use jj-hunk clean-history on the existing review split workspace. Keep the
aggregate diff against `trunk()` identical.

Formula variables:

```text
source_workspace=gascity-review-split
source_workspace_path=/data/.../.gc/workspaces/gascity/packs/gascity-review-split
source_change_id=<change-id>
target_revset=@
base_revset=trunk()
```

### 5. Generated Code Mixed With Handwritten Code

Task description:

Separate generated files from handwritten logic so reviewers can inspect source
behavior independently from generated output.

Formula variables:

```text
source_workspace=<workspace>
source_workspace_path=<absolute-path>
source_change_id=<change-id>
target_revset=@
base_revset=trunk()
max_commits=4
plan_path=<docs-path>/generated-split-plan.md
report_path=<docs-path>/generated-split-report.md
```

### 6. Tests Mixed Into Implementation

Task description:

Split implementation and tests into separate coherent commits while preserving
the final behavior.

Formula variables:

```text
source_workspace=<workspace>
source_workspace_path=<absolute-path>
source_change_id=<change-id>
target_revset=@
base_revset=trunk()
max_commits=3
```

### 7. Large Refactor Plus Behavior Change

Task description:

Separate mechanical refactor from behavior changes. The refactor commit should
be behavior-preserving.

Formula variables:

```text
source_workspace=<workspace>
source_workspace_path=<absolute-path>
source_change_id=<change-id>
target_revset=@
base_revset=trunk()
plan_path=<docs-path>/refactor-history-plan.md
report_path=<docs-path>/refactor-history-report.md
```

### 8. Stack Already Has Multiple Bad Commits

Task description:

Clean the whole stack from `<base>` to `@`, not just the current change.
Reorder, split, and squash into a reviewable sequence.

Formula variables:

```text
source_workspace=<workspace>
source_workspace_path=<absolute-path>
source_change_id=
target_revset=@
base_revset=<base-change-or-bookmark>
max_commits=<desired-upper-bound>
```

### 9. Pre-PR Cleanup

Task description:

Prepare this workspace for PR review by turning the current working stack into
clean commits. Do not push or create a PR.

Formula variables:

```text
source_workspace=<workspace>
source_workspace_path=<absolute-path>
source_change_id=<change-id>
target_revset=@
base_revset=trunk()
report_path=<docs-path>/pre-pr-clean-history.md
```

### 10. Blocked Split Planning Only

Task description:

Inspect the current change and write a clean-history split plan, but do not
mutate JJ history yet.

Formula variables:

```text
source_workspace=<workspace>
source_workspace_path=<absolute-path>
source_change_id=<change-id>
target_revset=@
base_revset=trunk()
plan_path=<docs-path>/clean-history-plan.md
max_commits=<optional>
mode=plan-only
```

## Common Contract

Common required inputs:

```text
source_workspace_path
target_revset
base_revset
```

Common optional inputs:

```text
source_workspace
source_change_id
plan_path
report_path
max_commits
pack
pack_root
pack_workspace
mode
```

Runtime routing metadata for existing JJ workspaces:

```text
gc.work_dir=<source_workspace_path>
work_dir=<source_workspace_path>
```
