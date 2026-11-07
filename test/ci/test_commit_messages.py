"""Tests for the commit message contract used by CI and local Git."""

import sys
import subprocess
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts" / "ci"))
from check_commit_messages import validate  # noqa: E402


class CommitMessageTests(unittest.TestCase):
    def test_accepts_optional_scope_body_and_breaking_footer(self):
        for message in (
            "docs(linux): clarify required build dependencies\n",
            "chore: refresh repository metadata",
            "test(library): cover missing folders during rescan",
            "fix(playback): preserve subtitle selection after seeking\n\n"
            "Seeking reset the selected track. Restore it after source reload.\n",
            "refactor(playback): centralize media state transitions\n\n"
            "Playback and source switching used separate transition logic.\n\n"
            "Route both through the shared controller.\n",
            "feat(library)!: change index format\n\n"
            "BREAKING CHANGE: Rebuild existing library indexes.\n",
            "feat(vpfl_desktop_linux): support file selection",
            "feat: change library index format\n\n"
            "BREAKING CHANGE: Rebuild existing library indexes.",
        ):
            with self.subTest(message=message):
                self.assertEqual([], validate(message))

    def test_rejects_malformed_messages(self):
        cases = {
            "": "message is empty",
            "Update files": "heading must use",
            "doc(linux): clarify packages": "heading must use",
            "fix(): clarify packages": "heading must use",
            "fix(linux): ": "heading must use",
            "fix(linux): clarify packages ": "heading must use",
            "fix(linux): clarify packages\nBody without a blank separator.": "blank line",
            "fix(linux): " + "x" * 70: "72 characters",
        }
        for message, expected_error in cases.items():
            with self.subTest(message=message):
                self.assertTrue(
                    any(expected_error in error for error in validate(message))
                )

    def test_range_checks_all_new_commits_and_ignores_merge_messages(self):
        script = Path(__file__).resolve().parents[2] / "scripts" / "ci" / "check_commit_messages.py"
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.run(
                    ("git", "-c", "core.hooksPath=/dev/null", *args),
                    cwd=directory,
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout.strip()

            git("init", "-q", "-b", "main")
            git("config", "user.name", "VPFL Test")
            git("config", "user.email", "vpfl@example.invalid")
            git("commit", "--allow-empty", "-qm", "historical heading")
            git("switch", "-qc", "feature")
            git("commit", "--allow-empty", "-qm", "feat(library): index selected folders")
            git("switch", "-q", "main")
            git("commit", "--allow-empty", "-qm", "another historical heading")
            git("switch", "-q", "feature")
            git("merge", "-q", "--no-ff", "main", "-m", "Merge main")
            git("commit", "--allow-empty", "-qm", "fix: retain selection")

            command = (sys.executable, str(script), "--range", "main..HEAD")
            result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("Validated 2 commit message(s).", result.stdout)

            git("commit", "--allow-empty", "-qm", "invalid heading")
            invalid_commit = git("rev-parse", "--short=12", "HEAD")
            result = subprocess.run(command, cwd=directory, capture_output=True, text=True)
            self.assertEqual(1, result.returncode)
            self.assertIn(invalid_commit, result.stderr)
            self.assertIn("heading must use", result.stderr)


if __name__ == "__main__":
    unittest.main()
