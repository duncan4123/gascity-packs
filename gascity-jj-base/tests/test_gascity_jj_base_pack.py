from __future__ import annotations

import pathlib
import tomllib


PACK = pathlib.Path(__file__).resolve().parents[1]


def load_pack_toml() -> dict:
    return tomllib.loads((PACK / "pack.toml").read_text(encoding="utf-8"))


def test_pack_imports_gascity_and_jjw_without_copying_base_pack() -> None:
    pack = load_pack_toml()

    assert pack["pack"]["name"] == "gascity-jj-base"
    assert pack["imports"]["gc"]["source"] == "../gascity"
    assert pack["imports"]["jjw"]["source"] == "../jjw"
    assert not (PACK / "schemas").exists()
    assert not (PACK / "roles").exists()
    assert not (PACK / "assets" / "workflows" / "build-base").exists()
