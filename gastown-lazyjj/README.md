# gastown-lazyjj

LazyJJ workspace and stack workflow pack for Gas Town jj workers.

## What this pack adds

- `jedi` named sessions for rig-scoped LazyJJ workers
- `tasksmith` named sessions for LazyJJ-aligned task and bead authoring
- the `mol-polecat-lazyjj-work` formula for workspace-bound stack work
- the `lazyjj-workspace` skill for implementation and handoff rules
- tutorial skills for LazyJJ foundations, stack workflow, conflicts, publishing,
  reference, Claude integration, and taskcraft
- reusable template fragments for JJ mental-model and stack workflow guidance

## Why it exists

LazyJJ is the pack layer that makes JJ feel like a practical stacked-workflow
tool for agent work. The pack keeps the runtime rules close to the session:

- the workspace owns the work
- `@` is the current head
- the stack is the graph from `trunk()` to `@`
- fixups should absorb back into the stack, not create ad hoc branches
- the review bookmark is an export handle, not the working model

## Tutorial-aligned workflow

The tutorial this pack follows boils down to:

1. inspect the stack with `jj log -r 'trunk()..@'`
2. make one focused change
3. checkpoint with `jj new -m` or `jj describe -m`
4. use `jj absorb` for late fixups
5. review with `jj diff --from branch_off`
6. set a review bookmark on the stack tail with `jj bookmark set`
7. push that bookmark with `jj git push`
8. open GitHub PRs with `gh pr create` using the stack order
9. land in order and keep the workspace clean

## Pack entry points

- [`pack.toml`](./pack.toml)
- [`agents/jedi/prompt.template.md`](./agents/jedi/prompt.template.md)
- [`agents/tasksmith/prompt.template.md`](./agents/tasksmith/prompt.template.md)
- [`formulas/mol-polecat-lazyjj-work.toml`](./formulas/mol-polecat-lazyjj-work.toml)
- [`formulas/mol-lazyjj-publish.toml`](./formulas/mol-lazyjj-publish.toml)
- [`skills/lazyjj-workspace/SKILL.md`](./skills/lazyjj-workspace/SKILL.md)
- [`skills/lazyjj-foundations/SKILL.md`](./skills/lazyjj-foundations/SKILL.md)
- [`skills/lazyjj-mental-model/SKILL.md`](./skills/lazyjj-mental-model/SKILL.md)
- [`skills/lazyjj-stack-workflow/SKILL.md`](./skills/lazyjj-stack-workflow/SKILL.md)
- [`skills/lazyjj-conflicts/SKILL.md`](./skills/lazyjj-conflicts/SKILL.md)
- [`skills/lazyjj-publishing/SKILL.md`](./skills/lazyjj-publishing/SKILL.md)
- [`skills/lazyjj-reference/SKILL.md`](./skills/lazyjj-reference/SKILL.md)
- [`skills/lazyjj-claude/SKILL.md`](./skills/lazyjj-claude/SKILL.md)
- [`skills/lazyjj-taskcraft/SKILL.md`](./skills/lazyjj-taskcraft/SKILL.md)
