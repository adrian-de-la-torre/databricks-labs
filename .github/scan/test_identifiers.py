"""What identifiers.py promises, proved without a network.

Every sample is assembled at run time from fragments. A literal sample would be
a finding of the scanner it tests, since the gate scans this file too.

  python3 -m unittest discover -s .github/scan -p "test_*.py"
"""

from __future__ import annotations

import contextlib
import io
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import identifiers as scan  # noqa: E402

AT = "@"
GUID = "-".join(["3f2b9c1d", "7a4e", "4c2b", "9d1e", "5b6a7c8d9e0f"])
DIGITS16 = "8" * 16
AZURE = ".azuredatabricks" + ".net"


def kinds(text: str, path: str = "x.tf") -> list[str]:
    return [kind for _, _, kind, _ in scan.matches(text, scan.ignored_for(path))]


class EachPatternFires(unittest.TestCase):
    """One sample per kind. A pattern that matches nothing passes every gate."""

    def test_workspace_host(self):
        self.assertEqual(kinds(f'host = "https://adb-{DIGITS16}.7{AZURE}"'), ["workspace-host"])

    def test_other_databricks_hosts(self):
        self.assertEqual(kinds("instance-abc." + "database.azuredatabricks" + ".net"), ["databricks-host"])
        self.assertEqual(kinds("dbc-1a2b3c4d" + ".cloud.databricks" + ".com"), ["databricks-host"])

    def test_app_host(self):
        self.assertEqual(kinds("https://my-app-123.aws." + "databricksapps" + ".com"), ["app-host"])

    def test_bare_workspace_id(self):
        self.assertEqual(kinds(f'workspace = "{DIGITS16}"'), ["workspace-id"])

    def test_uuid_in_either_case(self):
        self.assertEqual(kinds(f"/subscriptions/{GUID}/resourceGroups/rg"), ["uuid"])
        self.assertEqual(kinds(GUID.upper()), ["uuid"])

    def test_tokens(self):
        self.assertEqual(kinds("dapi" + "0a" * 16), ["token"])
        self.assertEqual(kinds("dose" + "0a" * 16), ["token"])
        self.assertEqual(kinds("eyJ" + "a" * 10 + ".eyJ" + "b" * 10), ["token"])

    def test_email(self):
        self.assertEqual(kinds("someone" + AT + "example.com"), ["email"])

    def test_storage_endpoint_and_derived_names(self):
        catalog_account = "stdbxlabdevneu" + "0a1b2c3d"
        self.assertEqual(kinds(f"abfss://unity{AT}{catalog_account}" + ".dfs.core.windows" + ".net/"), ["storage-host"])
        self.assertEqual(kinds('storage_account_name = "sttfstate' + "0a1b2c3d" + '"'), ["storage-account"])
        self.assertEqual(kinds("stdbxlabtestneu" + "9f8e7d6c"), ["storage-account"])

    def test_github_numeric_ids(self):
        self.assertEqual(kinds("github_owner_id = " + "1234567"), ["numeric-id"])
        self.assertEqual(kinds('"repository_id": ' + "98765432"), ["numeric-id"])
        self.assertEqual(kinds("repo:someone" + AT + "1234567/labs" + AT + "7654321:pull_request"), ["oidc-subject"])


class WhatIsNotAnIdentifier(unittest.TestCase):
    """Names, regions and ranges are what the env files are allowed to hold."""

    def test_names_regions_and_ranges(self):
        for text in [
            'address_space = "10.11.0.0/24"',
            'location = "northeurope"',
            'resource_group_name = "rg-terraform-state"',
            'name = "rg-dbxlab-dev-neu"',
            'key = "platform/dev/northeurope.tfstate"',
            'storage_credential_name = "sc-dbxlab-dev"',
            "repo:<owner>" + AT + "<owner_id>/<repo>" + AT + "<repo_id>:<context>",
            "AADSTS700213",
            'max_clusters_per_user = 2',
        ]:
            with self.subTest(text=text):
                self.assertEqual(kinds(text), [])


class Allowlist(unittest.TestCase):
    def test_values_that_belong_to_no_one(self):
        for text in [
            'host = "https://accounts.azuredatabricks.net"',
            '"acdd72a7-3385-48ef-bd42-f606fba81ae7", # Reader',
            '"ba92f5b4-2d11-453d-a403-e96b0029c9fe", # Storage Blob Data Contributor',
            "persona" + AT + "example.invalid",
            "Author: someone <1234567+someone" + AT + "users.noreply.github.com>",
            "Author: dependabot[bot] <49699333+dependabot[bot]" + AT + "users.noreply.github.com>",
            "Commit: GitHub <noreply" + AT + "github.com>",
            "Signed-off-by: dependabot[bot] <support" + AT + "github.com>",
        ]:
            with self.subTest(text=text):
                self.assertEqual(kinds(text), [])

    def test_a_guid_that_is_not_a_builtin_role_is_still_found(self):
        self.assertEqual(kinds(f'"{GUID}", # Reader'), ["uuid"])

    def test_checksums_are_blanked_only_in_lock_files(self):
        # A checksum that happens to contain sixteen digits between two '/'.
        line = '    "h1:Ab/' + DIGITS16 + '/cdEFghIJklMNopQRstUVwxYZ01234567=",'
        self.assertEqual(kinds(line, "infra/stacks/platform/.terraform.lock.hcl"), [])
        self.assertEqual(kinds(line, "infra/stacks/platform/main.workspace.tf"), ["workspace-id"])


