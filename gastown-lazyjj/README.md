# gastown-lazyjj

LazyJJ workspace and stack workflow pack for Gas Town jj workers.

## What this pack adds

- `jedi` named sessions for rig-scoped LazyJJ workers
- the `mol-polecat-lazyjj-work` formula for workspace-bound stack work
- the `lazyjj-workspace` skill for quick reference
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
6. publish with `jj spr diff --cherry-pick` for independent PRs, or
   `jj spr diff --all` for a dependent stack
7. land in order and keep the workspace clean

## Pack entry points

- [`pack.toml`](./pack.toml)
- [`agents/jedi/prompt.template.md`](./agents/jedi/prompt.template.md)
- [`formulas/mol-polecat-lazyjj-work.toml`](./formulas/mol-polecat-lazyjj-work.toml)
- [`formulas/mol-lazyjj-spr-publish.toml`](./formulas/mol-lazyjj-spr-publish.toml)
- [`skills/lazyjj-workspace/SKILL.md`](./skills/lazyjj-workspace/SKILL.md)
