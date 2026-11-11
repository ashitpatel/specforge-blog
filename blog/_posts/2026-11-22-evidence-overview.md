---
title: "The evidence file: what the runs actually showed"
description: "Every number behind the series' claims, in one place: blinded cleanroom runs on Java and Python projects, what matched upstream fixes, what stayed potential, and what the tool demonstrably misses."
layout: post
series: specforge
date: 2026-11-11
---

*Part 14 of 16 in a series on [specforge](https://github.com/ashitpatel/specforge). The first thirteen posts told stories. This one opens the file drawer: every run behind them, with the numbers that keep the stories honest. Evidence: [`evidence/overview/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/overview), [`evidence/sshd/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/sshd), [`evidence/celery/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/celery).*

*Level L1 · Needs: part 1. The calibrated whole.*

The series has shown you a lost wake-up, an overfilled pool, and two gates that fire. A fair reader asks: how much testing stands behind those stories, and what did the runs show when nothing worked? This post answers with the runs themselves — over a dozen evaluations on real Java and Python projects, blinded, preregistered, and scored from frozen records. Three sentences hold the calibration, and everything below is the receipt:

1. **At depth, the tool is precise but narrow.** What survives to a verdict is real about nine times in ten — but a labelled bug reaches depth only a fraction of the time.
2. **At the surface, the proposer is broad but noisy.** It covers roughly half of known fix locations, and most of an unfiltered suggestion list is duds.
3. **The demonstrated core spans five projects in both languages.** Blinded testers, reproduced on real code, matched to upstream fixes. Everything above that core inherits weaker guarantees, stated per rung.

## The ladder, strongest rung first

**Demonstrated on real code.** Four evaluations had blinded testers whose findings were reproduced against the real code and matched against fixes they never saw. On kazoo (Python), pointed authors caught 6 of 10 past fixes with 9 reproduced findings, 7 distinct bugs, and 0 false positives; unhinted authors caught 3 of 10 and 4 further bugs that still reproduced on that week's kazoo. On stomp.py and Pyro5 (run 19), all 23 adjudicated claims were real and 4 of 5 labelled fixes matched (three exact, one partial), with zero wrong-direction verdicts. On kombu and huey (run 15), all 33 claims were real and demonstrated — and recall was 0 of 8, because the labelled fixes sat in broker transports and an event loop the engine could not see. A five-slice wave (R152) went 5 for 5: one confirmed race reproduced, four honestly clean with controls. The stomp story in [part 5]({% post_url 2026-11-13-temporal-stomp %}) and the kombu story in [part 6]({% post_url 2026-11-14-structural-kombu %}) come from this rung.

**Statically confirmed and blind-adjudicated.** Three larger runs never executed code — Java has no replay, and the Python packets ran static-only — so their verdicts rest on static confirmation plus independent blind adjudication, never demonstration. Say that plainly, because the counts are the series' largest: run 33 on Log4j 2 (8 testers, 8 trees) judged 36 of 37 claims real with 0 of 8 labelled fixes matched; FR2 on sshd and celery (16 packets) judged 134 of 141 real (95.0%); FR3 (8 packets, new fixes) judged 84 of 94 real (89.4%). High precision, low labelled recall, no executions: that is the rung, stated whole. The next two posts open two of these runs file by file: [sshd]({% post_url 2026-11-23-sshd-deep-dive %}) and [celery]({% post_url 2026-11-24-celery-deep-dive %}).

**Flagged at introduction.** The change guard reviewed two Log4j feature commits blind and flagged both regressions in a visible place — 1st of 31 and 2nd of 3 — months before users manifested them ([part 4]({% post_url 2026-11-12-feature-log4j %})). Note the pairing the record insists on: run 33's depth missed those same two bugs' slices at ranks 106 and 385, below the screen. Change-triggered flags catch change-introduced bugs; they do nothing for latent races in dormant code. Neither half replaces the other. (Separately, change review on six kazoo fix diffs named the restored property 6 for 6, with no false restore on two controls — the review direction, measured on real fixes.)

**Proposer location recall.** The weakest rung, and the most easily overstated: does any proposal merely *cover* a fix's location, without finding the bug? On four Java benches (41 fix locations: commons-pool, HikariCP, curator, sshd), a frozen measurement covered 10/17, 5/5, 3/17 and 1/2 within rank 100 — and a follow-up adjudicated four covers as function-name coincidences, tightening the matching rule (covers v2, both ranks kept) rather than the numbers. On Python, a 20-item pilot covered 14 locations with 0 in author reach, while a 6-fix asyncpg set covered 5 — and its spec loop then caught all 6, including the uncovered one, violated pre-fix and clean on the control. Coverage is not finding; the asyncpg split shows which stage usually fails (proposing, not checking).

**Structural.** The shape-invariant family is thinner and the post says so. A PostgreSQL task queue's real 2020 defect — a delete the database refuses — was found on the pre-fix commit by direct schema/code comparison, with nothing reported after the fix or at HEAD; planted defects came with Alloy counterexamples and a schema-enforced control stayed clean non-vacuously. A three-slice Alloy pilot mirrored three temporal verdicts exactly and found nothing new — agreement as evidence, not discovery. The structural catches in the new deep-dives: one real Alloy violation on celery (part 16) and verified-clean Alloy models on sshd (part 15). No structural catch on Java exists yet.

## The extent: 46 projects, one table

Breadth first, as a count: 39 real-world projects across 30 blinded cleanroom runs (run 22's two packets are constructed, not real-world), 227 packets, 1,084 findings filed — plus 7 projects in the benchmark families below, 46 in all. Every row is one preregistered run; every count is from its frozen `SCORES.json`.

| run | projects | packets | findings | fix matches |
|---|---|---|---|---|
| 6 | [cheroot](https://github.com/cherrypy/cheroot), [pykka](https://github.com/jodal/pykka) | 6 | 44 | 24† |
| 7 | [rpyc](https://github.com/tomerfiliba-org/rpyc) | 8 | 35 | 9† |
| 8 | [tqdm](https://github.com/tqdm/tqdm) | 8 | 32 | 12† |
| 9 | [loguru](https://github.com/Delgan/loguru) | 8 | 40 | 15† |
| 10 | [websockets](https://github.com/python-websockets/websockets) | 6 | 16 | 5† |
| 11 | [python-engineio](https://github.com/miguelgrinberg/python-engineio), [aiokafka](https://github.com/aio-libs/aiokafka) | 8 | 42 | 1 partial |
| 12 | [asyncssh](https://github.com/ronf/asyncssh) | 8 | 27 | 4† |
| 13 | [aiohttp](https://github.com/aio-libs/aiohttp) | 8 | 32 | 5† |
| 14 | [aiormq](https://github.com/mosquito/aiormq), [aio-pika](https://github.com/mosquito/aio-pika) | 8 | 31 | 5 |
| 15 | [kombu](https://github.com/celery/kombu), [huey](https://github.com/coleifer/huey) | 8 | 33 | 0 |
| 16 | [tornado](https://github.com/tornadoweb/tornado) | 8 | 24 | 3 |
| 17 | [waitress](https://github.com/Pylons/waitress), [gunicorn](https://github.com/benoitc/gunicorn) | 8 | 29 | 5 |
| 18 | [dramatiq](https://github.com/Bogdanp/dramatiq) | 7 | 29 | 1 |
| 19 | [stomp.py](https://github.com/jasonrbriggs/stomp.py), [Pyro5](https://github.com/irmen/Pyro5) | 5 | 23 | 4 |
| 20 | [pyftpdlib](https://github.com/giampaolo/pyftpdlib), [urwid](https://github.com/urwid/urwid) | 5 | 16 | 3 |
| 21 | [pebble](https://github.com/noxdafox/pebble) | 8 | 31 | 3 |
| 22 | constructed ×2 (not real-world) | 2 | 10 | 2 |
| 23 | [loky](https://github.com/joblib/loky) | 8 | 31 | 7 |
| 24 | [circuits](https://github.com/circuits/circuits) | 8 | 34 | 5 |
| 25 | [klipper](https://github.com/Klipper3d/klipper) | 6 | 25 | 0 |
| 26 | [parsl](https://github.com/Parsl/parsl) | 8 | 44 | 1 |
| 27 | [frigate](https://github.com/blakeblackshear/frigate) | 8 | 36 | 1 |
| 28 | [rich](https://github.com/Textualize/rich), [redis-py](https://github.com/redis/redis-py) | 8 | 39 | 4 |
| 29 | [gevent](https://github.com/gevent/gevent) | 8 | 32 | 0 |
| 30 | [trio](https://github.com/python-trio/trio), [prompt_toolkit](https://github.com/prompt-toolkit/python-prompt-toolkit) | 8 | 23 | 1 |
| 31 | [ansible-core](https://github.com/ansible/ansible) | 8 | 34 | 5 |
| 32 | [Quartz](https://github.com/quartz-scheduler/quartz), [Ehcache 3](https://github.com/ehcache/ehcache3) | 8 | 30 | 2 |
| 33 | [Log4j 2](https://github.com/apache/logging-log4j2) | 8 | 37 | 0 |
| FR2 | [MINA SSHD](https://github.com/apache/mina-sshd), [celery](https://github.com/celery/celery) | 16 | 141 | 3 pairs* |
| FR3 | [MINA SSHD](https://github.com/apache/mina-sshd), [celery](https://github.com/celery/celery) | 8 | 94 | 4 pairs* |

Three footnotes, all load-bearing. (†) Runs 6–10, 12–13 predate the blind label matcher: their "matches" count touching-findings, an earlier, looser methodology — run 11's single partial is already a matcher verdict. (—) "Findings" are findings filed, deduplicated where the run deduplicated; adjudicated precision varies by run and lives in each run's analysis, not this table. (*) FR-era matches are matcher verdicts on fix/packet pairs (3 of 34, 4 of 12), a stricter denominator than the per-packet recall above.

Beyond the cleanroom, 7 more projects: [kazoo](https://github.com/python-zk/kazoo) (10 reverted fixes: 6 pointed hits, 9 reproduced, 0 FP; 3 unhinted + 4 open; review 6/6), [procrastinate](https://github.com/procrastinate-org/procrastinate) (data-model door: the 2020 defect pre-fix, clean after and at HEAD, 2 planted, 1 control), [asyncpg](https://github.com/MagicStack/asyncpg) (6 temporal fixes, spec loop 6/6 caught), and four directed Java end-to-end runs — [commons-pool](https://github.com/apache/commons-pool) (confirmed), [curator](https://github.com/apache/curator) (uncertain), [resilience4j](https://github.com/resilience4j/resilience4j) (confirmed), [HikariCP](https://github.com/brettwooldridge/HikariCP) (the #591 run behind part 7's probe). Directed waves (R152/R154) and instrument variants (Q1/Q3–Q5, I2/I2G/I2H) revisit projects already counted. That is the extent: 46 projects, two languages, every one named.

## The funnel: where precision actually lives

Read the two precision numbers together, because either alone misleads. A blind sample of 40 Java proposals judged 3 real (7.5%): an unfiltered suggestion list is mostly duds, and the miss autopsy says why — 21 of 22 misses were never proposed at all (visibility-only shapes, single-context code, unframed liveness, one proposal-stage gap). But findings that survive modelling, checking, and confirmation adjudicate real at 89–100% across runs. The tool's precision is in the depth, not the proposer: propose broadly, then falsify strictly. Anyone quoting the 95% without the 7.5% — or the reverse — is selling something.

## What the tool demonstrably misses

The misses are records, not conjectures. Labelled-fix recall at depth runs from 0 of 8 (runs 15 and 33) to 4 of 5 (run 19): fixes the proposer never surfaces (broker-bound state, greenlet and event-loop shapes, GC finalizers, filesystem and JDK-internal state), fixes ranked below the screen or the depth bar, and fixes examined and wrongly falsified. No tester in 24 FR2/FR3 packets ever authored the missing slice from scratch. Wrong-direction verdicts exist in every static run (1 in run 33, 7 in FR2, 6 in FR3) — caller-threading and lock-identity facts dominate the calibration backlog. And the full-reading question was tested twice and lost twice: reading everything finds ~2.5× the real bugs at comparable-or-lower precision, but the adoption rules (own-fix depth, zero wrong-direction) failed both times, so screen-50 stays the default.

## Smaller runs, same discipline

Two instrument experiments on the same sshd/celery trees: prompt+gate authoring held 2/2 filed with 2/2 blind-real (I2H), and the severity-reserve slot engaged friction-free but picked at 2/4 precision, so it stays opt-in (Q5). The tool's own repository guard stands at 283 post-commit reviews with zero `BLOCKING` — and three runs that errored instead of verdicting, counted here, not hidden.

## How to read the next two posts

Parts 15 and 16 are the deep-dives: one Java project, one Python project, each with a fixed issue the tool matched, potential issues it flagged with code, and the misses on the same trees. Read them as exhibits for this post's three sentences — precise at depth, noisy at the surface, demonstrated at the core — with the file drawer open beside them.

{% include series.html %}
