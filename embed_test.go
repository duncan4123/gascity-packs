package gascitypacks

import (
	"io/fs"
	"testing"
)

func TestGastownEmbedsPackContent(t *testing.T) {
	pack := Gastown()
	for _, rel := range []string{
		"pack.toml",
		"agents/dog/agent.toml",
		"agents/dog/prompt.template.md",
		"formulas/mol-shutdown-dance.toml",
		"template-fragments/propulsion.template.md",
		"overlay/per-provider/codex/.codex/hooks.json",
	} {
		if _, err := fs.Stat(pack, rel); err != nil {
			t.Errorf("gastown pack missing %s: %v", rel, err)
		}
	}
}

func TestGascityEmbedsPackContent(t *testing.T) {
	pack := Gascity()
	for _, rel := range []string{
		"pack.toml",
		"formulas/implement.formula.toml",
		"formulas/build-base.formula.toml",
		"formulas/build-basic.formula.toml",
		"skills/mayor/SKILL.md",
		"assets/scripts/checks/gap-analysis-approved.sh",
		"assets/scripts/checks/build-artifact-valid.sh",
		"roles/pack.toml",
	} {
		if _, err := fs.Stat(pack, rel); err != nil {
			t.Errorf("gascity pack missing %s: %v", rel, err)
		}
	}
}

func TestBdGcDlEmbedsPackContent(t *testing.T) {
	pack := BdGcDl()
	for _, rel := range []string{
		"pack.toml",
		"agents/bd-gc-dl-fixer/agent.toml",
		"agents/bd-gc-dl-fixer/prompt.template.md",
		"commands/build/command.toml",
		"commands/build/help.md",
		"commands/build/run.sh",
		"commands/file-fix-task/command.toml",
		"commands/file-fix-task/help.md",
		"commands/file-fix-task/run.sh",
		"skills/bd-gc-dl-build-release/SKILL.md",
		"skills/bd-gc-dl-migrate/SKILL.md",
		"template-fragments/bd-gc-dl-handoff.template.md",
	} {
		if _, err := fs.Stat(pack, rel); err != nil {
			t.Errorf("bd-gc-dl pack missing %s: %v", rel, err)
		}
	}
}

func TestEmbedHasNoUnexpectedRoots(t *testing.T) {
	entries, err := fs.ReadDir(packsFS, ".")
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]bool{"gastown": true, "gascity": true, "bd-gc-dl": true}
	if len(entries) != len(want) {
		names := make([]string, 0, len(entries))
		for _, e := range entries {
			names = append(names, e.Name())
		}
		t.Fatalf("embedded roots = %v, want gastown + gascity + bd-gc-dl", names)
	}
	for _, e := range entries {
		if !want[e.Name()] {
			t.Fatalf("unexpected embedded root %q", e.Name())
		}
	}
}
