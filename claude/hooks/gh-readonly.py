#!/usr/bin/env python3
"""PreToolUse hook: auto-approve Bash commands whose every segment is read-only,
with method-aware checks for `gh api`. Silent (exit 0, no output) on anything it
can't prove safe, so the normal permission flow takes over. Never denies."""

import json
import shlex
import sys

SEPARATORS = {"|", ";", "&&", "||"}

SAFE_UTILS = {
    "jq", "head", "tail", "grep", "sort", "uniq", "wc", "cut", "tr",
    "cat", "echo", "printf", "ls", "cd", "date", "which", "column",
}

GIT_RO_SUBCOMMANDS = {
    "status", "log", "diff", "show", "blame", "rev-parse", "rev-list",
    "ls-files", "ls-tree", "ls-remote", "cat-file", "merge-base",
    "describe", "shortlog", "for-each-ref",
}

GH_RO_SUBCOMMANDS = {
    ("pr", "view"), ("pr", "list"), ("pr", "diff"), ("pr", "checks"), ("pr", "status"),
    ("issue", "view"), ("issue", "list"), ("issue", "status"),
    ("run", "view"), ("run", "list"),
    ("repo", "view"), ("repo", "list"),
    ("release", "view"), ("release", "list"),
    ("workflow", "view"), ("workflow", "list"),
    ("label", "list"),
    ("auth", "status"),
}

# gh api flags that consume the following token as their value
GH_API_VALUE_FLAGS = {
    "-X", "--method", "-f", "-F", "--field", "--raw-field", "--input",
    "--jq", "-q", "-H", "--header", "--hostname", "-t", "--template",
    "--cache", "-p", "--preview",
}


def tokenize(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    return list(lex)


def strip_safe_redirects(tokens):
    """Remove the harmless stderr redirects `2>&1` and `2>/dev/null`."""
    out = []
    i = 0
    while i < len(tokens):
        if tokens[i : i + 3] == ["2", ">&", "1"] or tokens[i : i + 3] == ["2", ">", "/dev/null"]:
            i += 3
        else:
            out.append(tokens[i])
            i += 1
    return out


def split_segments(tokens):
    segments = []
    current = []
    for tok in tokens:
        if tok in SEPARATORS:
            if current:
                segments.append(current)
            current = []
        else:
            current.append(tok)
    if current:
        segments.append(current)
    return segments


def is_safe_gh_api(tokens):
    method = None
    field_used = False
    endpoint = None
    i = 2
    while i < len(tokens):
        tok = tokens[i]
        if tok in ("-X", "--method"):
            if i + 1 >= len(tokens):
                return False
            method = tokens[i + 1].upper()
            i += 2
        elif tok.startswith("--method="):
            method = tok.split("=", 1)[1].upper()
            i += 1
        elif tok in ("-f", "-F", "--field", "--raw-field"):
            field_used = True
            i += 2
        elif tok.startswith(("--field=", "--raw-field=")):
            field_used = True
            i += 1
        elif tok == "--input" or tok.startswith("--input="):
            return False
        elif tok in GH_API_VALUE_FLAGS:
            i += 2
        elif tok.startswith("-"):
            i += 1
        else:
            if endpoint is None:
                endpoint = tok
            i += 1
    if endpoint is None:
        return False
    # GraphQL can carry mutations regardless of HTTP method; let it prompt.
    if "graphql" in tokens:
        return False
    if method is not None and method != "GET":
        return False
    # Without an explicit GET, field flags make gh default to POST.
    if field_used and method != "GET":
        return False
    return True


def is_safe_git(tokens):
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if tok in ("--no-pager", "-P"):
            i += 1
        elif tok == "-C":
            i += 2
        elif tok.startswith("-"):
            # -c can inject pagers/aliases that execute commands; reject all
            # other global flags too.
            return False
        else:
            return tok in GIT_RO_SUBCOMMANDS
    return False


def is_safe_gh(tokens):
    if len(tokens) < 2:
        return False
    if tokens[1] == "api":
        return is_safe_gh_api(tokens)
    if tokens[1] in ("search", "status"):
        return True
    if len(tokens) >= 3 and (tokens[1], tokens[2]) in GH_RO_SUBCOMMANDS:
        return True
    return False


def is_safe_segment(tokens):
    if not tokens:
        return True
    first = tokens[0]
    if first == "gh":
        return is_safe_gh(tokens)
    if first == "git":
        return is_safe_git(tokens)
    if first == "sort" and any(t == "-o" or t.startswith("--output") for t in tokens):
        return False
    return first in SAFE_UTILS


def command_is_safe(command):
    # Constructs we can't reason about: command substitution (even inside
    # double quotes), backticks, and multi-line commands.
    if "$(" in command or "`" in command or "\n" in command:
        return False
    try:
        tokens = tokenize(command)
    except ValueError:
        return False
    tokens = strip_safe_redirects(tokens)
    # Any remaining pure-punctuation token that isn't a separator is a
    # redirect, subshell, or backgrounding construct: reject.
    for tok in tokens:
        if tok not in SEPARATORS and tok and all(c in "();<>|&" for c in tok):
            return False
    return all(is_safe_segment(seg) for seg in split_segments(tokens))


def main():
    data = json.load(sys.stdin)
    if data.get("tool_name") != "Bash":
        return
    command = data.get("tool_input", {}).get("command", "")
    if "gh api" not in command:
        return
    if command_is_safe(command):
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": "all segments read-only (gh api GET)",
            }
        }))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Fail safe: no output means the normal permission flow continues.
        pass
