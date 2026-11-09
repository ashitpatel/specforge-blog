# Worked example: a Java connection pool, specified before it exists

Five lines of prose in, a checked spec out: 9 numbered requirements, a TLA+ model of
acquire/release/reaper/shutdown/restart (31K states, no errors), an Alloy model of the
pool structure (capacity proof holds), and 9 acceptance scenarios in plain English.
This folder is the complete, verified output of a real greenfield run — nothing here
is hand-written to look good.

## The input (all of it)

> Connection pool for a Java service. The pool holds up to 32 database connections.
> Threads call acquire() to get a connection and release() to return it. If no
> connection is free, acquire() waits until one is returned. Idle connections past
> 5 minutes are closed and replaced. The pool shuts down cleanly, waiting for
> checked-out connections to come back.

Six elicitation rounds settled what that leaves open (indefinite waits, FIFO to the
longest waiter, any-thread release, grow-to-32-before-waiting, draining-then-down
shutdown, lazy refill after restart). See `requirements.md` for the settled text.

## 15-minute replay

Requirements: Python 3.12+, Java 17+, access to the specforge repo.

```bash
gh release download v0.0.1 -p "*.whl" -O specforge_engine-0.0.1-py3-none-any.whl
python3 -m venv .venv && source .venv/bin/activate
pip install ./specforge_engine-0.0.1-py3-none-any.whl
python replay.py
```

`replay.py` copies this folder to a temp dir and re-runs the arc end to end:
scenario export, Alloy + TLC verdicts, scenario acceptance from the answers file,
the `forge_done` gate, and both tutorial walkthroughs. Expect `# replay GREEN`.

## Why these bounds

`Pool.cfg` checks 2 connections, 2 threads, time 0–3, reap age 2 — not the real
32 connections, hundreds of threads, and 5 minutes. Three reasons, all deliberate:

1. **Small scope finds the bugs.** TLC explores *every* reachable state (31,332 here);
   production sizes are computationally infeasible anywhere. Races, deadlocks, and
   ordering violations manifest at tiny scope — that is the bet exhaustive checking
   has always made.
2. **Full size lives in Alloy.** The 32-boundary is proved at scope 33 in `pool.als`;
   TLA+ carries behavior, Alloy carries size. Neither spec covers everything; together
   they cover the requirements.
3. **Liveness needs fairness, fairly stated.** `WaiterResolves` (every waiter leaves
   the queue: served or dropped) holds only under strong fairness on releases and on
   each waiter's take — strong, not weak, because freed slots appear intermittently,
   never continuously. Two threads already exhibit the barging interleaving that makes
   per-thread fairness necessary; more threads add states, not shapes.

Two things we tried and backed out of, left visible so you don't retry them blind:
weak fairness (imposes nothing here — verified by counterexample) and `SYMMETRY`
(sound for the safety properties, but produces a spurious liveness counterexample;
verified both ways, so the cfg omits it with the reason inline).

## What's here

| file | what it is |
|---|---|
| `requirements.md` | R0–R5 + NFR1–NFR3, the settled prose |
| `Pool.tla` / `Pool.cfg` | behavior spec + checker config |
| `pool.als` | structural spec |
| `scenarios/` | the English contract (`.feature`) + machine form (`.json`) |
| `.specforge/answers.yaml` | every elicited answer, including scenario digests |
| `.specforge/deployment/pool/library.json` | the confirmed deployment model |
| `replay.py` | the 15-minute re-verification |

## Next steps

- Open an agent session here with the specforge server enabled and ask for a
  guided walkthrough of `Pool.tla` (`tutorial_spec`, then side-by-side).
- Change a requirement, re-run the checkers, and watch the gate refuse.
- Read the greenfield guide (`docs/user-manual/greenfield-run.md`) for the full
  flow, then start your own system with one line of prose.
