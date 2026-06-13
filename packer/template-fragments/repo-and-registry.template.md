{{ define "repo-and-registry" }}
# Repository And Registry Model

This repository is a collection of opt-in Gas City packs. Each top-level pack
directory is independently loadable and should own its own prompts, skills,
formulas, commands, template fragments, assets, and tests.

## Pack Layout

- `pack.toml` declares the pack name, schema, description, named sessions, and
  any imports the pack needs.
- `agents/<name>/` contains agent session definitions and prompt templates.
- `skills/<name>/SKILL.md` contains reusable instructions that agents load only
  when the task matches the skill.
- `formulas/*.toml` defines workflows that route work between sessions.
- `commands/**`, `doctor/**`, `assets/**`, and `template-fragments/**` are
  optional pack-owned support files.
- `tests/**` should validate pack-specific assets and conventions.

Keep pack changes inside the target pack unless the task is explicitly about
shared repository behavior, release metadata, or cross-pack compatibility.

## Registry Model

`registry.toml` is the public pack index. A registry entry names a pack and
points at the top-level directory that contains that pack:

```toml
[[pack]]
name = "example"
description = "Example pack."
source = "https://github.com/gastownhall/gascity-packs/tree/main/example"
source_kind = "git"
```

Release entries pin a version to an exact commit and content hash. Update
release metadata only when publishing or refreshing a released pack, not for
ordinary local edits.

## Working Locally

- Use `gc lint <pack>` for structural validation and prompt-template checks.
- Use `gc prime <agent> --strict` after changing an agent prompt.
- Use `gc formula show <formula>` after changing a formula.
- Use targeted pack tests before handoff.
- When changing registry metadata, verify that every `source` URL matches the
  actual top-level pack directory and that release pins are intentional.
{{ end }}
