---
title: "How it works: two checkers and the loop around them"
description: "Specforge's capabilities in one tour: three doors in, an Alloy model for shapes and a TLA+ model for interleavings, a reproduce-or-it-isn't-a-bug rule, and change guards that keep the models earning their keep."
layout: post
series: specforge
date: 2026-11-10
---

*Part 2 of 12 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 1]({% post_url 2026-11-09-what-tests-cannot-see %}) named the gap: tests sample instances, while concurrency and structure bugs hide in interleavings and shapes no test constructs.*

## Three doors in

The tool meets you where you are. There are three ways to start, and the question is asked once per project:

1. **A new system.** You describe what you want in plain prose — five lines is enough to start — and the tool interviews you about what the prose leaves open, then builds the specs. The worked example is [part 3]({% post_url 2026-11-11-greenfield-pool %}): a connection pool specified before a line of it exists.
2. **A new capability.** You describe a feature for an existing codebase. The tool models the feature's slice of the system and guards the change: the new behavior gets checked, and the old guardrails get re-checked. [Part 4]({% post_url 2026-11-12-feature-log4j %}) runs a real feature commit through this guard.
3. **Existing code.** You point the tool at a codebase and it hunts latent defects: proposing the riskiest slices, modeling them, and confirming what it finds. [Part 5]({% post_url 2026-11-13-temporal-stomp %}) and [part 6]({% post_url 2026-11-14-structural-kombu %}) are two catches from this door.

In all three, the specs stay behind the scenes by default. Your goal is the implementation; the Alloy and TLA+ models are guardrails around the coding, reviewable whenever you want — including through a guided tutorial mode that walks through a spec section by section and maps each variable back to the code it constrains.

## The two checkers

Why two modeling languages? Because they see different things:

- **Alloy sees shapes.** You declare the system's relations — which resources are queued, which are checked out — and assert what must always hold: *a resource is never both queued and checked out*. The solver searches for a snapshot that breaks the claim. When it finds one, the counterexample is a single state you can read at a glance. [Part 6]({% post_url 2026-11-14-structural-kombu %}) is five such snapshots that overfill a pool.
- **TLA+ sees interleavings.** You declare the system's actions — acquire, release, notify, wait — and the checker (TLC) explores every reachable state: every order in which threads can interleave, at small scope. When a property breaks, the counterexample is the exact trace: thread A paused here, thread B ran there, and now the waiter sleeps forever. [Part 5]({% post_url 2026-11-13-temporal-stomp %}) is one of those traces, demonstrated on real code.

The two checkers overlap deliberately. Where both speak about the same defect, they must agree — and their agreement is itself checked. A disagreement between the structural and temporal verdicts would be a finding about the models, not the code.

Small scope deserves a sentence, because it sounds like a cheat. The pool in part 3 is checked with 2 connections and 2 threads, not the real 32 and hundreds. The bet is old and explicit: interleaving bugs are about *shapes of interaction* — two threads racing through one window — and those shapes already appear at the smallest scope that fits them. More threads add states, not shapes. And size itself is not ignored: the 32-boundary the TLA+ model can't afford is proved at full size in Alloy, where counting is cheap. Each checker carries what it's good at.

## The loop: falsify first

A model-level finding is not a bug. It is a hypothesis, and the tool treats it as one. The loop around the checkers exists to kill hypotheses:

1. **Propose.** Static analysis ranks slices of the system by risk — shared state, lock shapes, history — and the riskiest get modeled first.
2. **Model.** Skeleton generators draft the spec's structure from the code (or the prose); the judgment — what the operations mean, what must hold — is authored, then checked.
3. **Check.** The solvers run. A violation comes back with its counterexample; a clean comes back with the bound it held under.
4. **Confirm.** A temporal counterexample is replayed against the real code under a deterministic scheduler that forces the exact interleaving — while a *control* interleaving, threads run one after another, must pass. If the code can't be made to exhibit the trace, the finding stays model-level. If the control fails too, the harness is wrong, not the code.
5. **Record.** Confirmed findings are recorded with their reproduction; unrefuted properties — claims the checkers couldn't break but nothing demonstrated either — don't ship as bugs.

That fourth step is the one that matters most. Demonstrated-or-it-didn't-happen is what separates this from a linter with opinions: [the lost wake-up]({% post_url 2026-11-13-temporal-stomp %}) hung a real sender, on real code, ten times in three thousand unforced trials.

## The guard: specs that earn their keep

A spec written once and never re-checked is documentation with delusions. So every model the tool keeps becomes a tripwire:

- **Change review.** Given the trees before and after a change, the tool diffs the specs in plain words ("changed pred Op_release"), re-checks both sides, and reports what the change *restores* (broken before, holds now — the fix, confirmed) and what it *breaks* (held before, fails now — the regression, caught). [Part 7]({% post_url 2026-11-15-drift-kombu-hikari %}) shows the breaks direction firing twice: once temporal, once structural.
- **Golden properties.** Properties that held are pinned. A later change that violates one blocks — the gate's verdict is `BLOCKING`, with the property named. A post-commit hook runs the same guard on the tool's own repository: 259 guarded commits so far, none blocking, which is the other half of the story told honestly in part 7.

## The methodology that keeps the tool honest

The examples in this series come from benchmark runs with rules borrowed from experimental science, because the author didn't trust his own tool either:

- **Blinded testers.** The agent modeling a slice works from the code alone: no labels, no fix commits, no hints about where the bug is. What it finds, it finds the way a user would.
- **Preregistration.** Predictions are written down before the checkers run — which properties should fail, which should hold — so a surprising verdict can't be quietly redefined as expected.
- **Frozen verdicts.** Once adjudicated, a verdict doesn't change because a later tool version disagrees. Disagreements become new records, not edits.
- **Adjudication.** An independent pass replays the evidence — re-running confirmations, re-reading the code — and verdicts like *real race, demonstrated* are its words, not the tester's.

You can see the shape of this in the evidence: each benchmark run keeps its preregistration, its match table, and its per-claim adjudication files beside each other. The stomp story in part 5 cites all three.

## What it won't do

The boundary from part 1, sharpened: bounded scope, two defect families, a human in the loop. Add one more: the tool needs something to check against. For existing code it needs the code; for a new system it needs your answers — the interview in part 3 is not ceremony, it's where the spec's content comes from. A vague requirement gets a question, not a guess presented as fact. (Where the tool does draft a guess, it labels it one and asks for approval.)

Enough machinery. [Part 3]({% post_url 2026-11-11-greenfield-pool %}) starts from five lines of prose and ends with a checked spec.

{% include series.html %}
