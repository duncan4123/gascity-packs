# Implement JJ Work Item

Implement the assigned work item and write a manifest-managed implementation
summary.

Required behavior:

- Use the source workspace for source edits.
- Confirm the preceding describe step has described the source jj change that
  will receive these edits. Do not edit source files from an undescribed `@`.
- Use `{{manifest_path}}` to read requirements, plan, decomposition, and any
  prior review/fix documents.
- Write or update the implementation summary at the path selected by
  `gc.docs.document_path_keys`.
- Include both source and document identities in the summary:
  source workspace, source change ID, default@ artifact root, document path,
  hash, and document change ID.
- Update `manifest.json` and bead metadata with the implementation summary path,
  schema, hash, and jj document change ID.
- Record the latest source change ID on `gc.docs.source_change_id`.

Do not rely on prompt context as the durable implementation record.
