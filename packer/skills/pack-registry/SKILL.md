---
name: pack-registry
description: Add or validate registry entries for Gas City packs using current registry.toml conventions.
---

# Pack Registry

Use this skill when working on `registry.toml`.

## Registry Shape

Registry entries use dereferenceable GitHub tree URLs:

```toml
[[pack]]
name = "example"
description = "Example pack."
source = "https://github.com/gastownhall/gascity-packs/tree/main/example"
source_kind = "git"

  [[pack.release]]
  version = "0.1.0"
  ref = "main"
  commit = "<full lowercase commit sha>"
  hash = "sha256:<64 lowercase hex>"
  description = "Release description."
```

## Validation

Run:

```bash
python3 validate_registry.py
python3 -m pytest tests/test_validate_registry.py -q
```

Use the pack content hash expected by `validate_registry.py`; it hashes the
pack subdirectory contents, not root module files.
