{{ define "bd-gc-dl-handoff" }}
## BD/DB DoltLite Issues

If you encounter a `bd`, `.beads` database, backend plugin, or DoltLite storage
failure while working other tasks, do not perform broad repair or rebuilds as a
side quest. Capture the failing command, scope, and first useful stderr in an
evidence file under `.gc/diagnostics/bd-gc-dl/`, then run the pack handoff
command. The command creates a focused repair task and slings it to the
`bd-gc-dl-fixer` agent.

Treat an issue as probably related to this pack when the symptom involves:

- `bd`, `gc bd`, `gc hook --claim`, `gc sling`, or formula workers failing
  while reading, creating, claiming, updating, closing, or routing beads;
- errors mentioning `.beads`, `metadata.json`, `doltlite`, `libdoltlite`,
  `backend_plugin`, `bd-backend-doltlite`, `gc-doltlite-fastpath`,
  `gc-doltlite`, plugin process startup, JSON protocol, traces, locks, schema
  migrations, dependency rows, or missing columns;
- empty or missing `.gc/backend-plugin-trace.jsonl` or
  `.gc/gascity-backend-plugin-trace.jsonl` when a DoltLite city should be using
  backend plugins;
- fresh `gc init` or existing-city migration behavior that leaves a DoltLite
  city unable to run normal `bd`/`gc bd` commands;
- wrapper scripts or runtime paths looking under old pack locations instead of
  `.gc/runtime/packs/bd-gc-dl/bin`;
- build or release failures for `bd`, `gc`, `bd-backend-doltlite`,
  `gc-doltlite-fastpath`, `gc-doltlite`, or `doltlite-client`.

Do not classify ordinary application test failures, prompt wording problems, or
unrelated Git/JJ conflicts as `bd-gc-dl` issues unless one of the symptoms above
is present.

Use this instead of hand-writing `gc bd create`/`gc sling`:

```bash
gc bd-gc-dl file-fix-task \
  --summary "<short symptom>" \
  --command "<failing command>" \
  --scope "<city, rig, repo, or bead scope>" \
  --evidence ".gc/diagnostics/bd-gc-dl/<evidence>.md" \
  --from-bead "${GC_BEAD_ID:-}"
```

The specialist owns failures across Beads core, Gas City, the DoltLite backend
plugin repo, and the Gas City packs that wire them together. Keep your original
task moving unless the failure prevents all progress.
{{ end }}
