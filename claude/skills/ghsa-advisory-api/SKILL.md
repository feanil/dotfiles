---
name: ghsa-advisory-api
description: Read and write GitHub repository security advisories (GHSA) through the REST API with gh - list and read advisories and their comments, create a draft, open the temporary private fork, PATCH the CVSS vector, CWE ids, affected/patched versions, credits and description, request a CVE, close or publish. Use whenever a task touches a security advisory programmatically; it carries the field quirks that the REST docs do not state.
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
- The fork's merge button is broken on and off (a recurring GitHub bug);
  the fallback is a direct fast-forward push of the reviewed commits to the
  public branches. Button merges land as single-parent squashes titled
  "Merge commit from fork", which conventional-commit tooling such as
  python-semantic-release cannot parse.
- GitHub Actions do not run on the fork, so the PR-level status checks you
  rely on upstream (CLA bot, CI) never report there.

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
