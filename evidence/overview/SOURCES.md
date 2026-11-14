# Sources for part 14 (evidence overview)

Every quantitative claim in
[`2026-11-22-evidence-overview.md`](../../blog/_posts/2026-11-22-evidence-overview.md),
with the record that carries it. `specforge:` paths are relative to
https://github.com/ashitpatel/specforge (`main`); `blog:` paths to this
repository.

## Demonstrated rung

| claim | source |
|---|---|
| kazoo pointed: 6/10 fixes, 9 reproduced findings, 7 distinct bugs, 0 FP | `specforge:docs/project/milestones/M3.md`, `specforge:evals/benchmarks/kazoo/RESULTS.md` |
| kazoo pointed hints caveat (every hit had a medium/strong hint) | `specforge:evals/benchmarks/kazoo/RESULTS.md` ("What the authors were told") |
| kazoo no-hint: 3/10 + 4 open bugs reproduced on `f6a78f7` | `specforge:evals/benchmarks/kazoo/NOHINT_RESULTS.md` |
| kazoo review: 6/6 restores named, 0/2 controls | `specforge:docs/project/milestones/M4.md`, `specforge:evals/benchmarks/kazoo/REVIEW_RESULTS.md` |
| run 19 (stomp.py + Pyro5): 23/23 real, 4/5 own-or-open (3 exact + 1 partial), 0 wrong-direction | `specforge:evals/cleanroom/run19/ANALYSIS.md`, `specforge:evals/cleanroom/run19/SCORES.json` |
| run 15 (kombu + huey): 33/33 real demonstrated, 0/8 recall | `specforge:evals/cleanroom/run15/ANALYSIS.md` |
| R152: 5/5 outcomes (1 reproduced race + 4 cleans with controls) | `blog:evidence/rounds/2026-10-26-R152-results.md` |

## Static + adjudicated rung

| claim | source |
|---|---|
| run 33 (Log4j 2): 36/37 real (97%), 0/8 recall, 1 wrong-direction, 8/8 to verdict | `specforge:evals/cleanroom/run33/ANALYSIS.md` |
| run 33 miss ranks c@106, d@385 (below screen) | `specforge:evals/cleanroom/run33/ANALYSIS.md` (miss table) |
| FR2: 134/141 real (95.0%), R1 A0/B1, R2 A2/5 B4/5, R3 A0/8 B3/8, R4 A2 B5, cost 1.66×/2.92×, adoption False | `specforge:evals/cleanroom/fr2/SCORES.json` (sha256 `70ee4d84…`), `specforge:evals/cleanroom/fr2/ANALYSIS.md`, `specforge:docs/project/rounds/2026-11-04-FR2-results.md` |
| FR3: 84/94 real (89.4%), R1′ 1/4+1/4, R2′ 2/4+4/4, R3 A1/4 B3/4, R4′ A1/25 B5/69, cost 1.76×/3.20×, adoption False | `specforge:evals/cleanroom/fr3/SCORES.json` (sha256 `6282aa3d…`), `specforge:evals/cleanroom/fr3/ANALYSIS.md`, `specforge:docs/project/rounds/2026-11-04-FR3-results.md` |
| run 34 (reactor-core): 31/34 real (91%), own 0/8, open 1/8, P1 7/8, P4 1/8, P3 2, P35 8/8, P22 8/8 | `specforge:evals/cleanroom/run34/SCORES.json` (sha256 `23f89243…`), `specforge:evals/cleanroom/run34/ANALYSIS.md` |
| runs 35–37 (Go blind, 24 packets): 80/82 real (97.6%), 14 own + 7 open matches | `specforge:evals/cleanroom/run35/SCORES.json` (sha256 `01bb15f0…`), `specforge:evals/cleanroom/run36/SCORES.json` (sha256 `c075d729…`), `specforge:evals/cleanroom/run37/SCORES.json` (sha256 `fe21703e…`), run `ANALYSIS.md` files, `specforge:docs/project/rounds/2026-11-14-GRUN-results.md` |

## Guard, proposer, structural

