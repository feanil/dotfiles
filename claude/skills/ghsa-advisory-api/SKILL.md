---
name: ghsa-advisory-api
description: Read and write GitHub repository security advisories (GHSA) through the REST API with gh - list and read advisories and their comments, create a draft, open and work in the temporary private fork (remote naming, push retries, pre-merge refresh, the fast-forward fallback when its merge button breaks), PATCH the CVSS vector, CWE ids, affected/patched versions, credits and description, link the landed fix commits in a Patches section, request a CVE, close or publish. Use whenever a task touches a security advisory programmatically; it carries the field quirks that the REST docs do not state.
---

# Repository security advisories over the GitHub API

Everything here was verified against live advisories between 2026-08 and
2026-10. Where something is still unverified it says so. The API reference is
https://docs.github.com/en/rest/security-advisories/repository-advisories.

## Before you write

An advisory PATCH is live the moment it returns, and **publishing is
irreversible**. Two habits:

- **Echo before mutate.** Any command that PATCHes, closes or publishes first
  GETs the advisory and prints one line, then runs the write:

  ```bash
  gh api repos/OWNER/REPO/security-advisories/GHSA-xxxx-xxxx-xxxx \
    --jq '[.ghsa_id, .summary, .state] | @tsv'
  ```

- **Read back after every write** with a fresh GET, not the PATCH response.
  Several fields (below) read back differently from what was sent.

Check the project's own instructions for what needs sign-off before a write;
this skill covers the mechanics only.

## What to call

| To do this | Use |
|---|---|
| List a repo's advisories (duplicate check) | `GET /repos/O/R/security-advisories --paginate` (`?state=draft|triage|published|closed`) |
| Read one | `GET /repos/O/R/security-advisories/GHSA-…` |
| Read its comments | `GET /repos/O/R/security-advisories/GHSA-…/comments` |
| Create a draft | `POST /repos/O/R/security-advisories --input body.json` |
| Open the temporary private fork | `POST /repos/O/R/security-advisories/GHSA-…/forks` |
| Change any field | `PATCH /repos/O/R/security-advisories/GHSA-… --input patch.json` |
| Request a CVE | `POST /repos/O/R/security-advisories/GHSA-…/cve` (not yet exercised here) |
| Close | PATCH `{"state": "closed"}` |
| Publish | PATCH `{"state": "published"}` — irreversible |

## Sending nested or multi-line fields

`gh api --field` cannot express arrays of objects (`vulnerabilities`,
`credits`) and mangles multi-line markdown. Write the body to a JSON file and
pass `--input`:

```bash
jq -n --rawfile desc newdesc.md \
  '{description: $desc,
    cwe_ids: ["CWE-863"],
    vulnerabilities: [{package: {ecosystem: "pip", name: "PACKAGE"},
                       vulnerable_version_range: ">= 1.2.0",
                       patched_versions: ""}]}' > patch.json
gh api repos/OWNER/REPO/security-advisories/GHSA-xxxx-xxxx-xxxx -X PATCH \
  --input patch.json \
  --jq '{state, severity, cvss: .cvss_severities, vulns: .vulnerabilities}'
rm patch.json
```

When appending an analysis to a reporter's description, keep their text intact
above a `---` separator and add below it.

## CVSS vector

The one field that most often reads back wrong. Rules, each one measured:

- **Send the vector in its own PATCH**, `{"cvss_vector_string": "CVSS:4.0/…"}`
  and nothing else. The same field takes a v3.1 or a v4.0 string; the
  `CVSS:4.0/` prefix routes it. The REST docs list only `severity` and
  `cvss_vector_string` and never mention v4, so do not expect to find this
  there.
- **Do not send `severity` with the vector.** `severity` is derived from the
  vector and the API rejects both in one PATCH.
- **Bundling the vector with other fields is unreliable.** It is accepted and
  derives `severity` correctly, but the visible score and vector string have
  stayed null even on a re-read 15 seconds later. Re-sending the vector
  standalone afterwards populated them. It is idempotent, so bundle if you
  like, then always send it standalone too.
- **Read back from the versioned field.** A v4 vector lands in
  `.cvss_severities.cvss_v4.{score,vector_string}`, a v3 one in
  `.cvss_severities.cvss_v3` and the legacy top-level `.cvss`. Confirm the
  score **and** `.severity` together; a correct band with a null score means
  the standalone PATCH is still needed.
- **A v4 PATCH replaces a v3 vector.** `cvss_v3` and `.cvss` read back null
  afterwards. The two cannot coexist.
- **To clear a vector** (after a test on a throwaway draft), PATCH
  `{"severity": null}`. That nulls `severity` and the v4 score and vector.

