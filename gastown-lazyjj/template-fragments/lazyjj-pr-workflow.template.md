{{ define "lazyjj-pr-workflow" }}
## LazyJJ PR Workflow

LazyJJ keeps PR publication close to the jj stack:

- `jj spr init` once per repo
- `jj spr diff --cherry-pick` for independent PRs
- `jj spr diff --all` only when the next change depends on the previous one
- `jj spr list` before landing
- `jj spr land --cherry-pick -r <change-id>` for independent land

If you are using the workspace-handoff mode instead of direct GitHub land,
bookmark the stack head and push that bookmark:

```bash
jj bookmark set <bookmark> -r @-
jj git push --bookmark <bookmark>
```
{{ end }}
