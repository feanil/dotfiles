For multi-session projects, track project state in the project's `CLAUDE.md`: only
what the next session needs to pick up where this one left off. Detail goes in the
files it links to.

## General Development Notes

- Prefer many smaller commits to one big commit for making changes. The goal is
  to have smaller commits that are easier to review individually rather than one
  large hard to review commit.
- When debugging issues (CI failures, deployment errors, etc.), reproduce the
  problem locally before attempting a fix. This confirms the root cause and
  verifies the fix actually works. Don't assume a fix is correct just because
  it looks right.
- When a CI check should have caught an issue but didn't, investigate why. The
  CI configuration itself may have a bug (wrong settings, missing test coverage,
  etc.) that allowed the issue through.
- Where possible use the dedicated file tools (Read, Edit) before bash.
- Run each shell command as its own Bash call; don't chain with `&&` or `||`
  unless it is necessary.
- Always run `cd ` commands separately from other commands.
    - The bash tools preserves the folder you're in between tool calls.

## Git Workflow Preferences

- Prefer fixup commits (`git commit --fixup=<sha>`) for related changes rather than
  creating separate commits.
- Claude may run interactive rebases (autosquash, reword, etc.) using the
  non-interactive editor technique below, but must first explain the plan
  (which commits move, what messages change, what scripts will run) and wait
  for explicit confirmation before invoking `git rebase`. After confirmation,
  also force-push needs the usual force-push confirmation.
  - `GIT_SEQUENCE_EDITOR` runs against the rebase todo file. E.g.
    `GIT_SEQUENCE_EDITOR='sed -i "1s/^pick/reword/"'` flips the first commit
    from `pick` to `reword`.
  - `GIT_EDITOR` runs against each commit-msg buffer. Point it at a small
    script that overwrites `$1` (the buffer path) with a prepared message
    file, e.g. `#!/bin/bash\ncp /tmp/new_msg.txt "$1"`.
  - Pass `-i` to `git rebase` — without it, `--autosquash` is silently ignored
    and `GIT_SEQUENCE_EDITOR` is not invoked.
  - Clean up the temp scripts after the rebase; an orphaned `GIT_EDITOR`
    script could clobber a later commit's message buffer if reused.
- `git add -i` and `git add -p` both need an interactive TTY — skip both.
  Stage files by explicit pathspec (`git add path/to/file`). For partial-file
  staging, edit the file directly so `git add <file>` stages only what you
  intend, or write a patch and apply it with `git apply --cached`.
- When running git commands in a repo, `cd` into the repo directory first rather than
  using `git -C <path>` on every invocation.
- Include links to relevant source code, documentation, or version comparisons in
  commit messages when explaining why changes were made.

## Commit Message Format

