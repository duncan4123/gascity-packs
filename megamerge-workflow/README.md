# megamerge-workflow Pack

Workflow support for Gas City megamerge repairs.

This pack teaches agents how to use Jujutsu's simultaneous-edits pattern for
multi-line repair work:

- create a multi-parent integration merge
- include every stack head that must compile or behave together
- prove each intended stack head is actually in the merge ancestry
- create an empty scratch child above it
- make fixes in the scratch child
- route hunks back into their owning lines with `jj absorb`, `jj squash`, or
  `jj-hunk`
- keep the merge as the validation surface
- materialize the accepted head into the root/default workspace so the files
  appear in the normal checkout after validation

Membership checks are explicit. A stack drawn near the megamerge is not enough:

```bash
jj log --no-pager -r '<stack-head> & ::<megamerge>'
jj log --no-pager -r '<megamerge>-'
```

If the first command does not print the stack head, restage the megamerge with
that head included before repairing or validating.

After validation, the megamerger should move the default workspace onto the
accepted head with `jj edit <accepted-head>` from the root checkout, unless
the default workspace has unrelated active work. Do not copy files between
workspaces.

## Checks

```bash
gc formula show mol-megamerge-work
gc prime megamerge --strict
```
