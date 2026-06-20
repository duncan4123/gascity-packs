# jj-hunk Pack

Agent-safe hunk selection workflows for Jujutsu repositories.

This pack wraps `jj-hunk-tool` and installs two skills from
`mvzink/jj-hunk-tool`:

- `jj-subagent-workspaces` for shaping isolated jj workspace tasks.
- `jj-surgeon` for implementing hunk-level jj changes safely.

## Sessions

- `tasksmith`: creates claim-sized hunk-surgery beads that follow the
  subagent workspace workflow.
- `surgeon`: implements those beads in a LazyJJ-style jj workspace.

## Commands

- `gc jj-hunk list`
- `gc jj-hunk spec`
- `gc jj-hunk split`
- `gc jj-hunk commit`
- `gc jj-hunk squash`
- `gc jj-hunk lightjj-annotate`

The hunk-editing wrappers are intentionally thin and delegate to `jj-hunk`.

`gc jj-hunk lightjj-annotate` bridges `jj-hunk-tool absorb --dry-run --debug`
into lightjj review annotations. It previews by default and only posts when
`--post` is passed.

## Formulas

- `mol-jj-hunk-work`: implement one hunk-level task.
- `mol-jj-hunk-subagent-task`: shape hunk-level work for isolated subagents.

## Checks

Run:

```bash
gc doctor --json
gc formula show mol-jj-hunk-work
gc formula show mol-jj-hunk-subagent-task
gc prime gascity-packs/jj-hunk.tasksmith --strict
gc prime surgeon --strict
```
