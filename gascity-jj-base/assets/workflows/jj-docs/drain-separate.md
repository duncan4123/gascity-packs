# Drain JJ Work In Separate Sessions

Drain implementation work into separate sessions while preserving document
handoff.

Required behavior:

- Pass `docs_workspace`, `docs_workspace_path`, `docs_artifact_root`, and
  `manifest_path` to each item formula.
- Pass any known source workspace and source change ID to each item formula.
- Ensure each worker writes its implementation summary as a manifest-managed
  document.
- For parallel writers, use item-scoped document paths or item-scoped document
  workspaces, then let the coordinating formula integrate them into the root
  manifest.

The drain formula for this step must be `jj-do-work`.
