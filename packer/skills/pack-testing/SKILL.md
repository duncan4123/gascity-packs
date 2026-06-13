---
name: pack-testing
description: Validate a Gas City pack with lint, prompt rendering, formula compilation, and targeted tests in a live city.
---

# Pack Testing

Use this skill to verify pack changes.

## Minimum Checks

```bash
gc lint <pack>
```

For agent prompt changes:

```bash
gc prime <agent> --strict
```

For formula changes:

```bash
gc formula show <formula-name>
```

For script or parser changes, run the narrowest test:

```bash
python3 -m pytest <pack>/tests -q
```

## Live City Checks

Use these when the pack must be loaded by the current city:

```bash
gc import list
gc import check
gc reload
gc formula list
```

If a newly added formula is not listed, the pack is valid but not imported into
the active city.

## Destructive Boundary

`gc formula cook` creates beads. Use it only when the test intentionally needs
real workflow beads. Prefer `gc formula show` for compile-only checks.
