# Record JJ Source Anchor

After implementation, record the source identity that downstream formulas should
review or publish.

Required behavior:

- Determine the latest source jj change ID for the implementation item.
  Use `jj -R "$SOURCE_WORKSPACE_PATH" log -r @ --no-graph` or the resolved
  implementation change in the source workspace. This is the source anchor for
  downstream review and publish steps.
- Record it on the item bead and workflow root bead as
  `gc.docs.source_change_id`.
- Record the source workspace as `gc.docs.source_workspace`.
- Record the source workspace path as `gc.docs.source_workspace_path`.
- Update `manifest.json` with the source workspace/change ID association.
- Confirm the implementation summary document exists and its manifest entry has
  a path, schema, hash, and document change ID.
- Do not overwrite `gc.docs.source_change_id` with the implementation summary's
  document change ID. The summary's `gc.docs.implementation_summary.change_id`
  and `gc.docs.change_id` record default@ document edits;
  `gc.docs.source_change_id` records source state.

This step closes the implementation item's source/document handoff.
