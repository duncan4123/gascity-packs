from __future__ import annotations

import json
import os
import subprocess
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PACKER = ROOT / "packer"


def load_toml(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8"))


def agent_config(name: str) -> dict:
    return load_toml(PACKER / "agents" / name / "agent.toml")


def named_session_templates() -> set[str]:
    data = load_toml(PACKER / "pack.toml")
    return {entry["template"] for entry in data.get("named_session", [])}


def test_packrouter_is_named_session_not_pool_agent() -> None:
    assert named_session_templates() == {"packrouter"}

    router = agent_config("packrouter")
    pool_fields = {
        "min_active_sessions",
        "max_active_sessions",
        "scale_check",
        "namepool",
        "namepool_names",
    }
    assert pool_fields.isdisjoint(router), sorted(pool_fields.intersection(router))


def test_packsmith_is_pool_agent_not_named_session() -> None:
    assert "packsmith" not in named_session_templates()

    packsmith = agent_config("packsmith")
    assert packsmith["min_active_sessions"] == 0
    assert packsmith["max_active_sessions"] > 1
    assert "gc.pack/gc.pack_root" in (PACKER / "agents" / "packsmith" / "agent.toml").read_text(
        encoding="utf-8"
    )


def test_create_pack_bead_dry_run_writes_route_metadata() -> None:
    script = PACKER / "assets" / "scripts" / "create-pack-bead.sh"
    env = os.environ.copy()
    env["GC_RIG"] = "gascity-packs"
    result = subprocess.run(
        [
            str(script),
            "--pack",
            "jj-hunk",
            "--pack-root",
            "packs/jj-hunk",
            "--workspace",
            "jj-hunk.fix-routing",
            "--title",
            "jj-hunk: fix routing",
            "--description",
            "body",
            "--acceptance",
            "gc lint jj-hunk passes",
            "--parent",
            "gp-parent",
            "--dry-run",
        ],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )

    assert 'bd create jj-hunk: fix routing --metadata @' in result.stdout
    assert " --description body" in result.stdout
    assert " --acceptance gc lint jj-hunk passes" in result.stdout
    assert " --parent gp-parent" in result.stdout
    assert "gc sling gascity-packs/packer.packsmith <child-bead-id> --on mol-packer-work --nudge" in result.stdout

    metadata_line = next(line for line in result.stdout.splitlines() if line.startswith("metadata: "))
    metadata = json.loads(metadata_line.removeprefix("metadata: "))
    assert metadata == {
        "gc.formula": "mol-packer-work",
        "gc.pack": "jj-hunk",
        "gc.pack_root": "packs/jj-hunk",
        "gc.pack_workspace": "jj-hunk.fix-routing",
        "gc.route_target": "gascity-packs/packer.packsmith",
    }


def test_create_pack_bead_dry_run_defaults_to_pack_workspace() -> None:
    script = PACKER / "assets" / "scripts" / "create-pack-bead.sh"
    env = os.environ.copy()
    env["GC_RIG"] = "gascity-packs"
    result = subprocess.run(
        [
            str(script),
            "--pack",
            "jjw",
            "--title",
            "jjw: update workspace docs",
            "--dry-run",
        ],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=True,
    )

    assert "bd update <child-bead-id> --set-metadata gc.pack_workspace=" not in result.stdout
    metadata_line = next(line for line in result.stdout.splitlines() if line.startswith("metadata: "))
    metadata = json.loads(metadata_line.removeprefix("metadata: "))
    assert metadata == {
        "gc.formula": "mol-packer-work",
        "gc.pack": "jjw",
        "gc.pack_root": "jjw",
        "gc.route_target": "gascity-packs/packer.packsmith",
    }


def test_create_pack_bead_dry_run_can_request_task_workspace() -> None:
    script = PACKER / "assets" / "scripts" / "create-pack-bead.sh"
    result = subprocess.run(
        [
            str(script),
            "--pack",
            "jjw",
            "--title",
            "jjw: update workspace docs",
            "--task-workspace",
            "--dry-run",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )

    assert "bd update <child-bead-id> --set-metadata gc.pack_workspace=<child-bead-id>-<title-slug>" in result.stdout
    metadata_line = next(line for line in result.stdout.splitlines() if line.startswith("metadata: "))
    metadata = json.loads(metadata_line.removeprefix("metadata: "))
    assert "gc.pack_workspace" not in metadata


def test_create_pack_bead_rejects_invalid_workspace_name() -> None:
    script = PACKER / "assets" / "scripts" / "create-pack-bead.sh"
    result = subprocess.run(
        [
            str(script),
            "--pack",
            "jj-hunk",
            "--workspace",
            "../escape",
            "--title",
            "bad workspace",
            "--dry-run",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 2
    assert "invalid --workspace" in result.stderr


def test_list_pack_workspaces_filters_pack_and_reports_title(tmp_path: Path) -> None:
    script = PACKER / "assets" / "scripts" / "list-pack-workspaces.sh"
    payload = {
        "sessions": [
            {
                "id": "dg-jjw",
                "template": "gascity-packs/packer.packsmith",
                "state": "active",
                "alias": "worker-jjw",
                "work_dir": "/repo/.gc/workspaces/gascity-packs/packs/jjw",
                "title": "jjw: update workspace docs",
            },
            {
                "id": "dg-hunk",
                "template": "gascity-packs/packer.packsmith",
                "state": "asleep",
                "session_name": "worker-hunk",
                "work_dir": "/repo/.gc/workspaces/gascity-packs/packs/jj-hunk/fix-routing",
                "title": "jj-hunk: fix routing",
            },
            {
                "id": "dg-other",
                "template": "gascity-packs/other.agent",
                "state": "active",
                "work_dir": "/repo/.gc/workspaces/gascity-packs/packs/jj-hunk/other",
                "title": "not a packsmith",
            },
        ]
    }
    fixture = tmp_path / "sessions.json"
    fixture.write_text(json.dumps(payload), encoding="utf-8")

    result = subprocess.run(
        [str(script), "--pack", "jj-hunk", "--from-json", str(fixture)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )

    assert "SESSION\tSTATE\tTARGET\tRIG\tPACK\tWORKSPACE\tWORKDIR\tTITLE" in result.stdout
    assert "dg-hunk\tasleep\tworker-hunk\tgascity-packs\tjj-hunk\tfix-routing" in result.stdout
    assert "jj-hunk: fix routing" in result.stdout
    assert "dg-jjw" not in result.stdout
    assert "not a packsmith" not in result.stdout


def test_pack_workspace_setup_uses_bead_selected_pack_not_agent_default() -> None:
    script = (PACKER / "assets" / "scripts" / "pack-workspace-setup.sh").read_text(encoding="utf-8")

    assert 'PACK_NAME="${GC_PACKER_PACK:-${PACKER_PACK:-}}"' in script
    assert 'trigger_pack=' in script
    assert 'trigger_pack_root=' in script
    assert 'GC_JJW_WORKSPACE_DIR="$PACK_WORKSPACE_PARENT"' in script
    assert 'missing or invalid pack name' in script
    assert "PACK_NAME=\"$AGENT_NAME\"" not in script
