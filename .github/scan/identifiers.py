#!/usr/bin/env python3
"""Identifiers that must never be committed, and the one place that defines them.

ADR-0005 is the reason: this repository is public, and anything committed to it
is copied by forks, mirrors and archives that a later commit cannot reach. So
deployment-specific values are resolved when a plan runs, and this scanner is
what keeps them from coming back.

  identifiers.py [FILE ...]           scan files; with none, every tracked file
  identifiers.py --history [--every-line] [REV ...]
                                      scan `git log -p` of REV (default --all):
                                      what each commit adds, its message and
                                      its author; --every-line also reads the
                                      removed and unchanged lines of each patch
  identifiers.py --redact             copy stdin to stdout with each match
                                      replaced by <kind>, for CI logs
  identifiers.py --identity           scan the author and committer that the
                                      next commit will carry, for the gate:
                                      a commit publishes them with its files
  identifiers.py --list [REV ...]     print kind and value of each distinct
                                      match in the history; for rewriting it
                                      on a laptop, never in CI

Findings are reported as file:count or commit:count, never as the matched text,
so that a finding does not leak into the CI log that reports it. Exit status is
1 when something matches.

The patterns are those of the scanner in Agent Cost Control, a sibling project,
plus four that only this repository needs: storage endpoints, storage account
names derived from a subscription id, GitHub's numeric account and repository
ids, and the cluster policy ids that a plan prints when it refreshes state.
Exceptions live in allowed.txt next to this file, each with its reason.

Standard library only, Python 3.9 or later: pre-commit and CI run it as is.
"""

from __future__ import annotations

import fnmatch
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ALLOWLIST = Path(__file__).with_name("allowed.txt")

