# Write JJ Gap-Analysis Report

Write a report-only gap analysis using the validated jj document and source
workspaces.

Required behavior:

- Read `{{context_path}}` when present. Treat it as the reference design,
  upstream implementation, or approved behavior to compare against.
- Inspect `{{subject_path}}` in `gc.docs.source_workspace_path` and, when a
  source change ID is available, pin observations to that jj change.
- Compare behavior at the query/API boundary, not just file names. For storage
  and controller work this means checking the exact CLI commands, direct SQL
  queries, metadata keys, formula variables, and artifact paths used by the
  implementation.
- For DoltLite or beads-doltlite work, run the exact `bd` and
  `gc beads-doltlite client query ...` probes that correspond to the code path
  under review. Record the city/workspace root used for each probe so path
  mismatches are visible.
- For upstream-vs-fork audits, identify which behavior is reference behavior,
  which behavior exists in the fork, which gaps are proven by tests or live
  probes, and which remaining gaps are only hypotheses.
- Write the full report to the path identified by
  `gc.docs.document_path_keys` or `gc.build.artifact_path_keys`.
- Update `manifest.json` with the gap-analysis path, schema, hash, and jj
  document change ID.
- Record `gc.docs.gap_analysis.path`, `gc.docs.gap_analysis.schema`,
  `gc.docs.gap_analysis.hash`, `gc.docs.gap_analysis.change_id`, and the latest
  `gc.docs.change_id` on the workflow root bead.

The bead comment may summarize the result, but the durable audit belongs in the
tracked report document.