| claim | source |
|---|---|
| MR1b: Log4j d 1st of 31, c 2nd of 3, visible ≤ 10 | `blog:evidence/rounds/2026-11-02-MR1-manifestation-reading.md` |
| Java 4-bench recall @100: 10/17, 5/5, 3/17, 1/2 (frozen) | `specforge:docs/project/rounds/2026-11-07-M8-results.md` |
| Go 3-bench recall @10: bbolt 2/4, grpc-go 2/23, etcd 1/25 | `specforge:evals/benchmarks/recall-go-bbolt/SELECTION.json`, `specforge:evals/benchmarks/recall-go-grpc/SELECTION.json`, `specforge:evals/benchmarks/recall-go-etcd/SELECTION.json` (items; ranks live in the local-only MANIFESTs, as Java's do), `specforge:docs/project/rounds/2026-11-13-G2-results.md`, `specforge:docs/project/rounds/2026-11-13-G3d-results.md` (rebless review with final ranks) |
| FM83: 4 fn-name coincidences, covers v2 | `specforge:docs/project/rounds/2026-11-07-FM83-results.md` |
| Proposer tail precision 3/40 (7.5%); miss autopsy 21 never-proposed + 1 ranked-out | `specforge:docs/project/rounds/2026-11-07-M8-results.md`, `specforge:docs/project/rounds/2026-11-07-M8-correction-1.md` |
| recall-pilot: 14/20 covered, 0/20 in author reach | `specforge:evals/benchmarks/recall-pilot/RESULTS.md` |
| asyncpg: 5/6 covered, 6/6 caught by spec loop incl. uncovered T01 | `specforge:evals/benchmarks/recall-asyncpg/RESULTS.md` |
| procrastinate: pre-fix find, clean after + at HEAD, planted + control | `specforge:evals/benchmarks/procrastinate/RESULTS.md`, `specforge:docs/project/milestones/M3b.md` |
| R154: Alloy mirrors agree everywhere, nothing new | `blog:evidence/rounds/2026-10-26-R154-results.md` |
| celery LimitedSet Alloy violation, real | `blog:evidence/celery/fr2-C36.json` |
| sshd Alloy cleans + seeded falsifiability | `blog:evidence/sshd/pkt-g-REPORT.md`, `blog:evidence/sshd/pkt-f-REPORT-excerpt.md` |

## Misses, instruments, own guard

| claim | source |
|---|---|
| Labelled recall 0/8 (runs 15, 33, 34) to 4/5 (run 19); no own-slice authoring in 24 FR2/FR3 packets; Go own-slice covers on 7 packets | run/FR `ANALYSIS.md` files above; `specforge:evals/cleanroom/run36/ANALYSIS.md`, `specforge:evals/cleanroom/run37/ANALYSIS.md` (P2 notes) |
| Wrong-direction: 1 (run 33), 7 (FR2), 6 (FR3), 2 (run 34), 0 (runs 35, 36), 2 (run 37); caller-threading/lock-identity backlog, +serialized-wrapper checks (run 34), +same-word/guard checks (run 37) | run/FR `ANALYSIS.md` files above |
| Full reading lost twice; screen-50 stays default | FR2/FR3 results records above |
| I2H prompt+gate 2/2 filed, 2/2 blind-real | `specforge:docs/project/rounds/2026-11-08-depth-I2H-results.md` |
| Q5 reserve slot 2/4 precision, stays opt-in | `specforge:docs/project/rounds/2026-11-08-depth-Q5-results.md` |
| Own-repo guard: 300 reviews, 0 BLOCKING, 3 errored runs (2026-11-13) | Local `.git/specforge-guard/` log (not in version control; counted, not quoted) |

## Extent table (part 14, "55 projects")

| claim | source |
|---|---|
| Per-run packets / findings / matches (runs 6–37, FR2, FR3) | `specforge:evals/cleanroom/<run>/SCORES.json` (frozen; run 11's partial from its `ANALYSIS.md`, which has no `MATCHES.json`) |
| Run codebases (prereg titles) | `specforge:evals/cleanroom/<run>/PREREGISTRATION.md` (run 22: constructed) |
| Totals: 259 packets, 1,199 findings (run 22 excluded) | Summed from the frozen `SCORES.json` files above |
| Repo URLs (45 installed clones) | `origin` remotes under `benchmarks/candidates/` and `benchmarks/java/` (local checkouts, not in version control) |
| Repo URLs (rich, redis-py, gevent, trio, prompt_toolkit, ansible-core, asyncpg) | Verified to exist via `gh api repos/<org>/<name>` 2026-11-11 (no local clone) |
| Beyond-cleanroom rows (kazoo, procrastinate, asyncpg, J3a/b/c + H) | Sources in the tables above; J-series verdicts from `blog:evidence/hikaricp/2026-10-29-J6c-java-golden-properties.md` |
| Beyond-cleanroom rows (bbolt, grpc-go, etcd: G3c/G3d directed Go end-to-end) | `specforge:docs/project/rounds/2026-11-13-G3c-results.md`, `specforge:docs/project/rounds/2026-11-13-G3d-results.md` |
| Repo URLs (bbolt, grpc-go, etcd) | `origin` remotes under `~/projects/benchmarks/` (local checkouts, not in version control) |
