"""Keep instruction scaffolding out of content checks in isolated projects."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
INSTRUCTIONS = ("AGENTS.md", "AGENTS.override.md", "CLAUDE.md", "CLAUDE.local.md")
BASH = shutil.which("bash")
if not BASH and os.name == "nt":
    candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
    BASH = str(candidate) if candidate.is_file() else None


@unittest.skipUnless(shutil.which("git") and BASH, "Git and Bash required")
class SharedHookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        # Every invoked hook and its helper belong to the disposable tree.
        # Newer hooks otherwise resolve their own location as the project root.
        hooks = self.root / ".claude/hooks"
        hooks.mkdir(parents=True)
        for name in ("yaml-helper.sh", "validate-commit.sh", "validate-assets.sh", "detect-gaps.sh"):
            shutil.copyfile(ROOT / ".claude/hooks" / name, hooks / name)
        self.write("project.yaml", "schema_version: 1\nengine:\n  name: Godot\nmodes:\n  workflow: standard\n")
        self.env = os.environ.copy()
        self.env.pop("CLAUDE_PROJECT_DIR", None)
        self.env["PATH"] = os.pathsep.join((str(Path(sys.executable).parent), self.env.get("PATH", "")))
        subprocess.run(["git", "init", "-q", str(self.root)], check=True, env=self.env)

    def write(self, path, text="Instructions\n"):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def instructions(self, directory):
        for name in INSTRUCTIONS:
            self.write(f"{directory}/{name}")

    def run_hook(self, name, payload=None):
        return subprocess.run(
            [BASH, f".claude/hooks/{name}"], cwd=self.root, env=self.env,
            input=json.dumps(payload or {}), text=True, encoding="utf-8",
            capture_output=True, timeout=30,
        )

    def output(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout + result.stderr

    def test_commit_ignores_instruction_documents_but_checks_real_gdds(self):
        self.instructions("design/gdd")
        subprocess.run(["git", "add", "design/gdd"], cwd=self.root, env=self.env, check=True)
        output = self.output(self.run_hook("validate-commit.sh", {"tool_input": {"command": "git commit"}}))
        self.assertNotIn("DESIGN:", output)
        self.write("design/gdd/combat.md", "# Combat\n")
        subprocess.run(["git", "add", "design/gdd/combat.md"], cwd=self.root, env=self.env, check=True)
        output = self.output(self.run_hook("validate-commit.sh", {"tool_input": {"command": "git commit"}}))
        self.assertIn("DESIGN: design/gdd/combat.md", output)

    def test_gap_detection_counts_only_game_documents_and_real_core_code(self):
        for index in range(51):
            self.write(f"src/sample_{index}.gd", "extends Node\n")
        self.instructions("src/core")
        self.instructions("design/gdd")
        self.instructions("design/gdd/archive")
        self.write("design/gdd/movement.md", "# Movement\n")
        output = self.output(self.run_hook("detect-gaps.sh"))
        self.assertIn("sparse design docs (1 files)", output)
        self.assertNotIn("Not counted:", output)
        self.assertNotIn("Core engine/systems exist", output)

    def test_architecture_count_excludes_instructions_but_keeps_actual_adrs(self):
        self.write("src/core/system.gd", "extends Node\n")
        self.instructions("docs/architecture")
        self.write("docs/architecture/ADR-001.md", "# Architecture decision\n")
        output = self.output(self.run_hook("detect-gaps.sh"))
        self.assertIn("only 1 ADR(s) documented", output)

    def test_gameplay_size_excludes_instructions_but_keeps_real_systems(self):
        self.instructions("src/gameplay/combat")
        self.write("src/gameplay/combat/system_0.gd", "extends Node\n")
        output = self.output(self.run_hook("detect-gaps.sh"))
        self.assertNotIn("Gameplay system", output)
        for index in range(1, 5):
            self.write(f"src/gameplay/combat/system_{index}.gd", "extends Node\n")
        output = self.output(self.run_hook("detect-gaps.sh"))
        self.assertIn("Gameplay system 'src/gameplay/combat/' (5 files)", output)

    def test_asset_hook_ignores_instruction_names_but_checks_real_assets(self):
        self.instructions("assets/data")
        for name in INSTRUCTIONS:
            with self.subTest(name=name):
                output = self.output(self.run_hook("validate-assets.sh", {
                    "tool_input": {"file_path": f"assets/data/{name}"},
                }))
                self.assertNotIn("NAMING", output)
        self.write("assets/data/Boss Notes.md")
        output = self.output(self.run_hook("validate-assets.sh", {
            "tool_input": {"file_path": "assets/data/Boss Notes.md"},
        }))
        self.assertIn("NAMING", output)


if __name__ == "__main__":
    unittest.main()
