---
name: pack-development
description: Create and modify Gas City packs, including pack manifests, agents, skills, formulas, commands, and assets.
---

# Pack Development

Use this skill when editing a Gas City pack.

## Workflow

1. Inspect the pack tree and `pack.toml`.
2. Identify the artifact type being changed: agent, skill, formula, command,
   doctor check, template fragment, asset, or registry metadata.
3. Follow the existing naming style in that pack.
4. Keep new artifacts small enough to test directly.
5. Add or update tests when behavior changes.

## Pack Manifest

`pack.toml` must use schema 2:

```toml
[pack]
name = "example"
version = "0.1.0"
schema = 2
description = "Short purpose."
```

Named sessions should be explicit:

```toml
[[named_session]]
template = "worker"
scope = "rig"
mode = "on_demand"
```

## Agent Prompts

After changing `agents/<name>/prompt.template.md`, render it:

```bash
gc prime <name> --strict
```

If the prompt uses shared fragments, verify every `{{ template "..." . }}`
reference resolves.

## Formulas

After changing `formulas/*.toml`, compile the formula:

```bash
gc formula show <formula-name>
```

Use `gc formula cook` only when creating beads is intentional.
