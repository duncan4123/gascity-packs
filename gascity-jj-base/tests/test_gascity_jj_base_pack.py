from __future__ import annotations

import pathlib
import re
import stat
import tomllib


PACK = pathlib.Path(__file__).resolve().parents[1]
ROOT = PACK.parent
EXPECTED_FORMULAS = {
    "jj-build",
    "jj-planning-base",
    "jj-decomposition-base",
    "jj-implement",
    "jj-do-work",
    "jj-do-work-item",
    "jj-review",
    "jj-fix-loop",
    "jj-publish",
    "jj-pack-build",
    "jj-pack-implement",
    "jj-pack-fix-loop",
    "root-task-stage-report",
}
PACK_AWARE_FORMULAS = {
    "jj-pack-build",
    "jj-pack-implement",
    "jj-pack-fix-loop",
}
FORMULAS_WITH_INHERITED_DESCRIBE_STEPS = {
    "jj-pack-build",
    "jj-pack-implement",
}
EXPECTED_TMUX_SESSION_LIVE = [
    "{{.ConfigDir}}/../gastown/assets/scripts/tmux-theme.sh "
    "{{.Session}} {{.Agent}} {{.ConfigDir}}/../gastown",
    "{{.ConfigDir}}/../gastown/assets/scripts/tmux-keybindings.sh "
    "{{.ConfigDir}}/../gastown",
]
BASE_TMUX_HELPERS = {
    "agent-menu.sh",
    "bind-key.sh",
    "cycle.sh",
    "status-line.sh",
    "tmux-keybindings.sh",
    "tmux-theme.sh",
}
METADATA_KEY_RE = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_.]*$")


def load_pack_toml() -> dict:
    return tomllib.loads((PACK / "pack.toml").read_text(encoding="utf-8"))


def load_formula(name: str) -> dict:
    path = PACK / "formulas" / f"{name}.formula.toml"
    return tomllib.loads(path.read_text(encoding="utf-8"))


def formula_files() -> list[pathlib.Path]:
    return sorted((PACK / "formulas").glob("*.formula.toml"))


def steps_by_id(formula: dict) -> dict[str, dict]:
    return {step["id"]: step for step in formula.get("steps", [])}


