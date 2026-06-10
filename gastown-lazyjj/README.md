# gastown-lazyjj

LazyJJ workspace and stack workflow pack for Gas Town jj workers.

## What this pack adds

- `jedi` named sessions for rig-scoped LazyJJ workers
- `tasksmith` named sessions for LazyJJ-aligned task and bead authoring
- the `mol-polecat-lazyjj-work` formula for workspace-bound stack work
- the `lazyjj-workspace` skill for implementation and handoff rules
- tutorial formulas and matching skill wrappers for LazyJJ create-PR,
  create-stack, edit-mid-stack, navigate-stack, resolve-conflicts, and
  sync-remote workflows
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

## Workspace Sync Contract

LazyJJ uses two live views of the same graph:

- the isolated jedi workspace owns implementation work
- the rig `default` workspace is the shared integration view

The canonical pack workflow is to keep both workspaces on the same integrated
stack head. When work moves from one workspace to the other:

1. pick the current stack head
2. move the target workspace to that head with `jj edit <stack-head>`
3. move the source workspace to that same head before starting the next task
4. if the source workspace still has useful local changes, keep them with
   `jj absorb` or `jj rebase` instead of copying files manually

That keeps the next round of work in either workspace based on the full,
current stack instead of a partial local view.

## Pack entry points

- [`pack.toml`](./pack.toml)
- [`agents/jedi/prompt.template.md`](./agents/jedi/prompt.template.md)
- [`agents/tasksmith/prompt.template.md`](./agents/tasksmith/prompt.template.md)
- [`formulas/mol-polecat-lazyjj-work.toml`](./formulas/mol-polecat-lazyjj-work.toml)
- [`formulas/mol-lazyjj-publish.toml`](./formulas/mol-lazyjj-publish.toml)
- [`formulas/mol-lazyjj-create-pr.toml`](./formulas/mol-lazyjj-create-pr.toml)
- [`formulas/mol-lazyjj-create-stack.toml`](./formulas/mol-lazyjj-create-stack.toml)
- [`formulas/mol-lazyjj-edit-mid-stack.toml`](./formulas/mol-lazyjj-edit-mid-stack.toml)
- [`formulas/mol-lazyjj-navigate-stack.toml`](./formulas/mol-lazyjj-navigate-stack.toml)
- [`formulas/mol-lazyjj-resolve-conflicts.toml`](./formulas/mol-lazyjj-resolve-conflicts.toml)
- [`formulas/mol-lazyjj-sync-remote.toml`](./formulas/mol-lazyjj-sync-remote.toml)
- [`skills/lazyjj-workspace/SKILL.md`](./skills/lazyjj-workspace/SKILL.md)
- [`skills/lazyjj-create-pr/SKILL.md`](./skills/lazyjj-create-pr/SKILL.md)
- [`skills/lazyjj-create-stack/SKILL.md`](./skills/lazyjj-create-stack/SKILL.md)
- [`skills/lazyjj-edit-mid-stack/SKILL.md`](./skills/lazyjj-edit-mid-stack/SKILL.md)
- [`skills/lazyjj-navigate-stack/SKILL.md`](./skills/lazyjj-navigate-stack/SKILL.md)
- [`skills/lazyjj-resolve-conflicts/SKILL.md`](./skills/lazyjj-resolve-conflicts/SKILL.md)
- [`skills/lazyjj-sync-remote/SKILL.md`](./skills/lazyjj-sync-remote/SKILL.md)
