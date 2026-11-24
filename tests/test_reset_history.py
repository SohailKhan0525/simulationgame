"""Exercise the destructive migration against disposable local remotes only."""

import pathlib
import shutil
import subprocess
import tempfile
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1]


def git(path, *args):
    return subprocess.check_output(
        ["git", "-C", str(path), *args], text=True, stderr=subprocess.DEVNULL
    ).strip()


class ResetHistoryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="reset-history-test-", dir=SOURCE.parent)
        self.addCleanup(self.temp.cleanup)
        self.base = pathlib.Path(self.temp.name)
        self.remote = self.base / "origin.git"
        self.work = self.base / "work"
        subprocess.run(["git", "init", "--bare", str(self.remote)], check=True, capture_output=True)
        subprocess.run(["git", "init", "-b", "main", str(self.work)], check=True, capture_output=True)
        git(self.work, "config", "user.name", "Migration test")
        git(self.work, "config", "user.email", "test@example.invalid")
        git(self.work, "remote", "add", "origin", str(self.remote))
        (self.work / "original.txt").write_text("Old content\n")
        git(self.work, "add", ".")
        git(self.work, "commit", "-m", "Original history")
        git(self.work, "branch", "old-branch")
        git(self.work, "tag", "old-tag")
        git(self.work, "push", "origin", "main", "old-branch", "old-tag")
        original_refs = git(self.work, "ls-remote", "--refs", "--heads", "--tags", "origin")
        (self.work / "tools").mkdir()
        shutil.copyfile(SOURCE / "tools/reset-history.sh", self.work / "tools/reset-history.sh")
        (self.work / "tools/history-reset-refs.tsv").write_text(original_refs + "\n")
        (self.work / "original.txt").unlink()
        (self.work / "game.txt").write_text("Reviewed game source\n")
        git(self.work, "add", "-A")
        git(self.work, "commit", "-m", "Reviewed replacement")
        git(self.work, "push", "origin", "main")
        self.expected = git(self.work, "rev-parse", "HEAD")
        self.tree = git(self.work, "rev-parse", "HEAD^{tree}")

    def run_reset(self):
        return subprocess.run(
            ["bash", "tools/reset-history.sh", self.expected],
            cwd=self.work, text=True, capture_output=True,
        )

    def refs(self):
        return git(self.work, "ls-remote", "--refs", "--heads", "--tags", "origin")

    def assert_refusal_preserves_remote(self):
        before = self.refs()
        result = self.run_reset()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("History reset refused:", result.stderr)
        self.assertEqual(before, self.refs())

    def test_success_preserves_exact_tree_and_leaves_one_parentless_main(self):
        result = self.run_reset()
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = self.refs().splitlines()
        self.assertEqual(len(lines), 1)
        root, ref = lines[0].split()
        self.assertEqual(ref, "refs/heads/main")
        self.assertNotEqual(root, self.expected)
        self.assertEqual(git(self.remote, "rev-list", "--count", root), "1")
        self.assertEqual(git(self.remote, "rev-parse", root + "^{tree}"), self.tree)
        self.assertEqual(
            git(self.remote, "show", root + ":tools/history-reset-refs.tsv"),
            (self.work / "tools/history-reset-refs.tsv").read_text().strip(),
        )
        # A completed migration cannot run again with the original expectation.
        self.assert_refusal_preserves_remote()

    def test_changed_old_branch_aborts_everything(self):
        git(self.work, "push", "origin", "HEAD:refs/heads/old-branch")
        self.assert_refusal_preserves_remote()

    def test_changed_old_tag_aborts_everything(self):
        git(self.work, "push", "--force", "origin", "HEAD:refs/tags/old-tag")
        self.assert_refusal_preserves_remote()

    def test_missing_inventoried_branch_aborts_everything(self):
        git(self.work, "push", "origin", ":refs/heads/old-branch")
        self.assert_refusal_preserves_remote()

    def test_unknown_branch_aborts_everything(self):
        git(self.work, "push", "origin", "HEAD:refs/heads/new-work")
        self.assert_refusal_preserves_remote()

    def test_unknown_tag_aborts_everything(self):
        git(self.work, "push", "origin", "HEAD:refs/tags/new-release")
        self.assert_refusal_preserves_remote()

    def test_changed_main_aborts_everything(self):
        git(self.work, "update-ref", "refs/heads/later", self.expected)
        git(self.work, "commit", "--allow-empty", "-m", "Someone else updated main")
        git(self.work, "push", "origin", "main")
        git(self.work, "checkout", "--detach", self.expected)
        self.assert_refusal_preserves_remote()

    def test_dirty_checkout_aborts_everything(self):
        (self.work / "game.txt").write_text("Unreviewed change\n")
        self.assert_refusal_preserves_remote()


if __name__ == "__main__":
    unittest.main()
