#!/usr/bin/env python3
"""Run a shared Claude validator explicitly, without committing or pushing.

Requires Git and Bash (Git Bash on Windows). Preserves the hook's exit code.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def find_bash(git, explicit=None):
    """Find Git Bash on Windows even when only Git's cmd folder is on PATH."""
    if explicit:
        candidate = Path(explicit).expanduser()
        return str(candidate.resolve()) if candidate.is_file() else shutil.which(explicit)
    if os.name == "nt":
        git_root = Path(git).parent.parent
        roots = [git_root]
        for key in ("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)"):
            if os.environ.get(key):
                roots.append(Path(os.environ[key]) / "Git")
        if os.environ.get("LOCALAPPDATA"):
            roots.append(Path(os.environ["LOCALAPPDATA"]) / "Programs/Git")
        for root in roots:
            for relative in ("bin/bash.exe", "usr/bin/bash.exe"):
                candidate = root / relative
                if candidate.is_file():
                    return str(candidate)
    return shutil.which("bash")


def validator_environment(bash, git):
    """Supply this interpreter and Bash utilities to the child process only."""
    env = os.environ.copy()
    bash_path = Path(bash)
    directories = [Path(sys.executable).parent, Path(git).parent, bash_path.parent]
    utilities = bash_path.parent.parent / "usr/bin"
    if utilities.is_dir():
        directories.append(utilities)
    env["PATH"] = os.pathsep.join([*(str(path) for path in directories), env.get("PATH", "")])
    return env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("commit", "push"))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1],
                        help="Project root (defaults to the script's repository)")
    parser.add_argument("--bash", default=os.environ.get("STUDIO_BASH"),
                        help="Bash executable override (or STUDIO_BASH); otherwise auto-detected")
    args = parser.parse_args()
    root = args.root.resolve()
    hook = Path(".claude/hooks") / f"validate-{args.kind}.sh"
    if not (root / hook).is_file():
        print(f"Missing hook: {hook}", file=sys.stderr)
        return 2
    git = shutil.which("git")
    bash = find_bash(git, args.bash) if git else None
    if not bash or not git:
        print("Git and Bash are required. On Windows, use Git Bash.", file=sys.stderr)
        return 2
    env = validator_environment(bash, git)
    if subprocess.run([git, "rev-parse", "--git-dir"], cwd=root, env=env,
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        print(f"Not a Git repository: {root}", file=sys.stderr)
        return 2
    payload = {"tool_name": "Bash", "tool_input": {"command": f"git {args.kind}"}}
    print(f"Running {hook.as_posix()} (validation only; no {args.kind}).", flush=True)
    try:
        return subprocess.run(
            [bash, hook.as_posix()], cwd=root, env=env, input=json.dumps(payload),
            text=True, timeout=30,
        ).returncode
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"Studio check failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
