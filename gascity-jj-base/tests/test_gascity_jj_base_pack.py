from __future__ import annotations

import pathlib
import tomllib


PACK = pathlib.Path(__file__).resolve().parents[1]
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
}


def load_pack_toml() -> dict:
    return tomllib.loads((PACK / "pack.toml").read_text(encoding="utf-8"))


def load_formula(name: str) -> dict:
    path = PACK / "formulas" / f"{name}.formula.toml"
    return tomllib.loads(path.read_text(encoding="utf-8"))


def formula_files() -> list[pathlib.Path]:
    return sorted((PACK / "formulas").glob("*.formula.toml"))


def test_pack_imports_gascity_and_jjw_without_copying_base_pack() -> None:
    pack = load_pack_toml()

    assert pack["pack"]["name"] == "gascity-jj-base"
    assert pack["imports"]["gc"]["source"] == "../gascity"
    assert pack["imports"]["jjw"]["source"] == "../jjw"
    assert not (PACK / "schemas").exists()
    assert not (PACK / "roles").exists()
    assert not (PACK / "assets" / "workflows" / "build-base").exists()


def test_readme_declares_default_document_workspace_contract() -> None:
    readme = (PACK / "README.md").read_text(encoding="utf-8")

    assert "`default@` checkout" in readme
    assert "The live bead database remains DoltLite" in readme
    assert "does not copy the base pack" in readme
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
        "DoltLite",
    ]:
        assert expected in plan


def test_pack_declares_all_jj_formula_files() -> None:
    found = {
        path.name.removesuffix(".formula.toml")
        for path in formula_files()
    }

    assert found == EXPECTED_FORMULAS

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
    }

    for name, extends in expected_extends.items():
        assert load_formula(name)["extends"] == extends


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


def test_formula_description_files_exist() -> None:
    for path in formula_files():
        formula = tomllib.loads(path.read_text(encoding="utf-8"))
        for step in formula.get("steps", []):
            description_file = step.get("description_file")
            if not description_file:
                continue

            resolved = (path.parent / description_file).resolve()
            assert resolved.is_file(), f"{path.name}:{step['id']} -> {resolved}"
