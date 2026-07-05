Build the plugin-backed DoltLite binary set for Gas City and Beads.

The default target is `all`.

Targets:

- `bd`: build a normal `bd` CLI from the Beads source tree.
- `gc`: build a normal `gc` CLI from the Gas City source tree.
- `bd-backend`: build `bd-backend-doltlite`.
- `gc-backend`: build `gc-doltlite-fastpath`.
- `gc-helper`: build the optional `gc-doltlite` helper.
- `backend`: build `bd-backend`, `gc-backend`, and `gc-helper`.
- `client`: build the DoltLite diagnostic client from this pack's
  `tools/doltlite-client` source by default.
- `all`: build `bd`, `gc`, `backend`, and `client`.

Common examples:

```bash
gc bd-gc-dl build all --install
gc bd-gc-dl build backend --install
gc bd-gc-dl build bd --bd-source /path/to/beads-plugin-architecture --install
gc bd-gc-dl build gc --gc-source /path/to/gascity --install
gc bd-gc-dl build client --install
```

The main `bd` and `gc` binaries are intentionally not linked directly to
`libdoltlite`; only backend plugin binaries are. This is the split-process
shape used by the local backend plugin trust config under
`.beads/config.local.yaml`.

Source discovery defaults:

- `bd`: `$CITY_ROOT/workspaces/beads-plugin-architecture` or explicit
  `--bd-source`.
- `gc`: `./gascity`, `$CITY_ROOT/gascity`, or adjacent checkout.
- backend plugin: `$CITY_ROOT/rigs/beads-backend-doltlite-plugin`, then
  workspace/cache adjacent checkouts.
- `client`: this `bd-gc-dl` pack's local source, unless `--client-source` or
  `BD_GC_DL_CLIENT_SOURCE` points at another checkout.

Backend plugin builds need `libdoltlite`. Pass `--lib DIR`, or set
`DOLTLITE_LIB`/`GC_DOLTLITE_LIB`. The command also checks common city paths.

Build cache defaults are city-local:

```text
GOCACHE=$CITY_ROOT/.cache/go/build
GOMODCACHE=$CITY_ROOT/.cache/go/mod
GOTMPDIR=$CITY_ROOT/.cache/go/tmp
TMPDIR=$CITY_ROOT/.cache/go/tmp
```

Set `BD_GC_DL_GO_CACHE_ROOT` to move all three together, or set the individual
Go variables when a build needs a specific cache. `TMPDIR` is also moved under
the city cache by default when it is unset or points at `/tmp`, so CGO does not
spill temporary files into the host temp filesystem.

Default outputs and build details go under the city root, not `/tmp`:

```text
$CITY_ROOT/.gc/runtime/packs/bd-gc-dl/bin/
$CITY_ROOT/.gc/runtime/packs/bd-gc-dl/last-build-*.json
```

With `--install`, `bd` installs to the active home `bd` path when found, or
`$HOME/.local/bin/bd`; `gc` installs to the active `gc` path when found, or
`$HOME/.local/bin/gc`; plugin and helper binaries install into this pack
runtime `bin`. The source pack should not contain built binaries. The existing
DoltLite metadata writers search the runtime `bin` path first, so new or
repaired scopes will point at these plugin binaries.
