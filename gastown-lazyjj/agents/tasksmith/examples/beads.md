# Tasksmith Example Beads

These examples are for the LazyJJ tasksmith agent. They are intentionally
small, stack-aware, and bead-shaped.

## Example 1: Split tutorial skills

```yaml
title: "Split LazyJJ tutorial skills"
type: task
priority: 2
description: |
  Break the LazyJJ guidance into tutorial-specific skills and update the pack
  documentation so the workflow is easier to learn in steps.
acceptance_criteria:
  - Tutorial skills exist for the main LazyJJ learning paths.
  - The README points to the right skills.
  - No stale `spr` wording remains.
dependencies: []
files:
  - gastown-lazyjj/skills/
  - gastown-lazyjj/README.md
verification:
  - rg -n "spr" gastown-lazyjj returns no matches
```

## Example 2: Add tasksmith agent

```yaml
title: "Add a taskcraft agent"
type: task
priority: 2
description: |
  Add an agent that produces LazyJJ-native task beads and includes example
  bead shapes for future planning work.
acceptance_criteria:
  - The agent prompt names the LazyJJ tutorial skills.
  - Example beads are included with the agent.
  - The agent is wired into the pack manifest.
dependencies: []
files:
  - gastown-lazyjj/agents/tasksmith/
  - gastown-lazyjj/pack.toml
verification:
  - The new named session appears in the pack manifest
```

## Example 3: Publish a stack

```yaml
title: "Create a publish-ready LazyJJ stack"
type: task
priority: 3
description: |
  Build a small stack, bookmark the tail, push it to GitHub, and open the PRs
  in order without using any unsupported `jj spr` commands.
acceptance_criteria:
  - The stack has clear checkpoint commits.
  - The tail bookmark is set and pushed.
  - The PRs are opened with `gh pr create`.
dependencies: []
files:
  - gastown-lazyjj/formulas/mol-lazyjj-publish.toml
verification:
  - gh pr list shows the published branch
```
