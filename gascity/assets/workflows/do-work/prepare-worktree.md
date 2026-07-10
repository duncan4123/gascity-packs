
Resolve and publish the isolated JJ workspace for this item. This is infrastructure
setup only. Do not edit source files in the launcher checkout.

1. Read current step bead metadata and get `gc.root_bead_id`; hard-fail if it is
   missing. Read that do-work root with `bd show <root-bead-id> --json`.
2. Resolve `<source-anchor-id>` from the do-work root:
   - read root metadata `gc.input_convoy_id`; hard-fail if it is missing
   - verify `gc.input_convoy_id` matches rendered runtime convoy `{{convoy_id}}`
   - read that input convoy with `bd show <input-convoy-id> --json`
   - if input convoy metadata has `gc.synthetic_kind=drain-unit-convoy`, use
     input convoy metadata `gc.drain_member_id`
   - do not use the synthetic drain-unit convoy id as `<source-anchor-id>`;
     hard-fail if the selected source anchor id equals the synthetic input convoy id
   - otherwise use `<input-convoy-id>` as the source anchor
   - if root metadata also has `gc.drain_member_id`, it must match the selected
     drain member
3. Validate context path {{context_path}}, files ownership, and verification
   policy for the resolved source anchor. Resolve the launcher workspace root
   before changing directory: prefer do-work root metadata `gc.work_dir` when
   it names an absolute existing JJ workspace; otherwise run `jj workspace root`
   from the worker startup directory. Require an absolute existing path and
   verify it with `jj -R "$LAUNCHER_ROOT" workspace root`. This fallback is
   required because nested workflow roots do not always carry `gc.work_dir`.
4. Read the rig name from root metadata `gc.var.rig_name`; hard-fail if it is
   missing. Set the deterministic workspace name to
   `<rig-name>-<source-anchor-id>` and its path to
   `<launcher-root>/.gc/workspaces/<rig-name>/items/<source-anchor-id>`.
5. Create or reuse that JJ workspace:
   - If the path is missing, create its parent directory and run
     `jj -R "$LAUNCHER_ROOT" workspace add "$WORKSPACE" --name "$WORKSPACE_NAME" -r @- -m "work(<source-anchor-id>): implementation workspace"`.
   - If the path exists, verify `jj -R "$WORKSPACE" workspace root` resolves
     exactly to its absolute path and run
     `jj -R "$WORKSPACE" workspace update-stale` when required.
   - Hard-fail if the path is not a JJ workspace, belongs to another repository,
     or resolves to the launcher checkout. Do not use `git worktree add`.
6. Record the workspace change ID with
   `jj -R "$WORKSPACE" log -r @ --no-graph -T 'change_id ++ "\n"'`.
   Persist the absolute path and JJ identity on the source anchor with one
   `bd update <source-anchor-id>` call using these metadata values:
   - `work_dir=<absolute workspace path>` (compatibility path for generic build checks)
   - `gc.docs.source_workspace=<workspace name>`
   - `gc.docs.source_workspace_path=<absolute workspace path>`
   - `gc.docs.source_change_id=<change id>`
   For synthetic drain-unit convoys, never persist `work_dir` on the synthetic drain-unit convoy; the original drain member/source anchor is authoritative.
   Verify the source anchor now has all four values and that the recorded path
   still resolves as the named JJ workspace before closing this step with
   `gc.outcome=pass`.
