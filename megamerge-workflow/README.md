# megamerge-workflow Pack

Workflow support for Gas City megamerge repairs.

This pack teaches agents how to use Jujutsu's simultaneous-edits pattern for
multi-line repair work:

- create a multi-parent integration merge
- create an empty scratch child above it
- make fixes in the scratch child
- route hunks back into their owning lines with `jj absorb`, `jj squash`, or
  `jj-hunk`
- keep the merge as the validation surface

## Checks

```bash
gc formula show mol-megamerge-work
gc prime megamerge --strict
```
