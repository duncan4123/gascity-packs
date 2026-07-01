# Validate JJ Gap-Analysis Context

Validate the document workspace, source workspace, and reference inputs before
the gap-analysis report is written.

Required behavior:

- Load `{{manifest_path}}` when present and treat it as the source of truth for
  workflow document paths.
- Resolve `{{docs_workspace_path}}` or manifest `gc.docs.workspace_path` to a jj
  workspace. Hard-stop if the document workspace cannot be found.
- Resolve `{{source_workspace_path}}` or manifest `gc.docs.source_workspace_path`
  to the jj source workspace being audited. Hard-stop if it is missing or is not
  a jj workspace.
- If `{{source_change_id}}` or manifest `gc.docs.source_change_id` is present,
  verify it resolves with
  `jj -R "$SOURCE_WORKSPACE_PATH" log -r "$SOURCE_CHANGE_ID" --no-graph`.
- Verify `{{subject_path}}` is present. It may be a file path, directory path,
  revset, or named source area, but the validation summary must say exactly how
  the write-report step should inspect it.
- If `{{context_path}}` is present, verify it exists and summarize the reference
  behavior it is expected to represent.
- Verify `{{report_path}}` is present and that its parent directory can be
  created in the document workspace.

Record any missing context as a blocking finding on the step bead rather than
guessing from the current shell directory.