class Redaction(unittest.TestCase):
    def test_a_host_is_one_redaction_not_a_host_around_an_id(self):
        line = f"[id=/subscriptions/{GUID}/x] https://adb-{DIGITS16}.7{AZURE}"
        self.assertEqual(scan.redact(line), "[id=/subscriptions/<uuid>/x] https://<workspace-host>")

    def test_only_the_number_of_an_id_assignment_is_redacted(self):
        self.assertEqual(scan.redact("github_repository_id = " + "1234567"), "github_repository_id = <numeric-id>")

    def test_allowed_values_survive(self):
        line = 'host = "https://accounts.azuredatabricks.net"'
        self.assertEqual(scan.redact(line), line)


class Reporting(unittest.TestCase):
    """A finding is reported where it is, never what it is: the CI log is public."""

    def setUp(self):
        # git exports GIT_INDEX_FILE, and sometimes GIT_DIR, to the hooks it
        # runs, and this file runs as one. Inherited, they point a fixture's
        # `git add` at the index of the commit being made instead of its own
        # repository, which is how these tests once staged their fixtures into
        # it. Every git below, the tests' and the scanner's, runs without them.
        clean = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        patcher = mock.patch.dict(os.environ, clean, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)

    def run_main(self, *argv: str) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = scan.main(list(argv))
        return status, out.getvalue()

    def test_files_report_counts_not_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            leaky = Path(tmp, "leaky.tfvars")
            leaky.write_text(f'workspace_id = "{DIGITS16}"\nsubscription = "{GUID}"\n')
            clean = Path(tmp, "clean.tfvars")
            clean.write_text('location = "northeurope"\n')
            status, out = self.run_main(str(leaky), str(clean))
        self.assertEqual(status, 1)
        self.assertIn("leaky.tfvars:2", out)
        self.assertNotIn("clean.tfvars", out)
        self.assertNotIn(DIGITS16, out)
        self.assertNotIn(GUID, out)

    def test_a_clean_file_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            clean = Path(tmp, "clean.tfvars")
            clean.write_text('environment = "dev"\n')
            status, out = self.run_main(str(clean))
        self.assertEqual(status, 0)
        self.assertIn("nothing found in 1 files", out)

    def test_history_covers_messages_and_authors(self):
        with tempfile.TemporaryDirectory() as tmp:
            git = ["git", "-C", tmp, "-c", "user.name=t", "-c", "user.email=t" + AT + "example.invalid",
                   "-c", "commit.gpgsign=false"]
            subprocess.run(["git", "init", "-q", tmp], check=True)
            Path(tmp, "a.txt").write_text("nothing here\n")
            subprocess.run(git + ["add", "a.txt"], check=True)
            subprocess.run(git + ["commit", "-q", "-m", "clean"], check=True)
            subprocess.run(git + ["commit", "-q", "--allow-empty", "-m", f"subscription {GUID}"], check=True)
            author = ["--author", "Someone <someone" + AT + "example.com>"]
            subprocess.run(git + ["commit", "-q", "--allow-empty", "-m", "clean too"] + author, check=True)
            cwd = Path.cwd()
            try:
                os.chdir(tmp)
                status, out = self.run_main("--history")
            finally:
                os.chdir(cwd)
        self.assertEqual(status, 1)
        self.assertEqual(len([line for line in out.splitlines() if line.endswith(":1")]), 2)
        self.assertNotIn(GUID, out)
        self.assertNotIn("someone" + AT, out)

    def test_history_reads_what_a_commit_adds_not_what_it_removes(self):
        """The pull request that removes an id must not fail for it; the commit that added it must."""
        with tempfile.TemporaryDirectory() as tmp:
            git = ["git", "-C", tmp, "-c", "user.name=t", "-c", "user.email=t" + AT + "example.invalid",
                   "-c", "commit.gpgsign=false"]
            subprocess.run(["git", "init", "-q", tmp], check=True)
            env = Path(tmp, "dev.tfvars")
            env.write_text(f'workspace_id = "{DIGITS16}"\n')
            subprocess.run(git + ["add", "dev.tfvars"], check=True)
            subprocess.run(git + ["commit", "-q", "-m", "adds an id"], check=True)
            env.write_text('location = "northeurope"\n')
            subprocess.run(git + ["commit", "-q", "-am", "removes it"], check=True)
            cwd = Path.cwd()
            try:
                os.chdir(tmp)
                removal, _ = self.run_main("--history", "HEAD~1..HEAD")
                every, _ = self.run_main("--history", "--every-line", "HEAD~1..HEAD")
                whole, out = self.run_main("--history")
            finally:
                os.chdir(cwd)
        self.assertEqual(removal, 0)
        self.assertEqual(every, 1)
        self.assertEqual(whole, 1)
        self.assertEqual(len([line for line in out.splitlines() if line.endswith(":1")]), 1)


if __name__ == "__main__":
    unittest.main()
