Build DoltLite-linked binaries from the Gas City and beads-doltlite source trees.

The default target is `gc`.

Use `gc beads-doltlite build gc --install --no-restart` for normal Gas City iteration, native read fastpath fixes, or build-tag changes.

Use `gc beads-doltlite build bd --install --no-restart` only after the
beads-doltlite source or bd link inputs change.

Use `gc beads-doltlite build client --no-restart` only when refreshing the
DoltLite diagnostic client.

Use `gc beads-doltlite build all --install --no-restart` for bootstrap or a coordinated rebuild.

`all` builds `bd`, `doltlite-client`, then `gc`; it does not skip unchanged targets. If Gas City source, a DoltLite-capable `bd` checkout, or `libdoltlite` is not present, the command fetches/builds managed copies under `.gc/runtime/packs/beads-doltlite/src/`.

Pass `--gc-source DIR`, `--bd-source DIR`, or `--lib DIR` to use local development checkouts.
Use `--gascity-source-url`/`--gascity-source-ref`,
`--bd-source-url`/`--bd-source-ref`, and
`--doltlite-source-url`/`--doltlite-source-ref` to override the managed
bootstrap sources.

With `--install`, the `gc` target updates every distinct home-owned entrypoint
the city may use: the running supervisor binary, the configured supervisor unit
binary, and the active controller `gc` path. Symlinks are resolved before
writing so aliases such as `$HOME/go/bin/gc` keep pointing at the same real
installed binary.

Examples:

```bash
gc beads-doltlite build gc --install --no-restart
gc beads-doltlite build all --install --no-restart
```
