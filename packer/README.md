# Packer

Packer is a Gas City pack-development toolkit. It gives agents the prompts,
skills, formulas, and command helpers needed to build packs while testing them
inside a real city and rig.

Use it when the work is about pack authoring rather than product code:

- creating or editing `pack.toml`
- adding agent prompts, skills, formulas, commands, doctor checks, or assets
- validating pack imports and template rendering
- running `gc lint <pack>` and targeted pack tests
- exercising formulas with `gc formula show` or controlled `gc formula cook`
- checking registry entries and release metadata

Operational notes discovered while building packs live are kept in
[`learned-workflow-notes.md`](./learned-workflow-notes.md).

Import it with a local binding, adjusting the source for the target city:

```toml
[imports.packer]
source = "../gascity-packs/packer"
```

Start a packer session when a rig needs pack development help:

```bash
gc session new packer --rig <rig>
```

For repeatable checks, use the formula:

```bash
gc sling <target> mol-packer-validate --formula \
  --var pack_path=/absolute/path/to/pack \
  --var pack_name=packer
```

For live-city import work, use `mol-packer-import-local-pack` with the target
rig, binding name, and pack source instead of hard-coding one machine's paths.