Compute the score locally before sending:

```bash
uvx --from cvss python -c "from cvss import CVSS4; c=CVSS4('CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:L/VI:N/VA:N/SC:N/SI:N/SA:N'); print(c.base_score, c.severity)"
```

## Vulnerabilities and versions

- `vulnerabilities[].package.ecosystem` must be one of the API's enum values
  (`pip`, `npm`, `maven`, …). A stored `""` or free text such as
  `"open edx studio"` makes **every** later PATCH 422 until the row is resent
  with a valid value, so fix it on the first write.
- `vulnerable_version_range` and `patched_versions` are free text. Use a
  range (`>= ulmo`, `>= 1.2.0, < 1.4.1`) rather than an enumeration; a range
  stays correct when a new release cuts. For a named-release project express
  `patched_versions` as `>= <earliest patched release>`; for a pip package,
  one `vulnerabilities[]` row per release line with semver ranges. A fix
  shipped only as git tags lists the tags.
- Set `patched_versions` to the development branch name when the main fix PR
  opens and widen to the range when the backports open.

## Linking fix commits

A published advisory must point at the code that fixes it, or operators have
to guess which commit on which branch is the fix. Do this **after** the fix
has landed on the public branches and **before** publishing: the temporary
fork and its SHAs disappear at publication, and fork SHAs are not the ones
that end up on the public branches anyway. Every advisory gets a
`### Patches` section in its description:

```markdown
### Patches
The fix landed in the following commits:

* `master`: [a182ff5d50](https://github.com/OWNER/REPO/commit/<full 40-char sha>)
* `release/newer`: [f657d158c2](https://github.com/OWNER/REPO/commit/<full 40-char sha>)
* `release/older`: [c99de016f1](https://github.com/OWNER/REPO/commit/<full 40-char sha>)
```

Conventions, each learned the hard way:

- One bullet per branch the fix actually landed on: the development branch
  first, then release branches newest to oldest. Link text is the 10-char
  short SHA; the href carries the **full** SHA so it never goes ambiguous.
- Use the repository's **current** name in the URLs. Old names redirect,
  but new links should not depend on that.
- If the description still has GitHub's unfilled template placeholder
  (`_Has the problem been patched? ..._` under `### Patches`), replace that
  line rather than appending a second Patches section.
- Cite the **commit that carries the change**. Where a fix landed as a
  two-parent "Merge commit from fork", cite the underlying fix commit (the
  second parent), not the merge. A single-parent squash titled "Merge
  commit from fork" *is* the fix; cite it directly.
- When a branch needed more than one commit, cite each one in order, so an
  operator cherry-picking by hand knows the full set.
- For a package repo, list the package fix commits with their released
  versions, then the consumer pin-bump commits.
- Update `patched_versions` in the same pass, as a range from the earliest
  patched release (see above). A branch that merely *contains* the fix
  because it was cut after the fix landed counts as patched.

Verify each SHA is really on its public branch before writing it:

```bash
git fetch origin
git merge-base --is-ancestor <sha> origin/<branch> && echo yes
```

To find the fix commits for an advisory that never recorded them:

```bash
git log --all --oneline --grep='GHSA-xxxx-xxxx-xxxx'   # fork merges carry the id
git log --all --oneline -S'<symbol from the report>' -- path/to/file
git branch -r --contains <sha>                          # which branches have it
```

PATCHing a **published** advisory works the same as a draft, but nested
fields still need `--input`, and a stored invalid `ecosystem` will 422 until
it is resent as a valid value.

## Credits

- Write `credits: [{"login": "someone", "type": "reporter"}]`. Valid types
  include `analyst`, `finder`, `reporter`, `coordinator`, `remediation_developer`,
  `remediation_reviewer`, `remediation_verifier`, `tool`, `sponsor`, `other`.
  A credits-only PATCH leaves the vector, versions and state alone.
- **Read back from `.credits_detailed[]`**, not `.credits[]`. After the PATCH,
  `.credits[].user.login` is `null` in both the response and a fresh GET;
  `.credits_detailed[]` carries `user.login`, `type` and `state`.
- A new credit is `state: "pending"` until the person accepts it, and
  acceptance is **per advisory**: accepting on one does not carry to another.
  Add credits well before publishing so there is time to accept.

## Comments

`GET …/comments` works and returns each comment with an `html_url` ending in
`#advisory-comment-<id>`, usable as a link target. Always read the comments
before telling anyone you cannot see them; a `404` once seen on this path was
not explained and should be retried, not taken as "no endpoint".

