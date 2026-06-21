# Prepare JJ Item Workspace

Prepare source and document context for one implementation item.

Required behavior:

- Resolve the workflow document manifest from `{{manifest_path}}`.
- Resolve the source workspace for this item.
- Record or confirm the source workspace name in `gc.docs.source_workspace`.
- Record any starting source change ID in `gc.docs.source_change_id`.
- Make the default@ artifact paths available to the implementation step.

The implementation summary must be written as a document in the jj document
workspace, not only as bead text.
