---
name: git-history
description: Edit git history without a TTY - fixup commits and autosquash, reword or reorder commits through GIT_SEQUENCE_EDITOR and GIT_EDITOR instead of an interactive editor, stage part of a file without `git add -p`, and the confirm-before-rebase and force-push rules. Use whenever a task says "fixup", "squash", "autosquash", "reword", "rebase", "amend an earlier commit", "force-push", or needs only some of a file's changes in a commit.
---

# git history without a TTY

Claude Code has no interactive terminal, so `git rebase -i`, `git add -p`
and `git add -i` cannot be driven directly. Everything below works through
environment variables and explicit paths instead. `cd` into the repo first
rather than passing `git -C <path>` on every call.

## Related changes: fixup, then autosquash

Prefer a fixup commit for a change that belongs to an earlier, unpushed
commit on the branch, over a new standalone commit:

```
git commit --fixup=<sha> -- <paths>
```

Fixups are squashed away later with one autosquash rebase (below). Use
`squash!`/`fixup!` when the *commit* is meant to disappear; use a
conventional `temp:` commit when the *change* is short-lived but will merge
as it is.

## The rule: explain, then wait

Before any `git rebase`, state the plan and wait for an explicit yes:

- which commits move or merge, and into what;
- what messages change, old and new;
- the exact scripts and environment variables that will run.

A force-push after the rebase needs its own confirmation; approval of the
rebase does not cover it. A repo's own instructions may relax this for that
repo only.

## Autosquash without an editor

`--autosquash` is silently ignored without `-i`, and `-i` needs a sequence
editor. Point it at a no-op so git keeps the todo it generated:

```
GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>
```

`<base>` is the commit *before* the first one being changed (`origin/main`,
or `<sha>^`). Check with `git log --oneline <base>..HEAD` first that every
`fixup!` target is in that range.

## Reword, reorder, drop

`GIT_SEQUENCE_EDITOR` runs against the rebase todo file; `GIT_EDITOR` runs
against each commit-message buffer.

Reword the first commit in the range:

```
printf '%s\n' 'feat: the new subject' '' 'The new body.' > /tmp/new_msg.txt
printf '#!/bin/sh\ncp /tmp/new_msg.txt "$1"\n' > /tmp/git_editor.sh
chmod +x /tmp/git_editor.sh
GIT_SEQUENCE_EDITOR='sed -i "1s/^pick/reword/"' GIT_EDITOR=/tmp/git_editor.sh git rebase -i <base>
rm /tmp/git_editor.sh /tmp/new_msg.txt
```

To reword a commit that is not first, match its sha in the sed address
(`sed -i "/^pick abc1234/s/^pick/reword/"`). To reorder or drop, write the
whole todo yourself: `GIT_SEQUENCE_EDITOR='cp /tmp/todo.txt'` with the
lines in the order you want and `drop` where needed.

Clean up the temp scripts immediately after the rebase. An orphaned
`GIT_EDITOR` script that is reused clobbers a later commit's message.

## Amend the latest commit

`git commit --amend --no-edit -- <paths>` for content, or `--amend -m` /
`-F file` for the message. Only on an unpushed commit, or with the
force-push confirmation above.

## Staging part of a file

`git add -p` and `git add -i` need a TTY. Either:

- edit the file so it holds only what this commit should carry, `git add
  <file>`, then restore the rest; or
- write the hunks as a patch and apply them to the index only:
  `git apply --cached patch.diff`.

Always stage by explicit pathspec; never a bare `git add -A` or `git
commit -a`, which sweep in files the session did not mean to touch.

## After a rebase

`git log --oneline <base>..HEAD` and `git diff <old-head>` (the pre-rebase
sha from `git reflog`) to show the history changed and the tree did not,
or changed only as intended. Report both.