# (kind, regex). When the regex has a group named v, the value is that group;
# otherwise it is the whole match. Order matters only for ties: overlapping
# matches resolve to the longest, so a whole host wins over the id inside it.
PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    (kind, re.compile(rx))
    for kind, rx in [
        # Azure workspace host, with or without its domain
        ("workspace-host", r"adb-[0-9]{6,}(?:\.[0-9]+)?(?:\.azuredatabricks\.net)?"),
        # any other Azure Databricks host: a Lakebase endpoint, a regional URL
        ("databricks-host", r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.azuredatabricks\.net"),
        # an AWS or GCP workspace host
        ("databricks-host", r"[A-Za-z0-9-]+\.(?:cloud|gcp)\.databricks\.com"),
        # a Databricks App host
        ("app-host", r"[A-Za-z0-9.-]*databricksapps\.com"),
        # a bare workspace id: 15 to 19 digits that are not part of a longer token
        ("workspace-id", r"(?<![0-9A-Za-z._-])[0-9]{15,19}(?![0-9A-Za-z_-])"),
        # any GUID: subscription, tenant, account, client, principal
        ("uuid", r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"),
        # a Databricks personal access token
        ("token", r"dapi[0-9a-f]{20,}"),
        # a Databricks OAuth secret
        ("token", r"dose[0-9a-f]{20,}"),
        # a JWT: an OAuth or OIDC token
        ("token", r"eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}"),
        # an email address; an abfss URL puts container@account in front of the
        # storage domain, which is not an address, and storage-host reports it
        ("email", r"[A-Za-z0-9._%+-]+@(?![a-z0-9]{3,24}\.(?:blob|dfs|file|queue|table|web)\.core\.windows\.net)"
                  r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"),
        # an Azure Storage endpoint: the state store, a catalog account
        ("storage-host", r"[a-z0-9]{3,24}\.(?:blob|dfs|file|queue|table|web)\.core\.windows\.net"),
        # a storage account name this repository derives from a subscription id:
        # state-store.sh and naming.tf both end it in eight hex digits of a hash
        ("storage-account", r"(?<![A-Za-z0-9])st(?:tfstate|dbxlab)[a-z0-9]*?[0-9a-f]{8}(?![A-Za-z0-9])"),
        # a numeric id assigned to a key named *_id: GitHub's owner and repository ids
        ("numeric-id", r"[A-Za-z0-9_]*_id[\"']?[ \t]*[=:][ \t]*[\"']?(?P<v>[0-9]{6,})(?![0-9])"),
        # an OIDC subject in GitHub's immutable form, which embeds both numeric ids
        ("oidc-subject", r"repo:[A-Za-z0-9_.-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+"),
        # a cluster policy id: sixteen uppercase hex digits, at least one of them a
        # letter, so that a bare sixteen-digit workspace id stays a workspace-id
        ("policy-id", r"(?<![0-9A-Za-z])(?=[0-9A-F]{0,15}[A-F])[0-9A-F]{16}(?![0-9A-Za-z])"),
    ]
]


def load_allowlist(path: Path = ALLOWLIST) -> tuple[list[re.Pattern[str]], list[tuple[str, re.Pattern[str]]]]:
    """allow <regex>: a value that matches it entirely is not a finding.
    ignore <glob> <regex>: in files whose path matches glob, text matching regex
    is blanked before scanning."""
    allow: list[re.Pattern[str]] = []
    ignore: list[tuple[str, re.Pattern[str]]] = []
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("  #", 1)[0].strip()
        if not line or line.startswith("#"):
            continue
        verb, _, rest = line.partition(" ")
        if verb == "allow" and rest:
            allow.append(re.compile(rest.strip(), re.IGNORECASE))
        elif verb == "ignore" and " " in rest.strip():
            glob, _, rx = rest.strip().partition(" ")
            ignore.append((glob, re.compile(rx.strip())))
        else:
            raise SystemExit(f"{path}:{number}: expected 'allow <regex>' or 'ignore <glob> <regex>'")
    return allow, ignore


ALLOW, IGNORE = load_allowlist()


def ignored_for(path: str) -> list[re.Pattern[str]]:
    return [rx for glob, rx in IGNORE if fnmatch.fnmatch(path, glob) or fnmatch.fnmatch("/" + path, glob)]


def matches(line: str, ignore: list[re.Pattern[str]] | None = None) -> list[tuple[int, int, str, str]]:
    """Non-overlapping (start, end, kind, value) of every finding in a line."""
    for rx in ignore or []:
        line = rx.sub(lambda m: " " * len(m.group(0)), line)
    spans = []
    for kind, rx in PATTERNS:
        for m in rx.finditer(line):
            start, end = m.span("v") if "v" in rx.groupindex else m.span()
            value = line[start:end]
            if not any(a.fullmatch(value) for a in ALLOW):
                spans.append((start, end, kind, value))
    spans.sort(key=lambda s: (s[0], s[0] - s[1]))
    kept, last = [], -1
    for span in spans:
        if span[0] >= last:
            kept.append(span)
            last = span[1]
    return kept


def redact(line: str) -> str:
    for start, end, kind, _ in reversed(matches(line)):
        line = f"{line[:start]}<{kind}>{line[end:]}"
    return line


def read_text(path: str) -> str | None:
    try:
        data = Path(path).read_bytes()
    except OSError:
        return None
    if b"\0" in data[:8192]:
        return None  # binary: nothing in this repository is, and a lock file is not
    return data.decode("utf-8", errors="replace")


def scan_files(paths: list[str]) -> int:
    if not paths:
        out = subprocess.run(["git", "ls-files", "-z"], check=True, capture_output=True).stdout
        paths = [p for p in out.decode().split("\0") if p]
    found: Counter[str] = Counter()
    read = 0
    for path in paths:
        text = read_text(path)
        if text is None:
            continue
        read += 1
        ignore = ignored_for(path)
        for line in text.splitlines():
            found[path] += len(matches(line, ignore))
    return report(found, read, "files")


def history(revs: list[str], every_line: bool = False):
    """(commit, path, line) for each line of `git log -p` that a commit publishes:
    its header, its message, the paths it touches and the lines it adds.

    A removed line was added by an earlier commit, where it is read, and an
    unchanged one is still there: reading only additions covers a whole history
    exactly once, and it keeps a pull request that removes an identifier from
    failing for the identifier it removes. every_line reads them all."""
    cmd = ["git", "log", "-p", "--no-color", "--no-ext-diff",
           "--format=commit %h%nAuthor: %an <%ae>%nCommit: %cn <%ce>%n%n%B"] + (revs or ["--all"])
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    commit, path, in_patch = "", "", False
    assert proc.stdout is not None
    with proc.stdout:
        for raw in proc.stdout:
            line = raw.decode("utf-8", errors="replace").rstrip("\n")
            if line.startswith("commit ") and len(line.split()) == 2:
                commit, path, in_patch = line.split()[1], "", False
            elif line.startswith("diff --git "):
                path, in_patch = line.rsplit(" b/", 1)[-1], True
            elif in_patch and not every_line and not line.startswith(("+", "rename to ", "copy to ")):
                continue
            yield commit, path, line
    if proc.wait() != 0:
        raise SystemExit(f"git log exited {proc.returncode}")


def scan_history(revs: list[str]) -> int:
    every_line = "--every-line" in revs
    revs = [r for r in revs if r != "--every-line"]
    found: Counter[str] = Counter()
    commits = set()
    for commit, path, line in history(revs, every_line):
        commits.add(commit)
        found[commit] += len(matches(line, ignored_for(path) if path else None))
    return report(found, len(commits), "commits")


IDENT_DATE = re.compile(r" [0-9]+ [-+][0-9]{4}$")


def scan_identity() -> int:
    """The author and committer the next commit will carry, read with git var
    before the commit exists. git commit exports --author, GIT_AUTHOR_* and
    -c user.* to its hooks, so git var reads exactly what the commit will
    publish, which is also what a fresh clone's global configuration supplies."""
    found: Counter[str] = Counter()
    for var in ("GIT_AUTHOR_IDENT", "GIT_COMMITTER_IDENT"):
        out = subprocess.run(["git", "var", var], capture_output=True, text=True)
        if out.returncode == 0:
            found[var] += len(matches(IDENT_DATE.sub("", out.stdout.strip())))
    if not found:
        print("identifiers: no identity configured, and git commit refuses without one")
        return 0
    status = report(found, len(found), "identities")
    if status:
        print("set user.email in this clone to the GitHub noreply address (ADR-0005)")
    return status


def list_history(revs: list[str]) -> int:
    seen: dict[str, str] = {}
    for _, path, line in history(revs, every_line=True):
        for _, _, kind, value in matches(line, ignored_for(path) if path else None):
            seen.setdefault(value, kind)
    for value, kind in sorted(seen.items(), key=lambda kv: (kv[1], kv[0])):
        print(f"{kind}\t{value}")
    return 0


def report(found: Counter[str], read: int, what: str) -> int:
    hits = {k: n for k, n in found.items() if n}
    if hits:
        print("::error::text that looks like an identifier, a host, a token or an email (where:count)")
        for where in sorted(hits):
            print(f"{where}:{hits[where]}")
        return 1
    print(f"identifiers: nothing found in {read} {what}")
    return 0


def main(argv: list[str]) -> int:
    if argv[:1] == ["--redact"]:
        # Die of SIGPIPE like any filter when the reader goes away, so pipefail
        # reports it, instead of a traceback in the middle of a log.
        import signal
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
        for line in sys.stdin:
            sys.stdout.write(redact(line.rstrip("\n")) + "\n")
            sys.stdout.flush()
        return 0
    if argv[:1] == ["--history"]:
        return scan_history(argv[1:])
    if argv[:1] == ["--list"]:
        return list_history(argv[1:])
    if argv[:1] == ["--identity"]:
        return scan_identity()
    return scan_files(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
