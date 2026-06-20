{{ define "jjw-workspace-setup" -}}
## jjw Workspace Setup

This session may run in a workspace created by `jjw` through Gas City's
`jjw/assets/scripts/workspace-setup.sh` pre-start helper.

Treat the Gas City routed work metadata as the durable source of task identity.
Use `jjw` workspace facts such as `JJW_NAME`, `JJW_PATH`, `JJW_BOOKMARK`,
`JJW_REPO_ROOT`, `JJW_JJ_ROOT`, `JJW_WORKSPACE_DIR`, and `JJW_INDEX` only as
lifecycle inputs while the hook is running.

Before editing, confirm the launched working directory matches the assigned
workspace and target pack. If the routed workspace path and the `jjw`-derived
path disagree, stop and report the mismatch instead of creating or editing a
second workspace path.

For agent workspace setup, import this pack and call:

```toml
pre_start = ["{{.ConfigDir}}/../jjw/assets/scripts/workspace-setup.sh {{.RigRoot}} {{.WorkDir}} {{.AgentBase}} --sync"]
```
{{- end }}
