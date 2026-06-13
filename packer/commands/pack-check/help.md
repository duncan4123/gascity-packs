# gc packer pack-check

Run a compact pack validation pass.

```bash
gc packer pack-check <pack> [agent] [formula]
```

The command runs:

- `gc lint <pack>`
- `gc prime <agent> --strict` when `agent` is provided
- `gc formula show <formula>` when `formula` is provided
