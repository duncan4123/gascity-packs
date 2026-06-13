# LazyJJ Pack Bead Template

## Summary

Use this template to turn a pack-oriented LazyJJ request into a small set of
claimable beads. Prefer the smallest dependency chain that still keeps the work
reviewable, stack-aware, and easy to route into the correct formula.

## Bead Shaping Rules

1. Anchor the bead to the affected pack surface, not to a fixed tutorial story.
2. Keep each bead narrow enough for one workspace and one claim.
3. Use `mol-polecat-lazyjj-work` for normal implementation work.
4. Use a tutorial formula only when the bead is explicitly teaching that
   tutorial workflow.
5. Add dependencies only when one bead truly has to land before another can be
   claimed cleanly.

## Example Beads

### 1. Refresh a pack README

```yaml
title: "Refresh pack README workflow links"
type: task
priority: 2
formula: mol-polecat-lazyjj-work
description: |
  Update the pack README so the LazyJJ workflow links, routing notes, and
  stack-aware terminology match the current pack layout.
acceptance_criteria:
  - The README points to the current pack surfaces.
  - The wording matches the current LazyJJ workflow model.
  - The change stays focused on documentation and navigation.
dependencies: []
files:
  - gastown-lazyjj/README.md
verification:
  - rg -n "tasksmith|workspace|stack|formula" gastown-lazyjj/README.md
```

### 2. Add a focused pack surface bead

```yaml
title: "Add a focused pack surface bead"
type: task
priority: 2
formula: mol-polecat-lazyjj-work
description: |
  Capture one pack surface change as a claimable bead, such as a skill, agent,
  formula, or workspace helper, without bundling unrelated cleanup.
acceptance_criteria:
  - The bead names one pack surface and one ownership boundary.
  - The verification step checks the exact files touched.
  - The scope is small enough for a single jj workspace.
dependencies: []
files:
  - gastown-lazyjj/agents/tasksmith/prompt.template.md
verification:
  - The bead can be attached directly to the LazyJJ work formula
```

### 3. Teach a tutorial-specific workflow

```yaml
title: "Add a tutorial-specific LazyJJ bead"
type: task
priority: 3
description: |
  Create a bead that explicitly teaches or exercises one LazyJJ tutorial
  workflow, and route it through the matching tutorial formula instead of the
  generic work formula.
acceptance_criteria:
  - The bead names the tutorial workflow it supports.
  - The bead uses the matching `mol-lazyjj-*` formula.
  - The bead remains narrow and claimable.
dependencies: []
files:
  - gastown-lazyjj/skills/lazyjj-create-pr/SKILL.md
verification:
  - The selected formula matches the tutorial workflow
```

### 4. Add pack routing metadata

```yaml
title: "Add pack routing metadata for a bead"
type: task
priority: 2
formula: mol-polecat-lazyjj-work
description: |
  Update pack metadata so a LazyJJ bead can be discovered, routed, and claimed
  from the current pack surface without changing unrelated workflow content.
acceptance_criteria:
  - The routing metadata matches the pack convention.
  - The bead remains claim-sized.
  - The verification step checks the exact routing surface.
dependencies: []
files:
  - gastown-lazyjj/pack.toml
  - gastown-lazyjj/agents/tasksmith/agent.toml
verification:
  - The pack metadata is valid for the targeted LazyJJ surface
```

