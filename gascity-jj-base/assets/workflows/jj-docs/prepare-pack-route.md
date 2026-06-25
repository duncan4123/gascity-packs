# Prepare Pack Route Metadata

Validate the pack-aware fix-loop routing context before any follow-up pack
source edit is dispatched.

Required behavior:

- Resolve the workflow document manifest from `{{manifest_path}}`.
- Verify that `gc.pack` or `gc.var.pack` names the target pack.
- Verify that `gc.pack_root` or `gc.var.pack_root` names the pack directory
  relative to the rig root.
- Treat `gc.pack_workspace` or `gc.var.pack_workspace` as an optional workspace
  key, not a path. It must not contain slashes.
- Preserve any known `gc.docs.source_workspace`,
  `gc.docs.source_workspace_path`, and `gc.docs.source_change_id` metadata.
  These are source anchors for summary, review, and follow-up fix context.
- Do not create a source workspace in this step. Packsmith pre-start creates or
  reuses the sparse pack workspace from the pack metadata.
- Do not derive pack identity from the title, formula name, step ID, attempt
  number, or generated session name.

Exit criteria:

- pack metadata is explicit
- document manifest metadata is still present
- source anchor metadata is preserved for the routed packsmith step
