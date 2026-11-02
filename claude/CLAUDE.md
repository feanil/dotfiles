Work state lives in `~/workdesk`: one folder per item under `work/`, each with
a `README.md` whose frontmatter and body hold what the next session needs
(`policy/types.md` there has the schema). When the current work matches a
tracked item, use the `work-state` skill (`/workdesk:work-state`) to resume,
hand off, capture or check what is due. A repo's own `CLAUDE.md` holds only
stable working rules for that repo, not state.

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
- A question is a request for information, not for a change. Answer it and
  stop; do not edit, refactor or "improve" anything off the back of a
  question unless I ask for the change.
- Where possible use the dedicated file tools (Read, Edit) before bash.
- Run each shell command as its own Bash call; don't chain with `&&` or `||`
  unless it is necessary.
- Always run `cd ` commands separately from other commands.
    - The bash tools preserves the folder you're in between tool calls.
- My wall-clock time is the expensive resource. Before starting anything that
  runs for more than a few seconds (large clones, long measurements, big test
  runs), ask whether the answer changes a decision that matters. If it only
  settles a minor detail, pick the sensible default and move on; if it's
  borderline, ask me whether it's worth running before kicking it off. Quick
  scratch checks that settle a correctness question are fine.

## Skills and where they live

- `~/.claude/skills` is a symlink into the public `feanil/dotfiles` repo.
  The `feanil` plugin there (`claude/skills/feanil/`, `/feanil:<skill>`)
  holds the generic skills: `pr-review-drafts`, `ghsa-advisory-api`,
  `cvss4-scoring`, `git-history`. Anything there must be safe for the open
  internet: generic `OWNER/REPO` and `GHSA-xxxx` placeholders, no
  unpublished advisory ids, PR details, tokens or private URLs. Skill
  changes get committed there with a conventional commit scoped `claude`.
- Private or Open edX process skills go in `~/workdesk/plugin/skills/`
  (the `workdesk` plugin, `/workdesk:<skill>`), never in dotfiles.

## Git Workflow Preferences

- Prefer fixup commits (`git commit --fixup=<sha>`) for related changes rather than
  creating separate commits.
- Rebases (autosquash, reword, reorder), amending and partial staging go
  through the `git-history` skill (`/feanil:git-history`): it has the
  non-interactive `GIT_SEQUENCE_EDITOR` / `GIT_EDITOR` technique and the
  `git apply --cached` route, since `git add -p` and `-i` need a TTY. Before
  any `git rebase`, explain the plan (which commits move, what messages
  change, what scripts will run) and wait for my explicit confirmation; a
  force-push afterwards needs its own confirmation.
- Stage files by explicit pathspec (`git add path/to/file`).
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
  all go through the `voice` skill (`/workdesk:voice`), which reads
  `/home/feanil/workdesk/policy/voice.md`. Read that file before drafting the
  prose — not from memory, and not as a polish pass afterwards.
- Always create reviews as **pending drafts** so I can edit before submitting. Never pass
  an `event` when creating one; that submits it immediately.
- **Never post standalone PR comments** (e.g., `gh pr comment`, `POST /issues/.../comments`,
  or any call that publishes without going through a pending review). All feedback must go
  through the pending review, replies included. One exception: an ask that has no inline
  anchor in the diff goes out as a follow-up PR comment after I've submitted the review,
  once I've approved that specific comment. Review bodies are assumed not to go out.
- Only one pending review per PR is allowed, so **add to the existing one rather than
  replacing it**. Do not delete and recreate a pending review — it loses my edits, and
  it is no longer necessary.
- **Read anything in full before deleting it**, whether that is one staged comment or a
  whole review. Deleting is permanent — there is no undelete, and any comment I edited in
  the GitHub UI is lost with it. Fetch the bodies first, diff them against what was last
  posted, and carry my edits through verbatim. Restoring stripped markdown fencing is
  fine; rewording is not. Where my wording and yours disagree, mine wins.
- The mechanics — creating a draft review, finding and appending to the pending
  one, replying on a thread, line anchors, dropping or rewording a staged comment,
  submitting — are the `pr-review-drafts` skill (`/feanil:pr-review-drafts`).
  Reviews are built in GraphQL and anchored by **file line**, not diff `position`.
