# Pack Workflow Self Review

Use this step only when `packer_mode=dev`. Complete the user-facing workflow
first, then review the pack workflow itself as the subject under trial.

Evaluate friction in these areas:

- missing metadata or inconsistent pack metadata
- step handoff clarity
- `source_change_id` visibility
- workdir and workspace assumptions
- prompt gaps
- check gaps
- packer or JJ workflow routing surprises

Record at most one concrete finding. If there is no concrete improvement,
record `none` in the close reason and do not route follow-up work.

Use this structured format for a concrete finding:

```text
PACK_IMPROVEMENT_FINDING v1
source_formula:
source_step_id:
trigger_bead:
observed_friction:
suggested_pack_change:
evidence:
acceptance_criteria:
```

A finding is concrete only when the evidence points to a specific pack change
and the acceptance criteria can be tested.

When `pack_improvement_routing_policy=route-concrete` and the finding is
concrete, create or sling a follow-up bead to
`gascity-packs/packer.packsmith` with this metadata:

```text
gc.pack={{self_pack}}
gc.pack_root={{self_pack_root}}
gc.pack_workspace={{self_pack_workspace}}
gc.formula=mol-packer-work
gc.route_target=gascity-packs/packer.packsmith
```

Carry the finding body into the follow-up bead description or notes. Preserve
normal workflow output and do not use this step to defer the user task itself.
