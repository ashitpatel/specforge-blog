---
title: "reactor, examined: precision on a family the tool never trained on"
description: "Eight blind first-looks at reactor-core: 31 of 34 subclaims real, one open partial match, all eight own fixes missed — the adversarial run, with the misses stated plainly."
layout: post
series: specforge
date: 2026-11-13
---

*Part 17 of 17 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 16]({% post_url 2026-11-24-celery-deep-dive %}) filed the series; this post reopens it for one drawer nobody planned: the first codebase family the tool met with no detector history behind it. Evidence: [`evidence/reactor/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/reactor).*

*Level L2 · Needs: comfort reading short Java excerpts. One project, file by file.*

Reactor-core is a Java reactive-streams library: Flux/Mono publishers, sinks, schedulers, operators — lock-free volatile/atomic races across callbacks, a shape no earlier run covered. Run 34 set eight blinded testers on eight of its fixes (#2628–#3707, distinct PRs), frozen engine, static-only, no person to ask. The engine moved from v1 to v2 first: v1 outgrew the 16 GB host on these trees (one packet reached 44 GB), and the bounded v2 completed every packet in minutes. Same bounds as the sshd post: statically confirmed plus blind-adjudicated, never demonstrated, sharing assumed where the verdicts say so. The headline is the split: 31 of 34 subclaims real — and 0 of 8 own fixes matched.

## The repeat offenders

Two defects showed up in five packets each, unanimously real.

**The unicast NPE** (packets pkt-a, pkt-b, pkt-c, pkt-e, pkt-h; 9 of 10 subclaims real). Subscribe publishes `SUBSCRIBED` before it publishes the subscriber (`UnicastManySinkNoBackpressure.java:79` vs `:84`):

```java
if (!STATE.compareAndSet(this, State.INITIAL, State.SUBSCRIBED)) {
    ...
}
this.actual = actual;
```

while an emitter reads the state and dereferences in two steps (`:112`, `:120`), and cancel nulls the field between any two steps (`:97-98`). Three windows, one shape: check-then-act on a volatile field — volatile, so this is not a visibility bug; the window is the check. Ten subclaims across the five packets, nine real. The tenth (pkt-c's tryEmitNext leg) is the falsification working: the demand guard returns `FAIL_OVERFLOW` before the dereference, so as stated it cannot happen.

**The MonoSubscriber double-discard** (packets pkt-a, pkt-b, pkt-c, pkt-g, pkt-h; 5 of 5 real). `complete()` snapshots the state (`Operators.java:1792`), `setValue()` re-reads it mid-call and discards on cancel (`:1936`), and the loop back in `complete()` discards the same value again (`:1809`). Same two reads, same double hook-fire, byte-identical code in two of the five trees. The sibling claim — emit-plus-discard, where cancel's discard races request's emit of the same value — went 3 for 3 alongside it.

## The refutations

Three subclaims came back not real, and all three turn on the same point the testers couldn't see from the inner classes: the serialized-sink wrapper and the reactive-streams contracts rule the interleaving out. A unicast onNext-after-terminal (pkt-b), an EmitterProcessor swallowed error (pkt-c), and the demand-guarded NPE leg above. Two of the three had been *confirmed* by their testers — wrong-direction verdicts, recorded as P3 = 2, both on wrapper/contract grounds the confirmation step never checks. The honest reading cuts both ways: the adjudicators are not a rubber stamp, and the confirmation step has a named blind spot (caller-held and wrapper-held serialization).

## The misses on the same trees

Own fixes: 0 for 8 — a flatMap race, a switchOnFirst rewrite, UsingWhen, FluxGenerate accounting, a synchronized MonoCollect, MonoDelayElement, publishOn, FluxReplay. The testers kept finding *neighbors* of the labelled bugs: pkt-h's publishOn double-discard sits next to its MonoDelayElement fix the way celery's errors-buffer finding sat next to the groups-buffer fix — and, exactly like that case, the blind matcher called the one cross-packet resemblance (pkt-h's finding against the publishOn fix) a **partial**: same operator, same racing pair, different faulty behavior. The proposer saw seven of eight own targets in its top 10 (five at rank 1); the testers' depth budgets went to the repeats above instead. Kept but unmodelled, as before — the record keeps the burials.

## The drawer, filed

Seventeen posts: everything part 16 listed, plus one adversarial drawer — a new family, 8 packets, 29 findings, 31 of 34 subclaims real, precision holding where recall blanked. The three sentences from part 14 hold with an amendment: precise at depth (91%), noisy at the surface (0/8 own recall — the frontier is now the proposer, not the checker), demonstrated nowhere on this rung by design. Everything above is checkable from the evidence folders beside the posts. Don't trust it. Check it.

{% include series.html %}
