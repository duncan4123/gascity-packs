# Drain JJ Work In One Shared Session

Drain implementation work in the current session while preserving document
handoff.

Required behavior:

- Pass `docs_workspace`, `docs_workspace_path`, `docs_artifact_root`, and
  `manifest_path` to the item formula.
- Pass any known `gc.docs.source_workspace`, `gc.docs.source_workspace_path`, and
  `gc.docs.source_change_id` to the item formula so the shared session continues
  from the same source anchor.
- Keep shared-session item work serial.
- Write each implementation summary as a manifest-managed document.
- Update `manifest.json` after each item so later items can consume current
  document state, including both source anchors and document change IDs.

The drain formula for this step must be `jj-do-work-item`.
