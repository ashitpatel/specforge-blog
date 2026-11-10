---
title: "A pool, specified before it exists"
description: "The greenfield run end to end: five lines of prose about a Java connection pool, six elicitation rounds, a TLA+ model checked over 31,332 states, an Alloy capacity proof, and nine acceptance scenarios."
layout: post
series: specforge
date: 2026-11-11
---

*Part 3 of 13 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 2]({% post_url 2026-11-10-how-it-works %}) toured the machinery. This post runs it from scratch. Evidence: [`evidence/pool/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/pool).*

The input is all of it — five lines of prose:

> Connection pool for a Java service. The pool holds up to 32 database connections. Threads call acquire() to get a connection and release() to return it. If no connection is free, acquire() waits until one is returned. Idle connections past 5 minutes are closed and replaced. The pool shuts down cleanly, waiting for checked-out connections to come back.

Read that again and count what it doesn't say. How long does `acquire()` wait — forever, or a timeout? When a connection frees, which waiter gets it? Can any thread release, or only the one that acquired? What happens to waiters when the pool shuts down? Does the pool start full or empty? Every one of those is a design decision the prose silently defers — and each one shapes the spec.

## The interview

The tool's first act is to number the requirements (R0–R5) and ask about what numbering exposes, three questions at a time, each with a recommended default. Six rounds settled the design:

- **Waits are indefinite** — `acquire()` blocks until a connection returns; shutdown likewise waits indefinitely for checked-out connections to come back.
- **A freed connection goes to the longest waiter** (FIFO), not to whoever grabs first.
- **Any thread holding a handle may release it**, and a thread may wait for another connection while holding one — but releasing a connection that isn't checked out is an error.
- **Grow before waiting**: if the pool holds fewer than 32, `acquire()` opens a new connection; only when all 32 are out does anyone queue.
- **Shutdown passes through draining, then down**; new and waiting acquires during shutdown are rejected.
- **After a restart, config persists but connections refill lazily**, as threads call `acquire()`.

The settled text lives in [`requirements.md`](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/pool/requirements.md): R0–R5 plus three non-functional requirements (hundreds of threads, single-process library, restart semantics). Every answer is also recorded in the answers file beside it, so the run is reproducible from prose plus answers.

Notice what happened: the user never saw a temporal operator. They answered plain questions — *FIFO or any-waiter?* — and the answers became the spec's content. The formality is behind the scenes; the judgment stays with the human.

## The two specs

**Behavior** is a TLA+ model of acquire, release, the idle-connection reaper, shutdown, and restart. The checker config is deliberately small:

```
CONSTANT MaxConns = 2
CONSTANT Threads = {"t1", "t2"}
CONSTANT MaxTime = 3
CONSTANT ReapAge = 2
```

Two connections, two threads, time 0–3 — not 32 connections and hundreds of threads. TLC explores *every* reachable state at that scope: 31,332 states, five invariants (pool shape, waiter shape, idle freshness, clean shutdown, type correctness) and five temporal properties, including `WaiterResolves`: every waiter eventually leaves the queue, served or dropped.

That last property is where the run got interesting. It holds only under **strong fairness** on releases and on each waiter's take — strong, not weak, because freed slots appear intermittently rather than continuously, and a thread can be barged past forever by better-timed rivals. Two threads already exhibit the barging interleaving that makes per-thread fairness necessary; more threads add states, not shapes. Two things the run tried and backed out of are left visible in the folder: weak fairness (verified by counterexample to impose nothing here) and thread symmetry (sound for safety, but produces a *spurious* liveness counterexample — verified both ways, so the config omits it with the reason stated inline).

**Structure** is an Alloy model of the pool's shape, and it carries what TLA+ can't afford: the 32-boundary, proved at full size (scope 33). TLA+ carries behavior, Alloy carries size; neither covers everything, and together they cover the requirements.

## The contract

The run's last artifact is the one the user actually signs: nine acceptance scenarios in plain English, one per requirement-carrying action, each the shortest behavior that ends with it:

```gherkin
@R1 @R3
Scenario: S1 AcquireCreate (R1, R3)
  Given conns = {}
    And held = {}
    And lastError = <<0, "none">>
    [... four more Given lines ...]
  When AcquireCreate("t1")
  Then conns = {1}
    And held = {<<1, "t1">>}
```

The scenarios are generated *from the checked model*, not handwritten — so they can't promise what the spec doesn't do. Accepting them is recorded by digest: the gate re-verifies that the accepted scenarios still match the model, and a model edit that silently changes behavior fails the gate until the scenarios are re-accepted. The English contract and the formal model can't drift apart unnoticed.

## The replay

Everything above re-verifies end to end. `replay.py` copies the folder to a temp dir and re-runs the arc — scenario export, Alloy and TLC verdicts, scenario acceptance from the answers file, the done-gate, both tutorial walkthroughs — and ends with:

```
# replay GREEN
```

Five lines of prose in, a checked spec out: 9 numbered requirements, a 31,332-state behavioral check with no errors, a full-size capacity proof, and 9 acceptance scenarios. Nothing in the folder is hand-written to look good; the replay is the receipt.

[Part 4]({% post_url 2026-11-12-feature-log4j %}) turns the tool on a real feature commit — one that shipped, and that users hit within a week.

{% include series.html %}
