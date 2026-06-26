# Pack Workflow Self Review

Use this step only when `packer_mode` is `self-review`, `handoff`, or
`self-review-handoff`. Complete the user-facing workflow first, then review or
route pack workflow findings according to the mode:

- `off`: no packer self-review or handoff behavior
- `self-review`: inspect the pack workflow and write findings only
- `handoff`: consume an existing findings artifact and create packsmith work
- `self-review-handoff`: write findings, then hand concrete findings to
  packsmith work

Evaluate friction in these areas:

- missing metadata or inconsistent pack metadata
- step handoff clarity
- `source_change_id` visibility
- workdir and workspace assumptions
- prompt gaps
- check gaps
- packer or JJ workflow routing surprises

For self-review modes, write a JSON artifact with schema
`gc.packer.pack-improvement-findings.v1`. If there is no concrete improvement,
write an artifact with an empty `findings` array, record `none` in the close
reason, and do not route follow-up work.

Use this top-level JSON shape:

```json
{
  "schema": "gc.packer.pack-improvement-findings.v1",
  "packer_mode": "self-review",
  "source": {
    "pack": "target-pack",
    "pack_root": "target-pack",
    "workspace": "optional-source-workspace",
    "change_id": "optional-source-change-id"
  },
  "findings": [
    {
      "schema": "gc.packer.pack-improvement-finding.v1",
      "id": "PKR-001",
      "severity": "P2",
      "title": "target-pack: fix concrete pack issue",
      "pack": "target-pack",
      "pack_root": "target-pack",
      "pack_workspace": "optional-child-workspace",
      "description": "Specific work for packsmith to perform.",
      "acceptance": "gc lint target-pack passes",
      "evidence": [
        {"path": "target-pack/file", "line": 12, "note": "Why this matters."}
      ]
    }
  ]
}
```

A finding is concrete only when the evidence points to a specific pack change
and the acceptance criteria can be tested. Use `pack_workspace` only when the
follow-up must run in a named child workspace; omit it for the reusable
pack-named integration workspace.

When `packer_mode=handoff` or `packer_mode=self-review-handoff`, consume the
findings artifact and create or sling one follow-up bead per actionable finding
to `gascity-packs/packer.packsmith` with this child-bead metadata:

```text
gc.pack=<finding.pack>
gc.pack_root=<finding.pack_root>
gc.formula=mol-packer-work
gc.route_target=packer.packsmith
gc.pack_workspace=<finding.pack_workspace>  # optional
```

Carry the finding id, findings path, finding schema, and packer mode into the
child bead metadata when available. Do not put `gc.pack`, `gc.pack_root`,
`gc.pack_workspace`, `gc.formula`, or `gc.route_target` on this ordinary
self-review or handoff step itself; those keys belong only on generated
packsmith child beads or already pack-routed source work. Preserve normal
workflow output and do not use this step to defer the user task itself.
