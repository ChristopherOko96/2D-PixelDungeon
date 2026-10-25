"""Exercise the validator bridge against disposable Git repositories only."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
GIT = shutil.which("git")
BASH = shutil.which("bash")
if not BASH and os.name == "nt":
    candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
    BASH = str(candidate) if candidate.is_file() else None


@unittest.skipUnless(GIT and BASH, "Git and Bash required")
class StudioCheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = os.environ.copy()
        self.env.pop("CLAUDE_PROJECT_DIR", None)
        self.env.pop("STUDIO_BASH", None)
        self.env["PATH"] = os.pathsep.join((str(Path(sys.executable).parent), str(Path(BASH).parent), self.env.get("PATH", "")))
        subprocess.run([GIT, "init", "-q", str(self.root)], check=True, env=self.env)
        hooks = self.root / ".claude/hooks"
        hooks.mkdir(parents=True)
        for name in ("validate-commit.sh", "validate-push.sh", "yaml-helper.sh"):
            shutil.copyfile(ROOT / ".claude/hooks" / name, hooks / name)

    def check(self, kind, env=None):
        return subprocess.run(
            [sys.executable, str(ROOT / "scripts/studio_check.py"), kind, "--root", str(self.root)],
            capture_output=True, text=True, encoding="utf-8", timeout=35, env=env or self.env,
        )

    def stage_data(self, content):
        data = self.root / "assets/data/enemy.json"
        data.parent.mkdir(parents=True, exist_ok=True)
        data.write_text(content, encoding="utf-8")
        subprocess.run([GIT, "add", "assets/data/enemy.json"], cwd=self.root, check=True, env=self.env)
        return data

    def test_invalid_staged_json_blocks_without_committing(self):
        self.stage_data('{"health": broken}')
        result = self.check("commit")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("not valid JSON", result.stderr)
        self.assertNotEqual(subprocess.run([GIT, "rev-parse", "--verify", "HEAD"], cwd=self.root,
                                          capture_output=True, env=self.env).returncode, 0)

    def test_valid_staged_json_passes_without_changing_index(self):
        self.stage_data('{"health": 100}')
        result = self.check("commit")
        self.assertEqual(result.returncode, 0, result.stderr)
        status = subprocess.check_output([GIT, "status", "--porcelain"], cwd=self.root, text=True, env=self.env)
        self.assertIn("A  assets/data/enemy.json", status)

    def test_staged_blob_is_checked_when_working_copy_was_repaired(self):
        data = self.stage_data('{"health": broken}')
        data.write_text('{"health": 100}', encoding="utf-8")
        result = self.check("commit")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("not valid JSON", result.stderr)

    def test_working_copy_does_not_replace_valid_staged_blob(self):
        data = self.stage_data('{"health": 100}')
        data.write_text('{"health": broken}', encoding="utf-8")
        result = self.check("commit")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_push_runs_validator_without_pushing(self):
        hook = self.root / ".claude/hooks/validate-push.sh"
        with hook.open("w", encoding="utf-8", newline="\n") as output:
            output.write('''#!/bin/bash
input=$(cat)
case "$input" in
  *'"command": "git push"'*) echo 'Validator called'; exit 7 ;;
  *) exit 8 ;;
esac
''')
        result = self.check("push")
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertIn("Validator called", result.stdout)

    def test_missing_hook_is_a_clear_failure(self):
        (self.root / ".claude/hooks/validate-commit.sh").unlink()
        result = self.check("commit")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Missing hook", result.stderr)

    @unittest.skipUnless(os.name == "nt", "Windows Git Bash fallback")
    def test_windows_bridge_finds_git_bash_and_python_without_bash_on_path(self):
        self.stage_data('{"health": 100}')
        env = self.env.copy()
        # Git's cmd directory has git.exe and no bash.exe. Neither a Git Bash
        # shell nor a PATH change in the calling process should be required.
        env["PATH"] = str(Path(GIT).parent)
        self.assertIsNone(shutil.which("bash", path=env["PATH"]))
        self.assertIsNone(shutil.which("python", path=env["PATH"]))
        result = self.check("commit", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("validation only; no commit", result.stdout)


if __name__ == "__main__":
    unittest.main()
