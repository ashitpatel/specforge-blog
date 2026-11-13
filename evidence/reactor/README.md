# Evidence: reactor-core (reactive Java) — part 17

Primary sources for the run 34 post. All verdicts below are static:
run 34 ran under a static-only evidence policy, so every finding is
"statically confirmed + blind-adjudicated", never demonstrated on running
code (`demonstrated: false` in every verdict file). The deployment model
is UNCONFIRMED (a library whose usage questions were never answered), so
multi-threaded sharing is assumed where the verdicts say so. The post
states both limits; this folder lets you check them.

Names: run 34 is one cleanroom experiment (8 packets on reactor-core, no
arms); a packet is one tester's sealed session on one tree; a claim file
(`run34-G2.json` style) holds one finding-cluster with its blind verdicts
(one per sub-claim); R1–R8 are the eight packet trees.

## Run

- **Run 34** (8 packets, reactor-core, 8 distinct fixes), engine
  `cleanroom-reactor-core-v2`, Nov 2026. Design, frozen scores and analysis:
  - `evals/cleanroom/run34/PREREGISTRATION.md`
  - `evals/cleanroom/run34/SCORES.json` (sha256 `23f89243…`)
  - `evals/cleanroom/run34/ANALYSIS.md`
  - Engine record (the v1 OOM and the v2 bounds that unblocked the run):
    `docs/project/rounds/2026-11-12-R34-OOM-build.md`

Paths are relative to the specforge repository
(https://github.com/ashitpatel/specforge, `main`); the files below are
vendored here because packet workdirs and adjudication dirs are not in
version control.

## Files

- `MATCHES-reactor.json` — the blind label matcher's output: own 0/8, one
  open partial (pkt-h on fix `24f04bc7da`).
- `run34-G1.json` — the unicast subscribe-window NPE cluster: 3 real, 1
  not-real (G1.2, ruled out by the demand guard).
- `run34-G2.json` — the unicast cancel-null NPE cluster: 6/6 real.
- `run34-G6.json` — the MonoSubscriber double-discard cluster: 5/5 real.
- `run34-G9.json` — the EmitterProcessor swallowed-error claim: not real
  (safe sinks serialize the interleaving).
- `pkt-a-REPORT.md` — the pkt-a tester report in full (4 confirmed bugs).
- `pkt-h-REPORT-excerpt.md` — the pkt-h header plus its publishOn
  double-discard finding (the open partial).
