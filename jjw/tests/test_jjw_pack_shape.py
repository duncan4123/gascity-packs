from __future__ import annotations

import os
import pathlib
import subprocess
import tomllib


PACK_DIR = pathlib.Path(__file__).resolve().parent.parent
REPO_ROOT = PACK_DIR.parent


def read_toml(relative_path: str) -> dict:
    return tomllib.loads((PACK_DIR / relative_path).read_text(encoding="utf-8"))


def assert_shell_script(relative_path: str) -> None:
    script = PACK_DIR / relative_path
    assert script.is_file(), f"missing script: {relative_path}"
    assert script.read_text(encoding="utf-8").startswith("#!/bin/sh\n")
    assert os.access(script, os.X_OK), f"script must be executable: {relative_path}"
    subprocess.run(["sh", "-n", str(script)], check=True)


def test_pack_manifest_declares_jjw_identity() -> None:
    manifest = read_toml("pack.toml")

    assert manifest["pack"]["name"] == "jjw"
    assert manifest["pack"]["schema"] == 2
    assert manifest["pack"]["version"] == "0.1.0"
    assert "Jujutsu workspace setup helpers" in manifest["pack"]["description"]


def test_workspace_report_formula_contract() -> None:
    formula = read_toml("formulas/mol-jjw-workspace-report.toml")

    assert formula["formula"] == "mol-jjw-workspace-report"
    assert formula["phase"] == "vapor"
    assert formula["pool"] == "dog"
    assert formula["steps"][0]["id"] == "report"

    text = "\n".join(
        [
            formula["description"],
            formula["steps"][0]["title"],
            formula["steps"][0]["description"],
        ]
    )
    for fragment in (
        "gc bd formula show mol-jjw-workspace-report --json",
        "jjw version",
        "jjw list --verbose",
        'bd update "$WORK_BEAD" --append-notes',
        "gc runtime drain-ack",
    ):
        assert fragment in text


def test_commands_doctor_orders_and_assets_are_wired() -> None:
    assert "Install aranw/jjw" in read_toml("commands/install/command.toml")[
        "description"
    ]
    assert "workspace health report" in read_toml(
        "commands/workspace-report/command.toml"
    )["description"]
    assert "jjw is available" in read_toml("doctor/check-jjw/doctor.toml")[
        "description"
    ]

    direct_order = read_toml("orders/workspace-report.toml")["order"]
    assert direct_order["trigger"] == "cooldown"
    assert direct_order["interval"] == "5m"
    assert "jjw list --verbose" in direct_order["exec"]

    formula_order = read_toml("orders/jjw-workspace-report.toml")["order"]
    assert formula_order["formula"] == "mol-jjw-workspace-report"
    assert formula_order["pool"] == "dog"

    for script in (
        "assets/scripts/install-jjw.sh",
        "assets/scripts/workspace-setup.sh",
        "assets/scripts/workspace-report.sh",
        "commands/install/run.sh",
        "commands/workspace-report/run.sh",
        "doctor/check-jjw/run.sh",
    ):
        assert_shell_script(script)

    assert "../../assets/scripts/install-jjw.sh" in (
        PACK_DIR / "commands/install/run.sh"
    ).read_text(encoding="utf-8")
    assert "../../assets/scripts/workspace-report.sh" in (
        PACK_DIR / "commands/workspace-report/run.sh"
    ).read_text(encoding="utf-8")


def test_template_fragments_cover_workspace_setup_and_reporting() -> None:
    fragments = {
        "template-fragments/jjw-workspace-setup.template.md": (
            '{{ define "jjw-workspace-setup" -}}',
            "assets/scripts/workspace-setup.sh",
            "JJW_NAME",
            "path disagree",
        ),
        "template-fragments/jjw-workspace-reporting.template.md": (
            '{{ define "jjw-workspace-reporting" -}}',
            "gc jjw workspace-report",
            "mol-jjw-workspace-report",
            "jjw list --verbose",
        ),
    }

    for relative_path, expected_fragments in fragments.items():
        text = (PACK_DIR / relative_path).read_text(encoding="utf-8")
        for expected in expected_fragments:
            assert expected in text


def test_readmes_list_jjw_entrypoints() -> None:
    pack_readme = (PACK_DIR / "README.md").read_text(encoding="utf-8")
    for fragment in (
        "assets/scripts/install-jjw.sh",
        "assets/scripts/workspace-setup.sh",
        "assets/scripts/workspace-report.sh",
        "gc jjw install",
        "gc jjw workspace-report",
        "formulas/mol-jjw-workspace-report.toml",
        "orders/workspace-report.toml",
        "orders/jjw-workspace-report.toml",
        "doctor/check-jjw",
        "template-fragments/jjw-workspace-setup.template.md",
        "template-fragments/jjw-workspace-reporting.template.md",
    ):
        assert fragment in pack_readme

    root_readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    assert "[jjw](./jjw)" in root_readme
    assert "workspace setup/reporting" in root_readme
