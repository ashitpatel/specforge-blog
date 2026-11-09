# Pre-registration: clean-room run 19, stomp.py + Pyro5 (2026-10-09)

This record was committed before any tester ran. It follows protocol v2.2 and its addendum: testers and adjudicators are launched as individual agents. The primary recall is own-or-open.

**This run tests:**
- **R61, a second time.** Check-to-use windows span calls. A thread-rule refutation is re-checked over the paused thread's whole path, and is never made when the path cannot be established. Run 18's test was vacuous, because the guard never fired.
- **R66 phases 1, 2 and 4, for the first time blind:**
  - objects shared with a started thread;
  - process contexts and lifecycle facts;
  - signal masks.
- **Round 22:** R64, R65, R67 and R68.

Phase 2 of R48 is not tested here; run 20 (pyftpdlib) is for that.

## Frozen inputs

- **Engine:** tag `cleanroom-run19-v1` (`f3d5094`).
  - 1484 tests pass.
  - Kazoo calibration: 84/84 per-runtime records identical through rounds 22-25.
  - The recorded calls of runs 15-18 are unchanged, apart from dramatiq run-18 pkt-e (round 22, adjudication D4c). See `docs/project/rounds/2026-10-09-round22-results.md` and the R66 design note's results sections.
  - Every packet's `engine/.../confirm.py` was checked equal to the tag.
- **Blindness:**
  - No stomp.py or Pyro5 label, screen or fix existed before the tag.
  - The builders of rounds 22-25 were forbidden to open `benchmarks/candidates/`.
  - R69, the run-20 loop detection, is being built in the working tree during this run. It is not committed, and it is not in any packet.
- **Labels:**
  - `stomp.all.json` (`ebdfd83d…`): 39 candidates, 34 with targets.
  - `pyro5.all.json` (`f17107b0…`): 20 candidates, 19 with targets.

## Screen and selection (rules in `evals/cleanroom/SELECTION.md`, "Run 19 selection")

- **stomp.py:** 6 screened, 0 removed by the security exclusion. 2 are high or medium, fewer than 6, so the reserve rule adds Pyro5.
- **Pyro5:** 6 screened, 0 removed. 3 are high or medium.
- **Deviation (procedural):** Pyro5's screen ran at the same time as stomp.py's, before the reserve rule was known to apply. It was used only because the rule then required it. Had stomp.py yielded 6, it would have been discarded.
- There were no backport groups.
- **All 5 are taken, so this run has 5 packets.** The rule takes the 8 most recent across both, and only 5 exist. The rules name no further reserve.

| packets | seed | evidence policy |
|---|---|---|
| `cleanroom/stomp/pkt-a..b` | 20261029 | a static, b `run_local` |
| `cleanroom/pyro5/pkt-a..c` | 20261030 | a and c static, b `run_local` |

Every `code/` has 0 refs and 0 unreachable objects.

## Measured before pre-registering (target ranks deliberately NOT measured)

| packet | tree | contexts | candidates | questions | project loops | process contexts |
|---|---|---|---|---|---|---|
| stomp a | 2013-08-26 | thread 4, caller 1 | 22 | 4 | 0 | 0 |
| stomp b | 2024-04-12 | thread 1, callback 1, caller 1 | 33 | 8 | 0 | 0 |
| Pyro5 a | 2026-05-30 | thread 19, caller 1 | 178 | 36 | 0 | 0 |
| Pyro5 b | 2020-03-06 | thread 19, caller 1 | 178 | 36 | 0 | 0 |
| Pyro5 c | 2026-05-30 | thread 19, caller 1 | 178 | 36 | 0 | 0 |

- The three Pyro5 trees give identical counts. Their package differs by 119 lines (5164 vs 5283), and most thread contexts come from `examples/`.
- No packet has a process context, so R66b and R66d have little to act on here. R66a (thread starts) can.

**What the selected fixes are,** from the screen's one-line reasons only:
- the heartbeat loop exiting on a shared flag;
- receipts recorded after the waiter is signalled and outside the lock;
- the name server's `remove()` checking a name outside its lock;
- a single-instance check-then-create race;
- a shared disconnect lock held across a user hook.

## Predictions

| id | prediction | threshold |
|---|---|---|
| **P4** | **own-or-open recall** (primary) | **≥ 2/5** |
| P4a | own-fix recall | ≥ 2/5 |
| P1 | proposer recall@10 (own targets) | ≥ 2/5 |
| P2 | a chosen slice covers own or open targets | ≥ 2/5 |
| **P3** | **wrong-direction verdicts** | **= 0** |
| **P30** | **refutations made where the paused thread's path crosses a call or cannot be established** (R61's rule) | **= 0** |
| **P32** | **R61's guard fires at least once** (a would-be refutation becomes `uncertain` with the path reason), so that P30 is not vacuous | reported. **If 0, P30 is recorded as vacuous a second time, not as a pass** |
| P5 | bugs and deterministic defects judged real | ≥ 80% |
| P9 | isolation violations, including the relay flag | = 0 |
| P10 | race labels on findings needing no preemption | ≤ 1 |
| P11 | over-claims | ≤ 1 |
| P22 | reproducibility: one recorded call per packet, re-run with the tester's own inputs (`p22.py`, with the own-record pairing) | every usable call identical |
| P31 | findings whose confirmation depends on a sharing question the code itself answers | reported, each one named |
| P33 | findings whose ranking or confirmation used an R66 fact (start sharing, process, signal) | reported |
| P21 | real unlabelled findings | reported |

**Threshold note:** five packets, so the thresholds are scaled from run 18's 3/7 and 2/7. Four of the five fixes are check-then-act or lock-scope shapes, the kind R61 judges.

## Stopping rules (fixed now)

- **If P3 fails,** the failing verdict's path is diagnosed and fixed before anything else.
- **If P30 fails,** R61's re-check has a gap.
- **If P32 = 0 again,** R61 gets a constructed blind test (a seeded check-then-act across a call in a fresh codebase) rather than a third natural run.

## Deviations during the run

- The parallel Pyro5 screen (above).