Posting a comment through the API (`POST` to the same path) has not been
tried. Until it is, treat "post this as a comment on the advisory" as a
manual step: hand over the text, the human posts it in the UI.

## States

`triage` (reporter-submitted, not yet accepted) → `draft` (accepted, being
fixed) → `published`. `closed` from `triage` or `draft` for duplicates and
false positives. Move `triage` → `draft` with PATCH `{"state": "draft"}` once
the report is confirmed real. Publish only after the fix commits are on the
public branches and linked from the description, because the temporary fork
and its SHAs disappear at publication.

## Temporary private fork

`POST …/forks` creates `OWNER/REPO-ghsa-xxxx-xxxx-xxxx`. Known behaviour:

- The response can report `default_branch: main` while the fork's actual
  default is the upstream's (`master`); a PR against `main` fails with
  "Base ref must be a branch". Check `gh repo view --json defaultBranchRef`.
- A fresh fork rejects pushes for roughly 15 minutes or more (SSH "could not
  read from remote", then `fatal error in commit_refs`). Wait ten minutes and
  retry once; if it fails again it has sometimes provisioned broken and needs
  deleting and recreating from the advisory page.
- Backport PRs on the fork need the base branch to exist there: push the
  public release branch to the fork at the same SHA first.
- Some forks cannot be deleted via the API (`403 Must have admin rights`);
  they disappear at publication or via the advisory page.
- Button merges land as single-parent squashes titled "Merge commit from
  fork", which conventional-commit tooling such as python-semantic-release
  cannot parse.
- GitHub Actions do not run on the fork, so the PR-level status checks you
  rely on upstream (CLA bot, CI) never report there.

### Working in the fork from a clone

- **Name the remote after the advisory.** One clone of the upstream repo
  often carries several advisory forks at once; a generic name such as
  `advisory-fork` collides on the second one.

  ```bash
  git remote add ghsa-xxxx-xxxx-xxxx git@github.com:OWNER/REPO-ghsa-xxxx-xxxx-xxxx.git
  ```

- **Push retries.** On a remote read error or `commit_refs` failure, wait
  ten minutes and retry once. If it fails again, report and stop; no tight
  retry loops.
- **Keep the fork's base branches current.** Fast-forward the fork's copy
  of each base branch to the public head before pushing a PR branch, so the
  PR diff shows only the fix and not every intervening upstream commit:

  ```bash
  git fetch origin
  git push ghsa-xxxx-xxxx-xxxx origin/master:master
  git push ghsa-xxxx-xxxx-xxxx origin/release/<name>:release/<name>
  ```

- **Pre-merge refresh.** Fork PRs go stale while they wait for review and
  disclosure (one sat 131 commits behind). On merge day, before anything
  lands: fast-forward the fork bases as above, rebase each PR branch onto
  its refreshed base, re-run the targeted tests, force-push with
  `--force-with-lease`, and record the new SHAs. A force-push does not
  dismiss an existing approval.

### When the merge button is broken

The fork's merge button fails on and off (a recurring GitHub bug; branch
staleness is a red herring). The fallback is a **plain fast-forward push**
of the reviewed commits straight to the public branches, with admin bypass
of branch protection. Never `--force`: a non-force push is fast-forward
only, so a public branch that moved is rejected rather than clobbered.

```bash
git fetch origin
# the reviewed branch must sit exactly on top of the public head
git merge-base --is-ancestor origin/<branch> <reviewed-branch> && echo ff-ok
git log --oneline origin/<branch>..<reviewed-branch>   # expect only the fix commit(s)
git push origin <reviewed-branch>:<branch>
```

If the public branch has moved past the fork base, rebase the reviewed
branch onto `origin/<branch>` first and re-run the targeted tests on the
rebased commit; the SHA that lands is the rebased one. Afterwards confirm
each landed SHA with `git merge-base --is-ancestor <sha> origin/<branch>`
and close the now-redundant fork PRs. The fork PRs stay `OPEN` on the fork
when a fix lands this way; that is expected.

## Creating a draft

```bash
jq -n --rawfile desc body.md \
  '{summary: "Short title",
    description: $desc,
    severity: "medium",
    cwe_ids: ["CWE-862"],
    vulnerabilities: [{package: {ecosystem: "pip", name: "PACKAGE"},
                       vulnerable_version_range: "TBD", patched_versions: ""}]}' > advisory.json
gh api repos/OWNER/REPO/security-advisories -X POST --input advisory.json \
  --jq '{ghsa_id, html_url}'
rm advisory.json
```

`severity` may be sent on create as a placeholder band; replace it with a
standalone vector PATCH once scored.
