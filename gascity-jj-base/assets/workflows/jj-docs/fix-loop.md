# Plan JJ Review Fixes

Turn review findings into a concrete fix plan using stable source and document
identities.

Required behavior:

- Read review findings from `{{manifest_path}}` or `{{findings_path}}`.
- Confirm the preceding describe step has described the jj change that will
  receive the fix plan or source fix edits.
- Reference the `gc.docs.source_workspace_path` and
  `gc.docs.source_change_id` that need fixes.
- Verify the source change ID resolves in the recorded source workspace before
  planning source fixes. Treat document change IDs as review or fix-plan
  artifact anchors, not source revisions.
- Produce fix instructions that preserve the manifest handoff for
  implementation and re-review.
- Record any new fix-plan document path, hash, schema, and document change ID in
  the manifest when a file is produced.

Downstream fix application should update source change IDs and manifest entries
before re-review.
