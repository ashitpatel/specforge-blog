---
title: "How to talk to the tool"
description: "Prompt craft from a real run: five lines of pool prose, six elicitation rounds, one overridden recommendation, two user pushbacks that changed the product — and how to read what comes back."
layout: post
series: specforge
date: 2026-11-21
---

*Part 13 of 13 in a series on [specforge](https://github.com/ashitpatel/specforge). The finale isn't a verdict — it's the conversation that produces one, reconstructed from the pool run's real record. Evidence: [`evidence/pool/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/pool).*

[Part 3]({% post_url 2026-11-11-greenfield-pool %}) showed what came out of the pool run. This post shows what went in: the actual questions, the answers, the moments the user pushed back — and what they teach about talking to the tool.

## Five lines in, six rounds out

The input was five lines of prose about a connection pool. The tool numbered it R0–R5 and asked what numbering exposed, three questions at a time, each with a recommended default. The six rounds, as they happened:

1. **Wait, Shutdown, Reaper.** How long does `acquire()` wait? What happens to waiters at shutdown? When are idle connections replaced? Answers: indefinitely, rejected, immediately.
2. **Release, Pool size, Drain.** Who may release? Fixed or elastic 32? How long does shutdown wait? Here the user overrode the recommendation — *any* thread may release, not just the acquiring thread. The spec followed the user.
3. **Threads, JVM, Infra.** Hundreds of threads, Java 21, no own infrastructure — the deployment shape, settled in one round.
4. **Flows, Bounds, Survive.** Which flows matter, which bounds apply, what survives a restart. The user deferred time bounds and split survival: config persists, connections refill lazily.
5. **Idle time, Bounds, Phases.** Whole minutes, big enough, draining-then-down — precision on the words the spec would reuse.
6. **Grow, Hold, Hold time.** Grow to 32 before anyone waits, holding-while-waiting allowed, no hold limit.

Plus one question asked with a story: *Maya waits first, Lee second, a connection frees — must Maya get it?* Answer: yes, FIFO to the longest waiter.

The lesson for your first run: terse is fine. Five lines bought six short rounds, not an interrogation — because each round showed its working (the exact requirement text each answer would record) and each default was labeled a guess awaiting approval, never a fact.

## Recommendations are not rails

Round 2 is the exhibit. The tool recommended acquiring-thread-only release; the user picked any-thread release with no note and moved on. Nothing broke, nothing scolded — the spec recorded the user's call. Defaults exist to make answering cheap, not to make disagreeing hard. The day a default gets hard to override is the day the tool starts designing your system instead of you.

## The pushbacks that changed the product

Twice the user stopped the run to question the interaction itself:

- *"Where do names such as Maya come from?"* The FIFO question had introduced two named waiters with no warning. Fair objection: invented characters in a question feel like hidden assumptions. The tool now introduces scenario personae before using them.
- *"How can I seek clarifications? 'None of the above' might do something else."* Also fair: a choice that looks like an exit but behaves like a skip is a trap. The form now reads *None — I need to discuss*, and says plainly that nothing is recorded until understanding is confirmed.

Both fixes shipped the same week. The meta-lesson: when the interaction feels wrong, say so in plain words — that feeling is usually right, and in this project it files itself as a bug.

## Reading what comes back

The run's reports each end in an action, and the pool run hit the classic arc. First `forge_done` reported "9 scenario(s) not yet accepted" — everything else green, the contract unsigned. The user read all nine scenarios, accepted them via the answers file, and the gate closed: `done: true`. The order matters: the tool never signs on your behalf, and the gate never passes unsigned.

The general version, worth memorizing: an `@req` gap means a requirement is modeled nowhere — point at its behavior. A `breaks:` verdict means read the counterexample before touching code. Owed debt is named, not hidden. And "no open questions" is a gate, not a suggestion — skipped questions return, they don't evaporate.

## The series, in one paragraph

Twelve posts showed the machinery, the examples, the neighbors, and the trust point. This one showed the conversation. The whole series reduces to a loop you can run Monday morning: describe the system badly, answer short rounds honestly, override defaults freely, push back on the interaction, read the scenarios before signing, and let the models stand guard afterwards. Don't trust it. Check it. Corrections welcome as issues — this post's own fixes started exactly that way.

{% include series.html %}
