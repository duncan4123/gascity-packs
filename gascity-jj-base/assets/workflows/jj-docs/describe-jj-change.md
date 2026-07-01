# Describe JJ Change Intent

Describe the jj change that will receive the next document or source edits
before making those edits.

Required behavior:

- Work in the jj workspace selected by step metadata: the default@ document
  workspace for document edits, or `gc.docs.source_workspace_path` for
  implementation/source edits.
- For source-scoped describe steps, hard-stop if
  `gc.docs.source_workspace_path` is missing or does not resolve to a jj
  workspace. Use `jj -R "$SOURCE_WORKSPACE_PATH" ...` or `cd` there before any
  source `jj status`, `jj log`, `jj describe`, or `jj new` command.
- When a source-scoped step receives `gc.docs.source_change_id` or
  `gc.var.source_change_id`, verify that change in the resolved source
  workspace and start from it before edits. Do not use a document
  `gc.docs.change_id` or `gc.docs.<name>.change_id` as the source revision.
- Inspect the current change before editing:

  ```bash
  jj status
  jj log -r @ --no-graph
  ```

- If `@` is empty or already represents this work, describe it with the intended
  outcome before changing files:

  ```bash
  jj describe -m "<scope>: <intended change>"
  ```

- If `@` contains unrelated work, create a fresh described change for this work
  before changing files:

  ```bash
  jj new -m "<scope>: <intended change>"
  ```

- Never start the document or source edits from a `(no description set)` change.
- Record the described change ID in the appropriate document or source metadata
  after the downstream edit step updates the files.
- For document-scoped edits, the downstream document step records
  `gc.docs.<name>.change_id` or `gc.docs.change_id`; for source-scoped edits, it
  records `gc.docs.source_change_id`.

Exit criteria:

- `jj log -r @ --no-graph` shows a non-placeholder description for the intended
  edit.
- `jj status` does not show unrelated changes mixed into the described work.
- No target document or source edits were made before the change was described.
