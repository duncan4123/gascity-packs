# Summarize JJ Implementation

Write the canonical implementation summary for the workflow root.

Required behavior:

- Read item summaries and source identities from `{{manifest_path}}`.
- Confirm the preceding describe step has described the jj change that will
  receive the aggregate implementation summary.
- Include the source workspace and latest source change ID that downstream
  review should inspect.
- If the manifest has multiple item source IDs, choose and report the latest
  integrated source change ID, and make unresolved or missing source IDs
  explicit instead of falling back to a document change ID.
- Write the summary as a document under the default@ artifact root.
- Update `manifest.json` with the summary path, schema, hash, and document
  change ID.
- Keep `gc.docs.implementation-summary.change_id` and `gc.docs.change_id` as
  document-workspace anchors. They do not identify source state.
- Record `gc.docs.implementation-summary.path`,
  `gc.docs.implementation-summary.schema`,
  `gc.docs.implementation-summary.hash`,
  `gc.docs.implementation-summary.change_id`,
  `gc.docs.source_workspace`, `gc.docs.source_change_id`, and
  `gc.docs.change_id` on the workflow root bead.
