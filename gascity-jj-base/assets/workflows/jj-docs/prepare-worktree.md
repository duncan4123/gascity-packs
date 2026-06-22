# Prepare JJ Source Workspace

Prepare the source workspace and document context for one implementation item.
This formula step owns workspace creation and switching; do not rely on agent
pre-start hooks to choose the source checkout.

Required behavior:

- Resolve the workflow document manifest from `{{manifest_path}}`.
- Keep workflow documents in `default@`; use the source workspace only for source
  edits, source `jj describe`, source verification, and source change IDs.
- Resolve the target pack from `gc.pack`, `gc.pack_root`, manifest source data, or
  the requested pack path. The reusable integration workspace is:
  `.gc/workspaces/<rig>/packs/<pack>`.
- If `gc.pack_workspace` is present, create or reuse the child workspace:
  `.gc/workspaces/<rig>/packs/<pack>/<workspace>`. Child workspaces start from
  `gc/<pack>` when that bookmark exists and later land back into the pack-named
  integration workspace, not directly to `default@`.
- Create or refresh the workspace from this formula step with the imported `jjw`
  helper, for example:

  ```bash
  jjw/assets/scripts/workspace-setup.sh \
    <rig-root> \
    .gc/workspaces/<rig>/packs/<pack> \
    <pack>
  ```

  For a child workspace, set `GC_JJW_WORKSPACE_DIR` to the pack workspace
  directory, set `GC_JJW_BOOKMARK_PATTERN='gc/<pack>.{name}'`, set
  `GC_JJW_BASE_REVSET=gc/<pack>` when that bookmark resolves, and pass the child
  workspace path/name to the same helper.
- Sparse-checkout the target pack plus shared pack infrastructure needed for
  validation. Widen the sparse checkout only for real shared surfaces required by
  the item; do not convert the workspace into a full checkout for convenience.
- Switch source commands to the resolved workspace path with `jj -R` or by
  changing directory there before source reads, edits, tests, or `jj describe`.
- Record or confirm the source workspace name in `gc.docs.source_workspace`.
- Record or confirm the source workspace path in `gc.docs.source_workspace_path`.
- Record any starting source change ID in `gc.docs.source_change_id`.
- Make the default@ artifact paths available to the implementation step.

The implementation summary must be written as a document in the jj document
workspace, not only as bead text.
