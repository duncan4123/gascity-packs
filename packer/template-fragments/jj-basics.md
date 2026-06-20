# JJ Basics for Pack Work

This fragment gives packsmith agents the minimal Jujutsu commands they need to
land in a workspace, claim a bead, keep their work visible and isolated, and
finish cleanly.

## Workspace references and bookmarks

In this repo:

- `default@` is the working copy of the rig-root **default workspace**. New pack
  workspaces are created from this commit by `jjw`.
- `main` is the **integration bookmark** for `gascity-packs`. Landed pack work
  ends up on `main@`.
- `gc/<pack>` bookmarks track the live `@` of each pack workspace.

Do not confuse `default@` (a workspace reference) with a `default` bookmark. If a
`default` bookmark exists, it is not the same thing.

## Land in a session and claim a bead

When a packsmith session starts, it is already pointed at the right sparse jj
workspace by the packer pre-start script. Your first action is to claim routed
work and record a clear workspace commit for it.

```bash
# Claim the routed bead assigned to this session
gc hook --claim --json

# Record the workspace position tied to this claim
jj describe -m "<pack>: <short task summary>"
```

Describing the change at the start creates a visible commit linked to the
session, prevents accidental mixing with the previous agent's work, and gives
other workspaces (and the dashboard) a readable signal of who is doing what.

If the claim returns `NO_ROUTED_WORK` or `CONFIG_REJECTED`, drain and exit
instead of inventing work.

## Bookmark hygiene

Pack workspaces use bookmarks in the `gc/<pack>` or `gc/<pack>.<workspace>`
namespace. The `main` bookmark is the integration target; only the landing
formula (`mol-packer-complete`) advances it.

- Do not move `main` unless you are running the landing steps.
- Do not create ad-hoc bookmarks; use `jj describe` and `jj new` to manage your
  local line instead.
- Do not run `jj op restore`; the operation log is shared across workspaces and
  you can rewind another session's state.

## Revset and stack management

Useful revsets for day-to-day pack work:

| Goal | Revset |
| --- | --- |
| Commits from main@ to your working copy | `main@..@` |
| Commits in this workspace line | `@ \| @- \| main@` |
| Changes in your working copy | `jj diff --git` |
| Files changed on your branch | `jj diff --from main@ --to @ --stat` |
| Check for conflicts | `jj log -r 'conflicts()'` |
| Check for divergent bookmarks | `jj log -r 'divergent()'` |
| Where new workspaces start from | `default@` |

If main@ has moved forward, rebase your work before landing:

```bash
jj rebase -s <first-local-change> -d main@
```

## Work finished formula

When the bead task is complete, run `mol-packer-complete` from inside the pack
workspace. It guides you through reviewing, cleaning, rebasing onto `main@`,
advancing the `main` bookmark, and verifying the landed state.

Summary of the landing sequence:

```bash
# Review
jj status
jj log -r 'main@..@' --no-graph
jj diff --git
jj diff --from main@ --to @ --stat

# Clean (as needed)
jj squash
jj split
jj describe -m "<pack>: <clear summary>"
jj abandon <empty-change-id>

# Rebase and land
jj rebase -s <first-local-change> -d main@
jj bookmark move main --to <tip-change-id>

# Verify
gc lint <pack>
python3 -m pytest <relevant-tests> -q

# Leave a clean working copy
jj new main@
```

After landing, the workspace is empty on top of `main@`, ready for the next
bead.
