# Evidence: sshd (Apache MINA SSHD, Java) — part 15

Primary sources for the sshd deep-dive. All verdicts below are static:
FR2 and FR3 ran under a static-only evidence policy, so every finding is
"statically confirmed + blind-adjudicated", never demonstrated on running
code (`demonstrated: false` in every verdict file). The deployment models
are UNCONFIRMED, so multi-threaded sharing is assumed where the verdicts
say so. The post states both limits; this folder lets you check them.

## Runs

- **FR2** (16 packets, sshd × celery, 4 fixes each, arms A/B), engine
  `cleanroom-fr2-v2`, Nov 2026. Design, frozen scores and analysis:
  - `evals/cleanroom/fr2/PREREGISTRATION.md`
  - `evals/cleanroom/fr2/SCORES.json` (sha256 `70ee4d84…`)
  - `evals/cleanroom/fr2/ANALYSIS.md`
  - Round record: `docs/project/rounds/2026-11-04-FR2-results.md`
- **FR3** (8 packets, sshd × celery, 2 new fixes each, arms A/B), engine
  `cleanroom-fr3-v1`, Nov 2026:
  - `evals/cleanroom/fr3/PREREGISTRATION.md`
  - `evals/cleanroom/fr3/SCORES.json` (sha256 `6282aa3d…`)
  - `evals/cleanroom/fr3/ANALYSIS.md`
  - Round record: `docs/project/rounds/2026-11-04-FR3-results.md`

Paths are relative to the specforge repository
(https://github.com/ashitpatel/specforge, `main` branch).

## Packet trees quoted (pre-fix exports, git checkouts)

| packet | tree HEAD | date | own fix |
|---|---|---|---|
| sshd-fr2/pkt-g | `4f92e0d3bcba` | 2025-03-16 | `9b9109c233` |
| sshd-fr2/pkt-f | `c49c0687aff1` | 2026-01-02 | `c1f31ee7c9` (3 days before the fix; direct ancestor line) |
| sshd-fr2/pkt-c | `c49790453544` | 2025-02-21 | `0fed512b02` |

Code excerpts in the post are from these trees at the line numbers quoted.
Upstream file URLs at those commits verify them, e.g.
https://github.com/apache/mina-sshd/blob/4f92e0d3bcba1614b227cf93bed3178213641b56/sshd-core/src/main/java/org/apache/sshd/common/session/helpers/AbstractSession.java

## Upstream fixes matched (verified on GitHub)

- `7849e4875d85dced5f26d4b95a09a7f488474692` — "Fix another race
  condition in KEX" (Thomas Wolf, 2026-10-11). Finding 11 on pkt-g
  matches it exactly (open-fix match).
  https://github.com/apache/mina-sshd/commit/7849e4875d85dced5f26d4b95a09a7f488474692
- `c1f31ee7c91db471605712ccc158a3a9f40f55b2` — "Avoid race condition
  when closing a SshClient" (2026-01-05, AtomicReference). Findings
  pkt-f#0, pkt-c#13/#14 overlap its schedule-vs-stop aspect (partial).
- `c425ac53e8df95684563d297cde6101b4db77255` — "[SSHD-1197] Fix race
  condition in KEX". FR3 pkt-c#4 is the same family but a different
  defect (partial; the post says so).

## Files in this folder (verbatim copies unless noted)

- `MATCHES-sshd.json` — the 12 sshd rows (FR2 pkt-a–h, FR3 pkt-a–d) of
  the two runs' blind `MATCHES.json`, extracted by script, rows verbatim.
- `fr2-S43.json` — KEX-before-assignment verdict (real, race).
- `fr2-S17.json` — ProcessShell destroy-vs-start leak verdict (real, race).
- `fr2-S1.json` — AgentImpl ConcurrentModificationException verdicts
  (real × 6 subclaims, six packets independently).
- `fr2-S28.json`, `fr2-S26.json`, `fr2-S27.json` — session-timeout
  cluster verdicts (real × 3).
- `fr3-S30.json` — rekey-vs-encode torn-read verdict (real, race;
  same KEX family as `c425`, different defect).
- `pkt-g-REPORT.md` — the pkt-g tester's full first-look report,
  verbatim (12 findings, 2 Alloy cleans, 6 controls).
- `pkt-f-REPORT-excerpt.md` — finding 1 (timeout NPE) and the Alloy
  section of the pkt-f report, with source line numbers (excerpt, marked).