def iter_metadata_blocks(value: object, context: str = "root"):
    if isinstance(value, dict):
        metadata = value.get("metadata")
        if isinstance(metadata, dict):
            yield context, metadata
        for key, child in value.items():
            yield from iter_metadata_blocks(child, f"{context}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_metadata_blocks(child, f"{context}[{index}]")


def is_executable(path: pathlib.Path) -> bool:
    return bool(path.stat().st_mode & stat.S_IXUSR)


def test_pack_imports_gascity_and_jjw_without_copying_base_pack() -> None:
    pack = load_pack_toml()

    assert pack["pack"]["name"] == "gascity-jj-base"
    assert pack["imports"]["gc"]["source"] == "../gascity"
    assert pack["imports"]["jjw"]["source"] == "../jjw"
    assert pack["imports"]["packer"]["source"] == "../packer"
    assert "gastown" not in pack["imports"]
    assert not (PACK / "schemas").exists()
    assert not (PACK / "roles").exists()
    assert not (PACK / "assets" / "workflows" / "build-base").exists()


def test_pack_reuses_base_tmux_session_live_scripts() -> None:
    pack = load_pack_toml()

    assert pack["global"]["session_live"] == EXPECTED_TMUX_SESSION_LIVE
    assert not (PACK / "assets" / "scripts" / "tmux-theme.sh").exists()
    assert not (PACK / "assets" / "scripts" / "tmux-keybindings.sh").exists()

    base_scripts = ROOT / "gastown" / "assets" / "scripts"
    for script in BASE_TMUX_HELPERS:
        helper = base_scripts / script

        assert helper.is_file(), script
        assert is_executable(helper), script


def test_readme_declares_default_document_workspace_contract() -> None:
    readme = (PACK / "README.md").read_text(encoding="utf-8")

    assert "`default@` checkout" in readme
    assert "The live bead database remains DoltLite" in readme
    assert "does not copy the base pack" in readme
    assert "source = \"../packer\"" in readme
    assert "jj-pack-build" in readme
    assert "pack_route_formula" in readme
    assert "packer_mode=dev" in readme
    assert "pack_improvement_routing_policy=record-only" in readme
    assert "gascity-jj-mayor" in readme
    assert "docs/formula-improvement-plan.md" in readme


def test_mayor_overlay_declares_jj_document_handoff_contract() -> None:
    skill = (
        PACK / "skills" / "gascity-jj-mayor" / "SKILL.md"
    ).read_text(encoding="utf-8")

    assert "name: gascity-jj-mayor" in skill
    assert "Use this skill with the imported `mayor` skill" in skill
    assert "default@" in skill
    assert "DoltLite" in skill
    assert "manifest.json" in skill
    assert "gc.docs.workspace" in skill
    assert "metadata-safe document" in skill
    assert "gc.docs.<name>.path" in skill
    assert "jj-do-work-item" in skill


def test_formula_improvement_plan_declares_jj_extension_surface() -> None:
    plan = (PACK / "docs" / "formula-improvement-plan.md").read_text(
        encoding="utf-8"
    )

    for expected in [
        "default@",
        "manifest.json",
        "jj-build",
        "jj-planning-base",
        "jj-decomposition-base",
        "jj-implement",
        "jj-do-work",
        "jj-do-work-item",
        "jj-review",
        "jj-fix-loop",
        "jj-publish",
        "jj-pack-build",
        "jj-pack-implement",
        "jj-pack-fix-loop",
        "gc.pack",
        "gc.pack_root",
        "gc.pack_workspace",
        "packer_mode=dev",
        "gc.packer.pack-improvement-finding.v1",
        "root-task-stage-report",
        "DoltLite",
    ]:
        assert expected in plan


def test_pack_declares_all_jj_formula_files() -> None:
    found = {
        path.name.removesuffix(".formula.toml")
        for path in formula_files()
    }

    assert found == EXPECTED_FORMULAS


def test_formula_metadata_key_references_are_beads_safe() -> None:
    failures: list[str] = []

    for path in formula_files():
        formula = tomllib.loads(path.read_text(encoding="utf-8"))
        for context, metadata in iter_metadata_blocks(formula):
            for key, value in metadata.items():
                if not METADATA_KEY_RE.fullmatch(key):
                    failures.append(f"{path.name}:{context}: metadata key {key!r}")

                if not key.endswith(("_key", "_keys")):
                    continue

                for raw_reference in str(value).split(","):
                    reference = raw_reference.strip()
                    if not reference or "{{" in reference or "}}" in reference:
                        continue
                    if not METADATA_KEY_RE.fullmatch(reference):
                        failures.append(
                            f"{path.name}:{context}: {key} references "
                            f"invalid metadata key {reference!r}"
                        )

    assert failures == []

    for name in EXPECTED_FORMULAS:
        formula = load_formula(name)
        assert formula["formula"] == name
        assert formula["contract"] == "graph.v2"
        assert "manifest_path" in formula["vars"]
        assert "docs_workspace" in formula["vars"]
        assert formula["vars"]["docs_workspace"]["default"] == "default"
        if "docs_base_revset" in formula["vars"]:
            assert formula["vars"]["docs_base_revset"]["default"] == "default@"


def test_jj_formulas_extend_upstream_contracts() -> None:
    expected_extends = {
        "jj-build": ["build-base"],
        "jj-planning-base": ["planning-base"],
        "jj-decomposition-base": ["decomposition-base"],
        "jj-implement": ["implement"],
        "jj-do-work": ["do-work"],
        "jj-do-work-item": ["do-work-item"],
        "jj-review": ["review"],
        "jj-fix-loop": ["fix-loop-base"],
        "jj-publish": ["publish"],
        "jj-pack-build": ["jj-build"],
        "jj-pack-implement": ["jj-implement"],
        "jj-pack-fix-loop": ["jj-fix-loop"],
    }

    for name, extends in expected_extends.items():
        assert load_formula(name)["extends"] == extends


def test_pack_aware_formulas_define_pack_route_vars() -> None:
    for name in PACK_AWARE_FORMULAS:
        vars_ = load_formula(name)["vars"]

        assert vars_["pack"]["required"] is True
        assert vars_["pack_root"]["required"] is True
        assert vars_["pack_workspace"]["default"] == ""
        assert vars_["pack_route_target"]["default"] == "packer.packsmith"
        assert vars_["pack_route_formula"]["default"] == "mol-packer-work"
        assert vars_["source_workspace"]["default"] == ""
        assert vars_["source_workspace_path"]["default"] == ""
        assert vars_["source_change_id"]["default"] == ""


def test_pack_aware_formulas_define_dev_mode_self_review_vars() -> None:
    for name in PACK_AWARE_FORMULAS:
        vars_ = load_formula(name)["vars"]

        assert vars_["packer_mode"]["default"] == "normal"
        assert vars_["self_pack"]["default"] == "gascity-jj-base"
        assert vars_["self_pack_root"]["default"] == "gascity-jj-base"
        assert vars_["self_pack_workspace"]["default"] == ""
        assert (
            vars_["pack_improvement_routing_policy"]["default"]
            == "record-only"
        )


def test_pack_aware_source_steps_carry_pack_route_metadata() -> None:
    expected_steps = {
        "jj-pack-build": {"implement", "implement-same-session"},
        "jj-pack-implement": {"drain-separate", "drain-same-session"},
        "jj-pack-fix-loop": {
            "prepare-worktree",
            "describe-source-fix-change",
            "apply-fixes",
        },
    }

    for formula_name, step_ids in expected_steps.items():
        steps = steps_by_id(load_formula(formula_name))

        for step_id in step_ids:
            metadata = steps[step_id]["metadata"]

            assert metadata["gc.formula"] == "{{pack_route_formula}}"
            assert metadata["gc.route_target"] == "{{pack_route_target}}"
            assert metadata["gc.pack"] == "{{pack}}"
            assert metadata["gc.pack_root"] == "{{pack_root}}"
            assert metadata["gc.pack_workspace"] == "{{pack_workspace}}"
            assert metadata["gc.docs.managed"] == "true"
            assert metadata["gc.docs.manifest_path_keys"] == (
                "gc.docs.manifest_path,gc.var.manifest_path"
            )
            assert metadata["gc.docs.source_workspace_key"] == (
                "gc.docs.source_workspace,gc.var.source_workspace"
            )
            assert metadata["gc.docs.source_workspace_path_key"] == (
                "gc.docs.source_workspace_path,gc.var.source_workspace_path"
            )
            assert metadata["gc.docs.source_change_id_key"] == (
                "gc.docs.source_change_id,gc.var.source_change_id"
            )

            if "drain" in steps[step_id]:
                assert steps[step_id]["drain"]["formula"] == (
                    "{{pack_route_formula}}"
                )


def test_pack_self_review_steps_are_dev_mode_and_policy_gated() -> None:
    expected_review_needs = {
        "jj-pack-build": ["review"],
        "jj-pack-implement": ["summarize"],
        "jj-pack-fix-loop": ["re-review"],
    }

    for formula_name, needs in expected_review_needs.items():
        steps = steps_by_id(load_formula(formula_name))
        self_review = steps["pack-self-review"]
        route = steps["route-pack-improvement"]
        self_metadata = self_review["metadata"]
        route_metadata = route["metadata"]

        assert self_review["needs"] == needs
        assert self_review["condition"] == "{{packer_mode}} == dev"
        assert self_review["description_file"] == (
            "../assets/workflows/jj-docs/pack-self-review.md"
        )
        assert self_metadata["gc.run_target"] == "gc.run-operator"
        assert self_metadata["gc.packer.mode"] == "{{packer_mode}}"
        assert self_metadata["gc.packer.self_pack"] == "{{self_pack}}"
        assert self_metadata["gc.packer.self_pack_root"] == (
            "{{self_pack_root}}"
        )
        assert self_metadata["gc.packer.self_pack_workspace"] == (
            "{{self_pack_workspace}}"
        )
        assert self_metadata["gc.packer.finding_schema"] == (
            "gc.packer.pack-improvement-finding.v1"
        )
        assert self_metadata["gc.packer.routing_policy"] == (
            "{{pack_improvement_routing_policy}}"
        )
        assert "gc.pack" not in self_metadata
        assert "gc.pack_root" not in self_metadata

        assert route["needs"] == ["pack-self-review"]
        assert (
            route["condition"]
            == "{{pack_improvement_routing_policy}} == route-concrete"
        )
        assert route["description_file"] == (
            "../assets/workflows/jj-docs/pack-self-review.md"
        )
        assert route_metadata["gc.run_target"] == "gc.run-operator"
        assert route_metadata["gc.formula"] == "mol-packer-work"
        assert (
            route_metadata["gc.route_target"]
            == "gascity-packs/packer.packsmith"
        )
        assert route_metadata["gc.pack"] == "{{self_pack}}"
        assert route_metadata["gc.pack_root"] == "{{self_pack_root}}"
        assert route_metadata["gc.pack_workspace"] == (
            "{{self_pack_workspace}}"
        )
        assert route_metadata["gc.packer.mode"] == "{{packer_mode}}"


def test_ordinary_jj_formulas_do_not_carry_pack_route_metadata() -> None:
    ordinary = EXPECTED_FORMULAS - PACK_AWARE_FORMULAS
    pack_keys = {
        "gc.pack",
        "gc.pack_root",
        "gc.pack_workspace",
        "gc.route_target",
        "gc.packer.self_pack",
        "gc.packer.self_pack_root",
        "gc.packer.self_pack_workspace",
    }
    pack_vars = {
        "pack",
        "pack_root",
        "pack_workspace",
        "packer_mode",
        "self_pack",
        "self_pack_root",
        "self_pack_workspace",
        "pack_improvement_routing_policy",
    }

    for name in ordinary:
        formula = load_formula(name)
        assert pack_vars.isdisjoint(formula.get("vars", {})), name
        for step in formula.get("steps", []):
            metadata = step.get("metadata", {})
            assert pack_keys.isdisjoint(metadata), name
            if "drain" in step:
                assert step["drain"].get("formula") != "{{pack_route_formula}}"


def test_jj_build_and_implement_route_drains_to_jj_item_formulas() -> None:
    for formula_name, separate_step, shared_step in [
        ("jj-build", "implement", "implement-same-session"),
        ("jj-implement", "drain-separate", "drain-same-session"),
    ]:
        formula = load_formula(formula_name)
        steps = {step["id"]: step for step in formula["steps"]}

        assert steps[separate_step]["drain"]["formula"] == "jj-do-work"
        assert steps[shared_step]["drain"]["formula"] == "jj-do-work-item"
        assert (
            steps[shared_step]["drain"]["on_item_failure"]
            == "skip_remaining"
        )


def test_parent_drain_steps_carry_source_workspace_reuse_metadata() -> None:
    for formula_name, step_ids in {
        "jj-build": {"implement", "implement-same-session"},
        "jj-implement": {"drain-separate", "drain-same-session"},
    }.items():
        steps = steps_by_id(load_formula(formula_name))

        for step_id in step_ids:
            metadata = steps[step_id]["metadata"]

            assert metadata["gc.docs.source_workspace_key"] == (
                "gc.docs.source_workspace,gc.var.source_workspace"
            )
            assert metadata["gc.docs.source_workspace_path_key"] == (
                "gc.docs.source_workspace_path,gc.var.source_workspace_path"
            )
            assert metadata["gc.docs.source_change_id_key"] == (
                "gc.docs.source_change_id,gc.var.source_change_id"
            )


def test_document_steps_carry_manifest_metadata() -> None:
    for path in formula_files():
        formula = tomllib.loads(path.read_text(encoding="utf-8"))
        for step in formula.get("steps", []):
            metadata = step.get("metadata", {})
            if metadata.get("gc.docs.managed") == "true":
                assert "gc.docs.manifest_path_keys" in metadata

            document_name = metadata.get("gc.docs.document")
            if document_name:
                assert "gc.docs.document_path_keys" in metadata
                assert "gc.docs.document_schema" in metadata


def test_source_workspace_contract_records_paths() -> None:
    for path in formula_files():
        formula = tomllib.loads(path.read_text(encoding="utf-8"))
        vars_ = formula.get("vars", {})
        if "source_workspace" in vars_:
            assert "source_workspace_path" in vars_, path.name

        for step in formula.get("steps", []):
            metadata = step.get("metadata", {})
            if "gc.docs.source_workspace_key" not in metadata:
                continue

            assert metadata["gc.docs.source_workspace_key"] == (
                "gc.docs.source_workspace,gc.var.source_workspace"
            )
            assert metadata["gc.docs.source_workspace_path_key"] == (
                "gc.docs.source_workspace_path,gc.var.source_workspace_path"
            )


def test_formula_owned_source_workspace_setup_precedes_source_work() -> None:
    def has_dependency_path(
        steps: dict[str, dict], step_id: str, dependency_id: str
    ) -> bool:
        pending = list(steps[step_id].get("needs", []))
        seen: set[str] = set()
        while pending:
            current = pending.pop()
            if current == dependency_id:
                return True
            if current in seen:
                continue
            seen.add(current)
            pending.extend(steps.get(current, {}).get("needs", []))
        return False

    for formula_name, source_steps in {
        "jj-do-work": ["describe-source-change", "implement", "close-source-anchor"],
        "jj-do-work-item": ["describe-source-change", "implement-item"],
        "jj-fix-loop": ["describe-source-fix-change", "apply-fixes"],
    }.items():
        steps = steps_by_id(load_formula(formula_name))
        assert steps["prepare-worktree"]["description_file"] == (
            "../assets/workflows/jj-docs/prepare-worktree.md"
        )
        for step_id in source_steps:
            assert has_dependency_path(steps, step_id, "prepare-worktree")


def test_prepare_worktree_uses_packer_style_formula_workspace_setup() -> None:
    doc = (
        PACK / "assets" / "workflows" / "jj-docs" / "prepare-worktree.md"
    ).read_text(encoding="utf-8")

    assert "This formula step owns workspace creation and switching" in doc
    assert ".gc/workspaces/<rig>/packs/<pack>" in doc
    assert "gc.pack_workspace" in doc
    assert "jjw/assets/scripts/workspace-setup.sh" in doc
    assert "GC_JJW_BOOKMARK_PATTERN='gc/<pack>.{name}'" in doc
    assert "gc.docs.source_workspace_path" in doc


def test_source_workspace_policy_reuses_stable_lanes_not_formula_steps() -> None:
    prepare = (
        PACK / "assets" / "workflows" / "jj-docs" / "prepare-worktree.md"
    ).read_text(encoding="utf-8")
    drain = (
        PACK / "assets" / "workflows" / "jj-docs" / "drain-separate.md"
    ).read_text(encoding="utf-8")
    implement = (
        PACK / "assets" / "workflows" / "jj-docs" / "implementation-item.md"
    ).read_text(encoding="utf-8")

    assert "Reuse before creating" in prepare
    assert "Never include the formula name, step ID, step bead ID" in prepare
    assert "generated session name" in prepare
    assert "Separate sessions are execution lanes, not source workspace identities" in drain
    assert "Do not create or select a new jj workspace in this step" in implement


def test_fix_loop_apply_fixes_declares_implementation_summary_contract() -> None:
    formula = load_formula("jj-fix-loop")
    metadata = steps_by_id(formula)["apply-fixes"]["metadata"]

    assert metadata["gc.build.artifact_schema"] == (
        "gc.build.implementation-summary.v1"
    )
    assert metadata["gc.docs.document"] == "implementation-summary"
    assert metadata["gc.docs.document_schema"] == (
        "gc.build.implementation-summary.v1"
    )
    assert metadata["gc.docs.document_path_keys"] == (
        "gc.docs.implementation_summary.path,"
        "gc.implementation.summary_path,"
        "gc.build.implementation_summary_path,"
        "gc.var.summary_path"
    )
    assert metadata["gc.build.artifact_path_keys"] == (
        "gc.implementation.summary_path,"
        "gc.build.implementation_summary_path,"
        "gc.var.summary_path,"
        "gc.docs.implementation_summary.path"
    )


def test_fix_loop_document_describe_steps_select_document_workspace() -> None:
    steps = steps_by_id(load_formula("jj-fix-loop"))

    for step_id in {"describe-fix-plan-change", "describe-re-review-change"}:
        metadata = steps[step_id]["metadata"]

        assert metadata["gc.jj.describe_scope"] == "document"
        assert metadata["gc.docs.workspace_key"] == (
            "gc.docs.workspace,gc.var.docs_workspace"
        )
        assert metadata["gc.docs.workspace_path_key"] == (
            "gc.docs.workspace_path,gc.var.docs_workspace_path"
        )


def test_implementation_item_prompt_requires_durable_closeout() -> None:
    doc = (
        PACK / "assets" / "workflows" / "jj-docs" / "implementation-item.md"
    ).read_text(encoding="utf-8")

    assert "the claimed step bead, and the workflow root bead" in doc
    assert "gc.docs.implementation_summary.path" in doc
    assert "GC_BEAD_ID=<claimed-step-id>" in doc
    assert "gc.outcome=pass" in doc
    assert "bd close <claimed-step-id> --reason" in doc
    assert "Do not pass" in doc


def test_pack_self_review_prompt_declares_structured_finding_format() -> None:
    doc = (
        PACK / "assets" / "workflows" / "jj-docs" / "pack-self-review.md"
    ).read_text(encoding="utf-8")

    for expected in [
        "packer_mode=dev",
        "missing metadata",
        "step handoff clarity",
        "`source_change_id` visibility",
        "workdir and workspace assumptions",
        "prompt gaps",
        "check gaps",
        "PACK_IMPROVEMENT_FINDING v1",
        "source_formula:",
        "source_step_id:",
        "trigger_bead:",
        "observed_friction:",
        "suggested_pack_change:",
        "evidence:",
        "acceptance_criteria:",
        "pack_improvement_routing_policy=route-concrete",
        "gascity-packs/packer.packsmith",
        "gc.pack={{self_pack}}",
        "gc.pack_root={{self_pack_root}}",
        "gc.pack_workspace={{self_pack_workspace}}",
        "gc.formula=mol-packer-work",
    ]:
        assert expected in doc


def test_describe_workflow_declares_pre_edit_jj_semantics() -> None:
    doc = (
        PACK / "assets" / "workflows" / "jj-docs" / "describe-jj-change.md"
    ).read_text(encoding="utf-8")

    assert "before making those edits" in doc
    assert "jj describe -m" in doc
    assert "jj new -m" in doc
    assert "(no description set)" in doc


def test_every_formula_has_concrete_describe_step() -> None:
    for name in EXPECTED_FORMULAS:
        if name in FORMULAS_WITH_INHERITED_DESCRIBE_STEPS:
            continue

        formula = load_formula(name)
        describe_steps = [
            step
            for step in formula["steps"]
            if step.get("metadata", {}).get("gc.jj.describe") == "true"
        ]

        assert describe_steps, name

        for step in describe_steps:
            metadata = step["metadata"]
            assert step["description_file"] == (
                "../assets/workflows/jj-docs/describe-jj-change.md"
            )
            assert "gc.run_target" in metadata
            assert metadata["gc.jj.describe_scope"] in {"document", "source"}
            assert "gc.docs.manifest_path_keys" in metadata
            if metadata["gc.jj.describe_scope"] == "document":
                assert (
                    metadata["gc.docs.workspace_key"]
                    == "gc.docs.workspace,gc.var.docs_workspace"
                )
                assert (
                    metadata["gc.docs.workspace_path_key"]
                    == "gc.docs.workspace_path,gc.var.docs_workspace_path"
                )


def test_mutating_steps_depend_on_concrete_describe_steps() -> None:
    source_edit_descriptions = {
        "../assets/workflows/jj-docs/fix-loop.md",
        "../assets/workflows/jj-docs/implementation-item.md",
    }

    for name in EXPECTED_FORMULAS:
        formula = load_formula(name)
        steps = steps_by_id(formula)
        describe_step_ids = {
            step_id
            for step_id, step in steps.items()
            if step.get("metadata", {}).get("gc.jj.describe") == "true"
        }

        for step_id, step in steps.items():
            metadata = step.get("metadata", {})
            mutates_document = bool(metadata.get("gc.docs.document"))
            mutates_source = step.get("description_file") in source_edit_descriptions
            if not (mutates_document or mutates_source):
                continue

            needs = set(step.get("needs", []))
            direct_describe_needs = needs & describe_step_ids
            assert direct_describe_needs, f"{name}:{step_id}"

            for describe_step_id in direct_describe_needs:
                describe_needs = set(steps[describe_step_id].get("needs", []))
                assert describe_needs <= needs, f"{name}:{step_id}"


def test_formula_description_files_exist() -> None:
    for path in formula_files():
        formula = tomllib.loads(path.read_text(encoding="utf-8"))
        for step in formula.get("steps", []):
            description_file = step.get("description_file")
            if not description_file:
                continue

            resolved = (path.parent / description_file).resolve()
            assert resolved.is_file(), f"{path.name}:{step['id']} -> {resolved}"


def test_root_task_stage_report_uses_tracked_document_generator() -> None:
    formula = load_formula("root-task-stage-report")
    steps = steps_by_id(formula)
    generate = steps["generate-report"]
    metadata = generate["metadata"]
    script = PACK / "assets" / "scripts" / "root-task-stage-report.js"

    assert script.is_file()
    assert is_executable(script)
    assert formula["vars"]["report_path"]["default"] == ""
    assert metadata["gc.docs.managed"] == "true"
    assert metadata["gc.docs.document"] == "root-task-stage-report"
    assert metadata["gc.docs.document_schema"] == "gc.reports.root-task-stage.v1"
    assert "gc.docs.root_task_stage_report.path" in metadata[
        "gc.docs.document_path_keys"
    ]
