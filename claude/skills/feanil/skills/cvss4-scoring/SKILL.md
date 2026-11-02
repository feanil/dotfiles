---
name: cvss4-scoring
description: Score a vulnerability with CVSS 4.0 - pick each base metric, compute the CVSS-B score locally with the cvss library, present the vector with full metric and value names and the neighbouring scores for any metric in doubt, and map the score to a severity band. Use whenever a task asks for a CVSS vector or score, compares two scorings, or reviews a reporter's proposed severity; it carries the v3.1-to-v4.0 differences that trip up people who learned v3.
---

# CVSS 4.0 scoring

Use CVSS 4.0. GitHub advisories support it natively and v3.1 is no longer
scored. Only the **Base** metrics are scored here (no Threat, Environmental
or Supplemental), so the result is CVSS-B. A vector starts `CVSS:4.0/` and
lists, in order: `AV/AC/AT/PR/UI/VC/VI/VA/SC/SI/SA`.

The spec is https://www.first.org/cvss/v4.0/specification-document and the
reference calculator is https://www.first.org/cvss/calculator/4.0.

## Compute, never estimate

Run the proposed vector through `scripts/score.py` before writing the score
anywhere. It prints the vector as a table of full metric and value names,
the score and band, and (with `--vary`) the score for every alternative
value of a metric you are unsure about:

```bash
uv run ~/.claude/skills/cvss4-scoring/scripts/score.py \
  'CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:A/VC:H/VI:H/VA:H/SC:H/SI:H/SA:H' --vary UI --vary PR
```

The one-liner behind it, when the script is not to hand:

```bash
uvx --from cvss python -c "from cvss import CVSS4; c=CVSS4('<vector>'); print(c.base_score, c.severity)"
```

## Presentation

Spell out the full metric name and the full value name next to the
abbreviation every time a vector is shown to a person: `Attack Vector (AV):
Network (N)`, not `AV:N`. Give one line of reasoning per metric. For any
metric that was in doubt, show the neighbouring values and their scores so
the reader can see what the choice costs. Check what the reporter already
filed and say where and why the proposal differs.

## Differences from v3.1

- **No Scope (S).** The "changed scope" idea moved into a second impact
  triple: VC/VI/VA score the **vulnerable system**, SC/SI/SA score any
  **subsequent system** the attack reaches.
- **Attack Requirements (AT) is new.** v3 folded "needs a race window or a
  particular configuration" into AC:H; v4 puts that in AT:P and keeps AC for
  defeating a built-in security control.
- **User Interaction (UI) has three values.** `N` none, `P` passive (the
  victim just uses the system normally), `A` active (the victim must do
  something specific). v3's "XSS that fires on page load is UI:N" becomes
  `UI:P`; a reflected XSS behind a crafted link is `UI:A`.
- **Privileges Required (PR)** is unchanged in shape but the v4 guidance is
  to score the privilege level the *attacker* holds, not the victim's.

## Base metrics

- **AV, Attack Vector.** `N` for anything reached over the network, which is
  nearly every web-application bug. `A` adjacent, `L` local, `P` physical
  are for ops tooling and filesystem-adjacent issues.
- **AC, Attack Complexity.** `L` when a direct request reproduces it. `H`
  only when the attacker must defeat a security control: bypass a
  mitigation, guess a secret, win a cryptographic race.
- **AT, Attack Requirements.** `N` by default. `P` when success depends on
  conditions the attacker does not control: a race window, a non-default
  setting, a feature that must be enabled, a particular victim state.
- **PR, Privileges Required.** `N` none, `L` a routine account, `H` an
  administrative one. Projects usually fix a role mapping (which roles are
  `L`, which are `H`, whether self-registration makes a logged-in user
  `N`); look for that mapping in the project's own notes and apply it.
- **UI, User Interaction.** `N` for server-side bugs. `P` when the victim
  only has to view content in the normal course of use. `A` when the victim
  must deliberately act: click a crafted link, submit a form, import a file.
- **VC / VI / VA, impact on the vulnerable system.** `H` for full data read,
  arbitrary write, or full denial of service; `L` for limited or scoped
  impact; `N` for none.
- **SC / SI / SA, impact on a subsequent system.** Non-`N` when the attack
  crosses a security authority: SSRF reaching cloud metadata or an internal
  network, script running in a victim's browser session acting as them,
  account takeover acting as another user, code execution reaching the host.
  `N` when the impact stays inside the vulnerable system's own authority.

## Severity bands

| Score | Band |
|---|---|
| 0.0 | None |
| 0.1 to 3.9 | Low |
| 4.0 to 6.9 | Medium |
| 7.0 to 8.9 | High |
| 9.0 to 10.0 | Critical |

Some disclosure venues say "moderate" where CVSS says "Medium"; use the
venue's word when writing for it.

## Worked examples

Scores from the `cvss` library, 2026-10. Illustrations only; score each real
vector yourself.

**Unauthenticated SSRF on an endpoint that fetches a user-supplied URL.**
`CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:L/VI:N/VA:N/SC:L/SI:N/SA:N` is 6.9
Medium. VC:L because small responses leak; SC:L because the internal network
or cloud metadata is reachable; no write, no denial of service.

**XSS on an application origin that carries a logged-in session.** Scored at
the account-takeover ceiling: `VC:H/VI:H/VA:H/SC:H/SI:H/SA:H`. The session
cookie may be HttpOnly, but the script can read the CSRF token and call any
API as the victim, including changing the account email and resetting the
password. The worst-case victim is an administrator, so the ceiling is
control of the instance. Score lower only when the execution context is
genuinely isolated (a sandboxed origin with no session).
- Reflected, anonymous, victim must follow a link:
  `CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:A/VC:H/VI:H/VA:H/SC:H/SI:H/SA:H` is 9.4 Critical.
- Stored by a low-privilege author, victim only views the page:
  `CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:P/VC:H/VI:H/VA:H/SC:H/SI:H/SA:H` is 9.4 Critical.
  With UI:A (the victim must open a specific link) it is 9.3.
PR comes from who can plant the payload.

**IDOR letting any account read another user's record.**
`CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:N/VC:L/VI:N/VA:N/SC:N/SI:N/SA:N` is 5.3
Medium; with PR:N (open self-registration counted as no privilege) it is
6.9 Medium. VC:L for limited data, no write, no subsequent system.

**Authenticated low-privilege RCE via a misvalidated import.**
`CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:N/VC:H/VI:H/VA:H/SC:H/SI:H/SA:H` is 9.4
Critical. Full impact on the application and, through SC/SI/SA, on the host.

**Administrator-only SQL injection in an admin form.**
`CVSS:4.0/AV:N/AC:L/AT:N/PR:H/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N` is 8.6
High. PR:H, full impact on the application, nothing beyond it.
