# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "pytest",
# ]
# ///
"""Tests for the gh-readonly PreToolUse hook. Run with: uv run test_gh_readonly.py"""

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

HOOK_PATH = Path(__file__).parent / "gh-readonly.py"

spec = importlib.util.spec_from_file_location("gh_readonly", HOOK_PATH)
assert spec is not None and spec.loader is not None
gh_readonly = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gh_readonly)


ALLOWED = [
    "gh api repos/openedx/openedx-platform/actions/jobs/123/logs",
    "gh api repos/o/r/pulls/1/comments --paginate 2>&1 | jq '.[].body'",
    "gh api 'repos/o/r/actions/runs?status=failure&per_page=5' --jq '.workflow_runs[] | .id'",
    'echo "---"; gh api repos/o/r/commits/abc/check-runs | head -50',
    "cd /tmp && gh api repos/o/r",
    "gh api repos/o/r 2>/dev/null | grep -i name | sort | uniq -c",
    "gh api repos/o/r -X GET -f q=test",
    "git log --oneline -5 && gh api repos/o/r/pulls/1",
    "gh pr checks 123 && gh api repos/o/r/commits/abc/check-runs",
]

REJECTED = [
    # mutations
    "gh api repos/o/r/pulls -X PATCH -f body=x",
    "gh api repos/o/r -X DELETE",
    "gh api repos/o/r --method=POST",
    "gh api repos/o/r/pulls/1/reviews -f event=APPROVE",  # -f defaults to POST
    "gh api repos/o/r --input /tmp/x.json",
    "gh api graphql -f query='query { viewer { login } }'",
    # unsafe companions in compound commands
    "gh api repos/o/r && rm -rf /tmp/x",
    "gh pr edit 1 --body x && gh api repos/o/r",
    "git -c core.pager='touch /tmp/pwned' log; gh api repos/o/r",
    "GH_TOKEN=x gh api repos/o/r",
    # shell constructs the hook can't reason about
    "gh api repos/o/r > /tmp/out.json",
    "gh api repos/o/r | tee /tmp/out.json",
    'echo "$(rm -rf /tmp/x)"; gh api repos/o/r',
    "gh api repos/o/r `rm x`",
    "gh api repos/o/r\nrm -rf /tmp/x",
    "gh api repos/o/r | sort -o /etc/passwd",
    "gh api repos/o/r 'unbalanced",
]


@pytest.mark.parametrize("command", ALLOWED)
def test_allowed(command):
    assert gh_readonly.command_is_safe(command)


@pytest.mark.parametrize("command", REJECTED)
def test_rejected(command):
    assert not gh_readonly.command_is_safe(command)


def run_hook(payload):
    return subprocess.run(
        [sys.executable, str(HOOK_PATH)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )


def test_end_to_end_allow():
    result = run_hook({"tool_name": "Bash", "tool_input": {"command": ALLOWED[0]}})
    assert result.returncode == 0
    decision = json.loads(result.stdout)["hookSpecificOutput"]
    assert decision["hookEventName"] == "PreToolUse"
    assert decision["permissionDecision"] == "allow"


def test_end_to_end_silent_on_mutation():
    result = run_hook({"tool_name": "Bash", "tool_input": {"command": REJECTED[0]}})
    assert result.returncode == 0
    assert result.stdout.strip() == ""


def test_silent_on_commands_without_gh_api():
    for command in ("git status", "rm -rf /"):
        result = run_hook({"tool_name": "Bash", "tool_input": {"command": command}})
        assert result.returncode == 0
        assert result.stdout.strip() == ""


def test_silent_on_non_bash_tool():
    result = run_hook({"tool_name": "Edit", "tool_input": {"file_path": "gh api x"}})
    assert result.returncode == 0
    assert result.stdout.strip() == ""


def test_silent_on_garbage_input():
    result = subprocess.run(
        [sys.executable, str(HOOK_PATH)], input="not json", capture_output=True, text=True
    )
    assert result.returncode == 0
    assert result.stdout.strip() == ""


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
