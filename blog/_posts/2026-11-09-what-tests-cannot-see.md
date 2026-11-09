---
title: "What tests cannot see"
description: "Tests check instances: this run, this interleaving, this input. Concurrency and structure bugs live in the interleavings and shapes no test constructs. A series on checking those exhaustively instead."
layout: post
series: specforge
date: 2026-11-09
---

*Part 1 of 7 in a series on [specforge](https://github.com/ashitpatel/specforge), a tool that turns requirements or code into checkable Alloy and TLA+ guardrails. Every example links to its evidence.*

A test suite can pass three thousand times and still miss the bug. In one case this series walks through, a messaging library's `send()` hung forever — but only when two threads interleaved inside a five-line window, which happened in 10 trials out of 3,000. The suite was green. The bug was real, and a user staring at a frozen connection would not have been comforted by the coverage number.

That is the gap this series is about. Tests check *instances*: this input, this timing, this interleaving. Two large families of defect live outside any instance you thought to construct:

- **Temporal defects.** Races, deadlocks, lost wake-ups, ordering violations: the bug is not in any one thread's code but in how threads interleave. The interleaving space is combinatorial, so testing samples it and hopes.
- **Structural defects.** Broken shape invariants: a pool holding more than its limit, a resource both queued and checked out, a reference pointing at a deleted row. The bug is a state no test built, usually because building it requires the same unlucky interleaving as above.

The industry's answer has mostly been *more instances*: more tests, stress runs, fuzzers, chaos engineering. All of them sample. The alternative is to stop sampling and start *exhausting*: write down what the system may do as a precise model, then check every reachable state of that model, at small scope, by machine. A model checker does not run your code three thousand times. It examines every interleaving the model allows — tens of thousands of states in seconds — and either proves the property holds within the bound or hands you the exact trace that breaks it.

That is what specforge does, and this series shows it working. The tool takes requirements in plain prose, or existing code, and builds two kinds of model behind the scenes: an Alloy model of the system's *shapes* (what states are legal) and a TLA+ model of its *behavior* (what interleavings are possible). It checks both, reproduces what it finds against the real code, and then keeps the models as guardrails: every later change is re-checked against them, and a change that breaks a guarded property is flagged at review time.

Five worked examples follow, each with its evidence in this repository:

- [A pool, specified before it exists]({% post_url 2026-11-11-greenfield-pool %}) — five lines of prose in, a checked spec out: the greenfield run, including the questions the tool asked and the acceptance scenarios the user signed.
- [The commit that Log4j would have flagged]({% post_url 2026-11-12-feature-log4j %}) — a real feature commit, run through the change guard: 40 touched symbols, 31 flags, the bug's flag first. It shipped, and users hit it within a week.
- [The lost wake-up]({% post_url 2026-11-13-temporal-stomp %}) — a latent race in a messaging library, found by a tester who knew nothing about it, matched exactly to the upstream fix, and demonstrated hanging on real code.
- [The pool that overfilled]({% post_url 2026-11-14-structural-kombu %}) — the same defect through the structural lens: an Alloy counterexample you can read as a snapshot instead of a trace.
- [The guard that fires]({% post_url 2026-11-15-drift-kombu-hikari %}) — two changes that break guarded properties, one temporal and one structural, both caught at review time.

Before those, the next post walks through [how the tool works]({% post_url 2026-11-10-how-it-works %}): the two checkers, the loop around them, and the methodology that keeps the tool honest — blinded testers, preregistered predictions, and a rule that nothing is called a bug until it reproduces on real code.

## The honest boundaries

Three limits, stated up front because the rest of the series assumes them:

1. **Bounded, not proven.** The checkers exhaust a small scope — two threads, two connections — not production size. The bet, and it is an explicit bet, is that interleaving bugs manifest at tiny scope. Each worked example states what its verdict rests on — the bound, the control, the caveats.
2. **Two defect families.** Temporal and structural. The tool has nothing to say about wrong business logic, bad UX, or slow queries; it checks shapes and interleavings.
3. **A human stays in the loop.** The tool asks questions when requirements are ambiguous, and a person accepts the scenarios that become the contract. The models are precise; deciding what they should say is judgment.

With that said: the bugs in this series are real, the verdicts are the checkers' own, and where a demonstration is constructed rather than found — a deliberate probe, a hand-authored regression — the post says so. On to the machinery.
