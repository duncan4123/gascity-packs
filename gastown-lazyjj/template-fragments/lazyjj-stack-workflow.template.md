{{ define "lazyjj-stack-workflow" }}
## LazyJJ Stack Workflow

Use these commands as the default stack routine:

```bash
jj git fetch
jj log -r 'trunk()..@'
jj log -r 'stack & no_description'
jj absorb
jj diff --from branch_off
```

For a new stack head:

```bash
jj new trunk() -m "work: <short summary>"
```

For focused checkpoints inside the stack:

```bash
jj new -m "next"
jj describe -r @- -m "short description"
```
{{ end }}
