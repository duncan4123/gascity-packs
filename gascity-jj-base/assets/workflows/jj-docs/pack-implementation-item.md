# Apply Pack Implementation Work

Apply source changes in the packsmith sparse workspace selected by the routed
pack metadata.

Required behavior:

- Use `gc.pack`, `gc.pack_root`, and optional `gc.pack_workspace` from the
  claimed step bead. Do not infer the pack from the title or current directory.
- Work only in the sparse workspace prepared by packsmith pre-start.
- Preserve the existing document handoff: read workflow context from
  `{{manifest_path}}` and write durable implementation evidence as a
  manifest-managed implementation summary.
- Keep source and document identities separate. `gc.docs.source_change_id`
  names the source implementation change in the pack workspace; document
  change IDs name files under the `default@` document workspace.
- When applying review fixes, use the fix plan and prior review findings from
  the manifest/document paths, then make the follow-up pack edits in the same
  pack lane.
- Record the final pack workspace, source workspace path, and source change ID
  on the claimed step bead and workflow root bead before closing.

Exit criteria:

- pack source edits are complete in the selected pack workspace
- implementation summary metadata points at the durable document artifact
- source workspace and source change anchors are updated for downstream review