Follow [OEP-51 conventional commits](https://docs.openedx.org/projects/openedx-proposals/en/latest/best-practices/oep-0051-bp-conventional-commits.html)
for all repos, not just openedx. Format: `<type>: <subject>\n\n<body>\n\n<footer>`.
Breaking changes use `!` (e.g., `feat!: drop python 3.8 support`).

**Types** (priority order; when a commit mixes types, use the highest-priority one
that applies):

- `revert` — undo a previous commit (include the prior commit message)
- `feat` — new feature or change to the feature set; includes public API changes
- `fix` — bug fix, security fix, or behavior change to an existing feature
- `perf` — performance improvement
- `docs` — docs-only (docs *for* other work belong in that work's commit)
- `test` — tests-only (same rule)
- `build` — CI, Makefile, tox.ini, packaging, release tooling
- `refactor` — no consumer-visible behavior change
- `style` — code styling only
- `chore` — repetitive mechanical work (requirements bumps, translations)
- `temp` — short-lived experimental change that will still be merged

**feat vs fix**: `feat` *adds* to the feature set; `fix` changes how an existing
feature *behaves*.

**Subject**: ~70 chars or fewer; no Jira/GitHub issue numbers in the subject —
links go in the body.

**Body**: explain the *why*. Reference public issues here. Footers use git
trailer format:
- `BREAKING CHANGE: <description>` — required for `<type>!` commits
- `Co-authored-by: Name <email>` — collaboration (already standard practice here)
- `Private-ref: <link>` — the only allowed place for links to private trackers

**Dep bumps**: if a pinned-dep upgrade pulls in a feat or fix, label the commit
`feat`/`fix` (not `chore`) so the change stays discoverable in the log.

**`squash!`/`fixup!` vs `temp`**: use git's `squash!`/`fixup!` when the *commit*
is meant to be squashed away; use `temp` when the *change* is short-lived but
will merge as-is.

## GitHub CLI Notes

When processing JSON output from `gh` commands, prefer the built-in `--jq` flag
(e.g. `gh pr list --json number,title --jq '.[] | .number'`) — it avoids a separate
process and works anywhere `gh` is available. Fall back to standalone `jq` only when
the transformation is too complex for a single `--jq` expression or when processing
JSON from a source other than `gh`.

On some repositories (including openedx), `gh pr edit --body` fails with a GraphQL
error about "Projects (classic)" deprecation. Use the REST API as a workaround:

```bash
gh api repos/OWNER/REPO/pulls/NUMBER -X PATCH -f body="new body content"
```

## PR Creation Preferences

- New PRs should be created as **drafts** by default (`gh pr create --draft`).
- Do NOT add "Generated by Claude" or similar attribution to PR descriptions —
  the `Co-Authored-By` trailer on commits is sufficient.
- Version bumps follow semantic versioning: use a **patch** bump for bug fixes,
  **minor** for new features, **major** for breaking changes.
- Do NOT include a "Test plan" section in PR descriptions without checking first.
  A checklist that just says "CI passes" is redundant noise.

## PR Review Preferences

- **Write anything posted under my name in my voice.** Review summaries, inline
  comments, replies to authors, PR descriptions, and issues filed on my behalf
  all get drafted from
  `/home/feanil/src/hacking/claude/my_voice/writing-style.md`. Read that file
  before drafting the prose — not from memory, and not as a polish pass
  afterwards.
- Always create reviews as **pending drafts** so I can edit before submitting. Never pass
  an `event` when creating one; that submits it immediately.
- **Never post standalone PR comments** (e.g., `gh pr comment`, `POST /issues/.../comments`,
  or any call that publishes without going through a pending review). All feedback must go
  through the pending review, replies included.
- Only one pending review per PR is allowed, so **add to the existing one rather than
  replacing it**. Find it with
  `gh api repos/OWNER/REPO/pulls/NUMBER/reviews --jq '.[] | select(.state == "PENDING") | .id'`,
  then append with `addPullRequestReviewThread` / `addPullRequestReviewThreadReply`. Do not
  delete and recreate a pending review — that was only ever a workaround for REST being
  unable to append, it loses my edits, and it is no longer necessary.
- **Read anything in full before deleting it**, whether that is one staged comment or a
  whole review. Deleting is permanent — there is no undelete, and any comment I edited in
  the GitHub UI is lost with it. Fetch the bodies first
  (`gh api repos/OWNER/REPO/pulls/NUMBER/reviews/REVIEW_ID/comments`, without narrowing
  `--jq` and comparing parsed JSON, since bodies contain newlines), diff them against what
  was last posted, and carry my edits through verbatim. Restoring stripped markdown fencing
  is fine; rewording is not. Where my wording and yours disagree, mine wins.

### Inline review comments

Mechanics live in the **`pr-review-drafts` skill** (`claude/skills/pr-review-drafts/`):
the exact GraphQL and REST calls for creating a draft review, appending to one that
already exists, replying on a thread, dropping or rewording a staged comment, editing
the body and submitting - plus `scripts/anchors.py`, which turns a PR diff into the
`line` / `side` anchors a comment needs.

Two things worth knowing without opening it. Reviews are built in GraphQL and anchored
by **file line**, not by diff `position`; the two coincide only in a wholly new file.
And a draft is **edited in place** - there is no delete-and-recreate, so my edits to a
staged review are never thrown away.
