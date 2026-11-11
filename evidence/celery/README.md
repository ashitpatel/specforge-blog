# Evidence: celery (Python) — part 16

Primary sources for the celery deep-dive. Same honesty header as the
sshd folder: FR2 and FR3 ran under a static-only evidence policy, so
every verdict here is "statically confirmed + blind-adjudicated", never
demonstrated on running code (`demonstrated: false` throughout). The
deployment models are UNCONFIRMED, so multi-threaded sharing is assumed
where the verdicts say so.

## Runs

- **FR2** (16 packets, sshd × celery, 4 fixes each, arms A/B), engine
  `cleanroom-fr2-v2`, Nov 2026: `evals/cleanroom/fr2/PREREGISTRATION.md`,
  `SCORES.json` (sha256 `70ee4d84…`), `ANALYSIS.md`,
  `docs/project/rounds/2026-11-04-FR2-results.md`.
- **FR3** (8 packets, sshd × celery, 2 new fixes each, arms A/B), engine
  `cleanroom-fr3-v1`, Nov 2026: `evals/cleanroom/fr3/PREREGISTRATION.md`,
  `SCORES.json` (sha256 `6282aa3d…`), `ANALYSIS.md`,
  `docs/project/rounds/2026-11-04-FR3-results.md`.

Paths are relative to the specforge repository
(https://github.com/ashitpatel/specforge, `main` branch).

## Packet trees quoted (pre-fix exports, git checkouts)

| packet | tree HEAD | date | note |
|---|---|---|---|
| celery-fr3/pkt-a, pkt-c | `dd7c23862eb0` | 2026-07-23 | direct parent of the flush fix (4 days before it) |
| celery-fr3/pkt-b | `166f705adcae` | 2025-08-31 | `6804ea8615` tree; flush defect present a year early |
| celery-fr2/pkt-e | `395d289b27e3` | 2026-09-27 | LimitedSet structural finding |
| celery-fr2/pkt-a | `debd39c54a57` | 2026-09-30 | flush cluster member |

Code excerpts in the post are from these trees at the line numbers
quoted, verifiable at e.g.
https://github.com/celery/celery/blob/dd7c23862eb08a2cfde7da6926f28410b699c077/celery/events/dispatcher.py

## Upstream fix matched (verified on GitHub)

- `f85031f61247dae1dcf19ca88cc057edba1534ee` — "fix(events): don't
  drop buffered events appended during publish (#10435)" (Oliver Haas,
  2026-07-27). FR3 findings pkt-a#4, pkt-c#0 (own) and pkt-b#3 (open)
  match its defect and mechanism exactly.
  https://github.com/celery/celery/commit/f85031f61247dae1dcf19ca88cc057edba1534ee
- One wrinkle, stated in the post: the testers found the
  errors-buffer instance (`_outbound_buffer`, list+clear outside the
  mutex); the fix repaired the sibling group-buffer instance
  (`events[:] = []` → `del events[:len(batch)]`). Same defect, same
  mechanism, adjacent lines — the match is on defect+mechanism, which
  is what the blind matcher's "exact" verdict claims.

## Files in this folder (verbatim copies unless noted)

- `MATCHES-celery.json` — the 12 celery rows (FR2 pkt-a–h, FR3 pkt-a–d)
  of the two runs' blind `MATCHES.json`, extracted by script, rows verbatim.
- `fr2-C1.json` — EventDispatcher.flush loss cluster (real × 7
  subclaims, seven FR2 packets; found unlabelled — the flush fix was not
  an FR2 label).
- `fr2-C36.json` — LimitedSet purge-evicts-live verdict (real,
  deterministic; the Alloy `NoPrematureEvict` violation).
- `fr3-C5.json` — flush loss verdicts, pkt-a#4 + pkt-c#0 (real × 2,
  GIL-reachable; own-fix exact matches).
- `fr3-C20.json` — flush loss verdict, pkt-b#3 (real, GIL-reachable;
  open-fix exact match on the older tree).
- `fr3-C1.json` — Timer double-start verdict (real, GIL-reachable).
- `fr3-C6.json` — concurrent-flush double-publish verdict (real,
  GIL-reachable; same window as the loss).
- `pkt-a-fr3-REPORT-excerpt.md` — findings B5/B6 (flush loss +
  double publish) of the pkt-a report, with source line numbers
  (excerpt, marked).
