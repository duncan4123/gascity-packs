# Validate JJ Review Context

Validate that the review has stable source and document inputs.

Required behavior:

- Confirm `{{manifest_path}}` exists or can be derived from workflow root
  metadata.
- Confirm all manifest document paths needed for the review are readable.
- Confirm `{{source_change_id}}` or manifest `gc.docs.source_change_id` resolves
  in `gc.docs.source_workspace_path`, or `{{subject_path}}` identifies the
  artifact state to review.
- Treat opaque user-reported tokens such as `zrxomlvkwruu` as symptom context
  only. Do not accept them as source anchors until they are present in
  manifest/bead metadata and resolve as a jj revision in the source workspace.
- Confirm document `change_id` values belong to the default@ document workspace
  and do not replace a missing `gc.docs.source_change_id`.
- Report any missing path, hash, schema, or change ID as a blocking context
  issue.

Do not start a review from prompt-only context when the manifest or source
identity is missing.
