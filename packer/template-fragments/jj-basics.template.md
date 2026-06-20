{{ define "jj-basics" }}
# JJ Basics for Pack Work

This fragment gives packsmith agents the minimal Jujutsu commands they need to
land in a workspace, claim a bead, keep their work visible and isolated, and
finish cleanly.

## Workspace references and bookmarks

In this repo:

- `default@` is the working copy of the rig-root **default workspace**. New pack
  workspaces are created from this commit by `jjw`. Pack work is integrated onto
  `default@` so it can be tested in a running Gas City.
- `main` is the **published integration bookmark** for `gascity-packs`. Landed
  pack work is released to `main` only after testing on `default@`.
- `main@origin` is the live published `main` on the `origin` remote.
- `gc/<pack>` bookmarks track the live `@` of each pack workspace.

Do not confuse `default@` (a workspace reference) with a `default` bookmark. If a
`default` bookmark exists, it is unrelated to `default@` and should be ignored.

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
namespace. The integration target for pack work is `default@`; only
`mol-packer-complete` moves `default@`. The `main` bookmark is released by the
packrouter release workflow after testing.

- Do not move `default@` unless you are running `mol-packer-complete`.
- Do not move `main` from a pack workspace.
- Do not create ad-hoc bookmarks; use `jj describe` and `jj new` to manage your
  local line instead.
- Do not run `jj op restore`; the operation log is shared across workspaces and
  you can rewind another session's state.

## Revset and stack management

Useful revsets for day-to-day pack work:

| Goal | Revset |
| --- | --- |
| Commits from default@ to your working copy | `default@..@` |
| Commits in this workspace line | `@ \| @- \| default@` |
| Changes in your working copy | `jj diff --git` |
| Files changed on your branch | `jj diff --from default@ --to @ --stat` |
| Check for conflicts | `jj log -r 'conflicts()'` |
| Check for divergent bookmarks | `jj log -r 'divergent()'` |
| Where new workspaces start from | `default@` |
| Live published state | `main@origin` |

Rebase onto `default@` only when the bead or formula says so, when `default@`
has moved forward, or when you are about to run `mol-packer-complete`. Do not
rebase after every trivial change by default.

## Work finished formula

When the bead task is complete, run `mol-packer-complete` from inside the pack
workspace. It guides you through reviewing, cleaning, rebasing onto `default@`
when needed, moving `default@` to the integrated tip, verifying, and leaving a
clean working copy.

Summary of the landing sequence:

```bash
# Review
jj status
jj log -r 'default@..@' --no-graph
jj diff --git
jj diff --from default@ --to @ --stat

# Clean (as needed)
jj squash
jj split
jj describe -m "<pack>: <clear summary>"
jj abandon <empty-change-id>

# Rebase onto default@ only if needed
jj rebase -s <first-local-change> -d default@

# Move default@ to the integrated tip (from inside the pack workspace)
jj -R <rig-root> edit <tip-change-id>

# Verify
gc lint <pack>
python3 -m pytest <relevant-tests> -q

# Leave a clean working copy
jj new default@
```

After landing, the pack workspace is empty on top of `default@`, ready for the
next bead. The integrated state on `default@` is now ready for testing in a
running Gas City. Release to `main` is handled separately by the packrouter
release workflow.
{{ end }}
