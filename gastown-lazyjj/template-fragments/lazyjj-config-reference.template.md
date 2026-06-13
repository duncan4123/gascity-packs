{{ define "lazyjj-config-reference" }}
## LazyJJ Config Reference

Source: `/home/ubuntu/.config/jj/lazyjj/website/src/content/docs/reference`

Use this reference when an agent needs the LazyJJ-specific jj command surface
and revset aliases.

### Value-Add Aliases

```bash
jj diff-files
jj diff-summary
jj log-short
```

Shortcut aliases:

```bash
jj diffs
jj diffls
jj gf
```

### Stack Commands

```bash
jj stack-view
jj stack-files
jj stacks-all
jj stack-top
jj edit <change-id>
jj stack-sync
jj stack-start
jj restack
jj stack-submit
jj tug
jj create <bookmark>
jj stack-gc
```

### Revset Aliases

```bash
jj log -r stack
jj log -r stacks
jj log -r no_description
jj log -r branch_off
jj log -r ghbranch
```

Useful combinations:

```bash
jj log -r "stack & empty()"
jj log -r "stack & bookmarks()"
jj log -r "stacks ~ stack"
jj log -r "stack & conflict()"
jj log -r "file(package.json)"
jj log -r "stack & file(glob:**/*test*.js)"
```

### Customization Files

```toml
# ~/.config/jj/conf.d/zzz-my-aliases.toml
[aliases]
log-short = ["log", "--limit", "20"]

# ~/.config/jj/conf.d/zzz-my-revsets.toml
[revset-aliases]
"ready" = "mine() & bookmarks() & ~empty()"
```
{{ end }}
