# Drain Pack Work Through Packsmith

Drain source implementation work into pack-routed packsmith beads while
preserving the jj document handoff.

Required behavior:

- Treat the parent formula request as the source of truth for pack routing.
- Pass `pack`, `pack_root`, optional `pack_workspace`, `pack_route_target`, and
  `pack_route_formula` through step metadata instead of inferring pack identity
  from bead titles, workspace paths, or generated session names.
- Each routed child bead must carry `gc.pack`, `gc.pack_root`,
  `gc.route_target`, and `gc.formula`. Carry `gc.pack_workspace` only as the
  optional stable workspace key under the pack workspace.
- Keep `docs_workspace`, `docs_workspace_path`, `manifest_path`,
  `source_workspace`, `source_workspace_path`, and `source_change_id` as
  document/source anchors for summary and review steps.
- Packsmith pre-start owns the sparse source workspace. It uses the pack
  metadata to check out `.gc/workspaces/<rig>/packs/<pack>` or the named child
  workspace below it, then claims and executes the routed work.
- Source edits happen in the packsmith sparse workspace. Workflow summaries,
  reviews, final reports, and other durable evidence remain manifest-managed
  documents under the `default@` document workspace.
- After pack edits land, downstream summary and review steps consume
  `gc.docs.source_workspace`, `gc.docs.source_workspace_path`, and
  `gc.docs.source_change_id` rather than reconstructing source state.

The drain formula for this step is the configured pack route formula, normally
`mol-packer-work`.
