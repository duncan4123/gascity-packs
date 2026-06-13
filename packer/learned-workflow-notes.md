# Learned Workflow Notes

## Import Before Formula Discovery

When adding a new local pack for a rig, creating the pack directory is not
enough for live formula discovery.

General workflow:

1. Put the pack somewhere the city can resolve, for example:
   - a checked-in pack directory
   - a symlink under the city's local `packs/` directory
   - a dereferenceable GitHub tree URL
2. Add the pack to the target rig's import map in `city.toml`.
3. Run `gc reload`.
4. Verify discovery:

```bash
gc import list
gc formula list
gc formula show <formula-name>
```

If `gc lint <pack>` passes but `gc formula show <formula-name>` says the
formula is not found, the pack is valid but not imported into the active rig.

Example rig import:

```toml
[[rigs]]
name = "<rig-name>"

[rigs.imports]
[rigs.imports.<binding-name>]
source = "<pack-source>"
```

Example local development source:

```toml
[rigs.imports.packer]
source = "./packs/packer"
```

Use examples only as examples. Pack guidance should stay portable across city
roots, rig names, and pack locations.
