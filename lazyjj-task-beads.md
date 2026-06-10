# LazyJJ Tutorial Skill Beads

## Summary

Split the LazyJJ tutorial skills into a small stack of claimable beads so the
workflow stays aligned to the current LazyJJ mental model, stack workflow, and
bookmark-first publishing flow.

## Acceptance Criteria

- Each bead is small enough to be claimed and finished independently.
- The bead order follows the tutorial stack: foundations, stack workflow,
  publishing/reference, taskcraft, then pack cross-links.
- Each bead names concrete files and includes verification steps.
- No stale `spr` wording remains in the tutorial-facing LazyJJ docs.

## Dependencies

- `lazyjj-foundations` and `lazyjj-mental-model` establish the base vocabulary.
- `lazyjj-stack-workflow` and `lazyjj-conflicts` define the middle of the stack.
- `lazyjj-publishing` and `lazyjj-reference` close out publish and inspect flow.
- `lazyjj-taskcraft` should come after the stack language is stable so its
  example beads match the tutorial wording.

## File Targets

- `gastown-lazyjj/skills/lazyjj-foundations/SKILL.md`
- `gastown-lazyjj/skills/lazyjj-mental-model/SKILL.md`
- `gastown-lazyjj/skills/lazyjj-stack-workflow/SKILL.md`
- `gastown-lazyjj/skills/lazyjj-conflicts/SKILL.md`
- `gastown-lazyjj/skills/lazyjj-publishing/SKILL.md`
- `gastown-lazyjj/skills/lazyjj-reference/SKILL.md`
- `gastown-lazyjj/skills/lazyjj-taskcraft/SKILL.md`
- `gastown-lazyjj/README.md`

## Verification Steps

- `rg -n "spr" gastown-lazyjj`
  returns no stale LazyJJ tutorial references.
- Manual review confirms each skill points to the correct tutorial topic and
  uses stack-aware language.
- Manual review confirms the bead order is dependency-safe and claimable one at
  a time.

## Proposed Beads

```yaml
key: refresh-lazyjj-foundations-mental-model
title: "Refresh LazyJJ foundations and mental model"
formula: mol-polecat-lazyjj-work
type: task
priority: 2
description: |
  Rework the foundation and mental-model tutorial skills so they teach the
  LazyJJ baseline first: install, quick start, operation log, graph-aware git
  differences, and the stack-aware mistakes that matter while editing a stack.
acceptance_criteria:
  - The foundations skill covers install and quick-start steps in tutorial
    language.
  - The mental-model skill explains operation log, bookmarks, and why history
    rewrites cascade through descendants.
  - The wording matches the source-of-truth tutorial style instead of adding
    new jargon.
dependencies: []
files:
  - gastown-lazyjj/skills/lazyjj-foundations/SKILL.md
  - gastown-lazyjj/skills/lazyjj-mental-model/SKILL.md
verification:
  - rg -n "spr" gastown-lazyjj/skills/lazyjj-foundations gastown-lazyjj/skills/lazyjj-mental-model returns no stale wording
  - Manual review of the two skills shows the tutorial order is install -> quick start -> stack mental model
```

```yaml
key: tighten-lazyjj-stack-workflow-conflicts
title: "Tighten LazyJJ stack workflow and conflict handling"
formula: mol-polecat-lazyjj-work
type: task
priority: 2
description: |
  Update the stack workflow and conflict skills so they read like one
  contiguous workflow: create a stack, navigate it, edit mid-stack, and treat
  conflicts as a normal part of rewriting history.
acceptance_criteria:
  - The stack workflow skill shows create, navigate, and edit-mid-stack steps.
  - The conflicts skill explains how to resolve conflicts without losing the
    stack shape.
  - The two skills agree on the same checkpoint and rebase language.
dependencies:
  - refresh-lazyjj-foundations-mental-model
files:
  - gastown-lazyjj/skills/lazyjj-stack-workflow/SKILL.md
  - gastown-lazyjj/skills/lazyjj-conflicts/SKILL.md
verification:
  - Manual review confirms the flow is stack-first, not command-first
  - No stale "conflicts are exceptional" framing remains in either skill
```

```yaml
key: rewrite-lazyjj-publishing-reference
title: "Rewrite LazyJJ publishing and reference guidance"
formula: mol-polecat-lazyjj-work
type: task
priority: 3
description: |
  Bring the publishing and reference skills in line with the bookmark-first
  LazyJJ publish flow and the native stack-inspection vocabulary. The goal is
  to make the publish path and the inspection path feel like one workflow.
acceptance_criteria:
  - The publishing skill prioritizes bookmarks, remote sync, and PR creation.
  - The reference skill teaches aliases and revsets as inspection tools, not as
    hidden magic.
  - No `jj spr` wording remains in the publishing guidance.
dependencies:
  - tighten-lazyjj-stack-workflow-conflicts
files:
  - gastown-lazyjj/skills/lazyjj-publishing/SKILL.md
  - gastown-lazyjj/skills/lazyjj-reference/SKILL.md
verification:
  - rg -n "spr" gastown-lazyjj/skills/lazyjj-publishing gastown-lazyjj/skills/lazyjj-reference returns no matches
  - Manual review confirms the publish flow is bookmark-first and the inspect flow is revset-aware
```

```yaml
key: expand-lazyjj-taskcraft-with-examples
title: "Expand LazyJJ taskcraft with stack-aware example beads"
formula: mol-polecat-lazyjj-work
type: task
priority: 3
description: |
  Turn the taskcraft skill into a reusable bead-shape guide with example beads
  that show clean dependencies, file targets, and verification steps. The
  examples should read like real stack work, not abstract planning notes.
acceptance_criteria:
  - The taskcraft skill includes at least one stack-aware bead shape.
  - The examples show how to write claimable beads with clear dependencies.
  - The examples use the same tutorial language as the other skills.
dependencies:
  - refresh-lazyjj-foundations-mental-model
  - tighten-lazyjj-stack-workflow-conflicts
files:
  - gastown-lazyjj/skills/lazyjj-taskcraft/SKILL.md
verification:
  - Manual review confirms the example beads are small enough to claim independently
  - The example beads include dependencies, file targets, and verification steps
```

```yaml
key: refresh-lazyjj-pack-cross-links
title: "Refresh LazyJJ pack cross-links and index"
formula: mol-polecat-lazyjj-work
type: task
priority: 4
description: |
  Update the LazyJJ pack README so it points to the finished tutorial skills in
  a stack-aware order and does not leave stale links or out-of-date phrasing in
  the index page.
acceptance_criteria:
  - The README points to the right skill for each tutorial topic.
  - The pack index reflects the same order as the bead stack.
  - The README does not reintroduce stale `spr` wording.
dependencies:
  - rewrite-lazyjj-publishing-reference
  - expand-lazyjj-taskcraft-with-examples
files:
  - gastown-lazyjj/README.md
verification:
  - rg -n "spr" gastown-lazyjj/README.md returns no stale wording
  - Manual review confirms the README links are in the same order as the bead dependency chain
```
