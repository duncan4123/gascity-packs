# Clean JJ History

Clean the source JJ history using the non-interactive `jj-hunk` methodology.

Required inputs:

- Source workspace path from `gc.docs.source_workspace_path`,
  `gc.var.source_workspace_path`, or `{{source_workspace_path}}`.
- Optional source anchor from `gc.docs.source_change_id`,
  `gc.var.source_change_id`, or `{{source_change_id}}`.
- Target revset from `{{target_revset}}` and base revset from
  `{{base_revset}}`.

Required behavior:

1. Validate the workspace:
   - `command -v jj-hunk`
   - `jj -R "$SOURCE_WORKSPACE_PATH" status`
   - `jj -R "$SOURCE_WORKSPACE_PATH" log -r '{{base_revset}}..{{target_revset}}'`
   - If a source change ID is present, verify it resolves and edit it before
     splitting when it is the intended cleanup target.
2. Capture the starting final diff:
   - `jj -R "$SOURCE_WORKSPACE_PATH" diff -r '{{base_revset}}..{{target_revset}}' --git`
   - `jj-hunk list --files` from the source workspace.
3. Plan the narrative stack before mutating history. Write the plan to the path
   selected by `gc.clean_history.plan_path`, `gc.var.plan_path`, or
   `{{plan_path}}` when a path is available. The plan must list each intended
   commit message, included path groups, risky mixed files, and verification.
4. Split iteratively with `jj-hunk`:
   - Use `jj-hunk list` before each split.
   - Build explicit JSON/YAML specs with `"default": "reset"` unless excluding
     one small residue from a mostly coherent commit.
   - Run `jj-hunk split --spec-file <spec> "<message>"` or the equivalent
     non-interactive command.
   - Use `jj describe -m "<message>"` for the final remaining change.
5. Verify each resulting commit:
   - `jj -R "$SOURCE_WORKSPACE_PATH" diff -r <change-id> --stat`
   - `jj -R "$SOURCE_WORKSPACE_PATH" show <change-id> --git` for suspicious or
     mixed commits.
6. Verify the final stack:
   - `jj -R "$SOURCE_WORKSPACE_PATH" log -r '{{base_revset}}..{{target_revset}}'`
   - Compare the final aggregate diff to the starting aggregate diff. Stop and
     report before closing if content was lost unintentionally.
7. Write a clean-history report to the path selected by
   `gc.clean_history.report_path`, `gc.var.report_path`, or `{{report_path}}`
   when a path is available. Include source workspace, starting change ID,
   resulting change IDs, commit messages, verification commands, and any
   intentionally unsplit residue.

Do not push, publish, or move bookmarks unless the user explicitly asked for
that in this workflow. Do not treat formula launch success as completion; close
the claimed step only after the history split and verification are complete.
