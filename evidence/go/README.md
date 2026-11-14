# Evidence: caddy (Go web server) — part 18

Primary sources for the Go deep-dive, which reads the caddy half of run 35
file by file. All verdicts below are static: run 35 ran under a
static-only evidence policy, so every finding is "statically confirmed +
blind-adjudicated", never demonstrated on running code (`demonstrated:
false` in every verdict file). The deployment models are UNCONFIRMED, so
multi-goroutine sharing is assumed where the verdicts say so. The post
states both limits; this folder lets you check them.

Names: run 35 is the first Go cleanroom experiment (8 packets,
nats-server × caddy); a packet is one tester's sealed session on one
tree; a claim file (`run35-C1.json` style) holds one finding-cluster
with its blind verdict.

## Run

- **Run 35** (8 packets, nats-server + caddy, 4 fixes each), engine tag
  `25713ee`, Nov 2026. Design, frozen scores and analysis:
  - `evals/cleanroom/run35/PREREGISTRATION.md`
  - `evals/cleanroom/run35/SCORES.json` (sha256 `01bb15f0…`)
  - `evals/cleanroom/run35/ANALYSIS.md`
  - Round record: `docs/project/rounds/2026-11-14-GRUN-results.md`

Paths are relative to the specforge repository
(https://github.com/ashitpatel/specforge, `main` branch).

## Packet trees quoted (pre-fix exports, git checkouts)

| packet | tree HEAD | date | own fix |
|---|---|---|---|
| caddy/pkt-a | `d6f86cc` | 2023-08-14 | `936ee918ee` (reverseproxy upstreams + logger) |
| caddy/pkt-b | `32c284b` | 2021-06-15 | `e8ae80adca` (fileserver browse template) |
| caddy/pkt-c | `b54fa41` | 2021-02-24 | `ce5a0934a8` (round-robin atomic) |
| caddy/pkt-d | `ab32440` | 2021-08-12 | `a10910f398` (admin serverMu) |

Code excerpts in the post are from these trees at the line numbers quoted.
Upstream file URLs at those commits verify them, e.g.
https://github.com/caddyserver/caddy/blob/d6f86cc/modules/caddytls/sessiontickets.go

## Upstream fixes matched (verified on GitHub)

- `936ee918ee00bcdf05d2f44a7fa292c054d64700` — "reverseproxy: Always
  return new upstreams (fix #5736) (#5752)" (2023-08-17; includes the
  "Fix healthcheck logger race" hunk). Finding 0 on pkt-a matches the
  logger race exactly (own-fix match).
  https://github.com/caddyserver/caddy/commit/936ee918ee00bcdf05d2f44a7fa292c054d64700
- `a10910f3981908424493c043d26dfcb4e5f8dc25` — "admin: Sync server
  variables (fix #4260) (#4274)" (2021-08-16; adds `serverMu`).
  Finding 0 on pkt-d matches it exactly (own-fix match, model-level);
  findings 1–2 on pkt-b and 0–1 on pkt-c match it exactly as an open
  fix.
  https://github.com/caddyserver/caddy/commit/a10910f3981908424493c043d26dfcb4e5f8dc25
- `325c244ea71a645c224afa1d0b46296ed76ef9fd` — "caddytls: fix TLS state
  races and ECH rotation retry (#7756)" (2026-05-20; holds `s.mu`
  across the STEK iteration). Not a label — the blind testers on the
  2021/2023 trees found the fatal STEK race it fixes years before it
  landed.
  https://github.com/caddyserver/caddy/commit/325c244ea71a645c224afa1d0b46296ed76ef9fd

## Files in this folder (verbatim copies unless noted)

- `MATCHES-caddy.json` — the 4 caddy rows (pkt-a–d) of run 35's blind
  `MATCHES.json`, extracted by script, rows verbatim.
- `run35-C2.json` — passive-health-check logger race verdict (real,
  race; own-exact on `936ee918ee`).
- `run35-C1.json` — STEK configs rotation race verdicts (real × 2
  subclaims, two packets independently).
- `run35-C3.json`, `run35-C4.json` — admin-server swap verdicts, local
  (real × 3) and remote (real × 2); model-level findings, confirmed by
  reading, unconfirmable by tool (no `@code` symbol for Go
  package-level state).
- `pkt-a-REPORT.md` — the pkt-a tester's full first-look report
  (2 confirmed bugs, 85 screen verdicts, 2 controls); one absolute path
  shortened for publication, marked inline, otherwise verbatim.
