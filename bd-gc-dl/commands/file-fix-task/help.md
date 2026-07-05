# gc bd-gc-dl file-fix-task

File a focused repair task for the `bd-gc-dl-fixer` agent and route it
immediately.

```bash
gc bd-gc-dl file-fix-task --summary "bd list fails in rig beads" \
  --command "bd list --json --limit 1" \
  --scope "plugin-backed beads rig" \
  --evidence ".gc/diagnostics/bd-gc-dl/bd-list-failure.md"
```

Options:

- `--summary TEXT`: short symptom for the issue title.
- `--command TEXT`: command that failed.
- `--scope TEXT`: city, rig, repo, or bead scope affected.
- `--evidence PATH`: evidence file or directory.
- `--details TEXT`: extra context.
- `--from-bead ID`: original bead blocked by the failure.
- `--target NAME`: specialist route target. Defaults to `bd-gc-dl-fixer`.
