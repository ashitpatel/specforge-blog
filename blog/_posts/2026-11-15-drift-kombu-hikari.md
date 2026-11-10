---
title: "The guard that fires"
description: "Two changes that break guarded properties: a probe that un-fixes HikariCP issue #591 trips the temporal gate with BLOCKING, and a rework of kombu's release breaks the structural golden. Both caught at review time."
layout: post
series: specforge
date: 2026-11-15
---

*Part 7 of 13 in a series on [specforge](https://github.com/ashitpatel/specforge). The series so far: [the gap]({% post_url 2026-11-09-what-tests-cannot-see %}), [the machinery]({% post_url 2026-11-10-how-it-works %}), [greenfield]({% post_url 2026-11-11-greenfield-pool %}), [a guarded feature]({% post_url 2026-11-12-feature-log4j %}), [a temporal catch]({% post_url 2026-11-13-temporal-stomp %}), [a structural catch]({% post_url 2026-11-14-structural-kombu %}). This post closes the loop: what happens when a change breaks a guarded property.*

A spec that nothing re-checks is documentation with delusions. The tool pins every property that held as a *golden*: a later change that flips one from holding to broken is a regression, and the gate says so — `BLOCKING`, with the property named. This post shows the gate firing twice: once temporal, once structural. Both demonstrations are constructed — a deliberate probe, a hand-authored regression — and this post labels them as such, because the mechanism is what's on trial here, and the mechanism either fires or it doesn't.

## Temporal: un-fixing HikariCP #591

The setup is real. HikariCP's connection pool had a race on its statement list, fixed upstream as issue #591: at HEAD, `trackStatement`, `untrackStatement`, and `closeStatements` are all `synchronized` on the connection. The golden property, `FastListTracked`, models the two sharing callers — each step tagged at the function that shares the instance (`ProxyConnection.trackStatement`, `untrackStatement`), a lesson learned the hard way after a container-tagged variant confirmed falsely on the fixed code.

The golden's meaning at approval: the defect is *refuted* on this code — the fix holds, and the baseline guards against the bug coming back. (Goldens on still-broken code mean the opposite: they record open findings, and a fix shows as an FYI. The record states both semantics plainly.)

Then the probe: a throwaway commit, since deleted, that removed `synchronized` from `trackStatement` — un-fixing #591. Run the gate over base versus probe:

```
BLOCKING FastListTracked.tla — golden property FastListTracked.tla (curated)
held before this change and fails now
```

Exit 1. The confirmation behind it is exact about why: on the pre-fix tree the race confirms (one side synchronized, the other not); at fixed HEAD it refutes (both sides hold the monitor). Remove the fix and the verdict flips back — and the gate blocks. The full record, including the false-confirmation episode that taught the tagging lesson, is in [`evidence/hikaricp/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/hikaricp).

## Structural: reworking kombu's release

The setup is [part 6's model]({% post_url 2026-11-14-structural-kombu %}), trimmed to its golden subset: `NoDoubleHold` — a resource is never both queued and checked out — the property that *held* on the base tree. A golden guards only what held.

Then the regression, hand-authored and labeled in the code as `BLOG-DEMO constructed regression`: a rework of `release()` that re-queues the resource but loses the discard from `_dirty`:

```diff
     def release(self, resource):
         if self.limit:
-            self._dirty.discard(resource)
             self._resource.put_nowait(resource)
```

The model is updated to track the head code, and the review runs over both trees. Its verdict on the model (strength details omitted):

```json
"specs": { "code/kombu/.specverify/Resource.als": ["changed pred Op_release"] },
"checks":      { "code/kombu/.specverify/Resource.als": {
                   "outcome": "violated", "violated": "NoDoubleHold" } },
"base_checks": { "code/kombu/.specverify/Resource.als": {
                   "outcome": "clean", "violated": null } },
"breaks": ["NoDoubleHold"]
```

The spec diff in plain words ("changed pred Op_release"), the check at both sides (clean at base, violated at head), and the conclusion: the change **breaks `NoDoubleHold`**. The released resource sits in both sets at once — the exact shape the golden forbids. Base and head trees, both models, and the complete [`review.json`](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/kombu/review.json) are in [`evidence/kombu/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/kombu), reproducible with the engine.

## The honest half

Two labels, kept visible:

- **Both breaks are constructed.** The HikariCP probe was deliberate (it undid a real fix on the real tree, which is why the flip means something — but nobody's commit was actually caught). The kombu regression is hand-authored. What they demonstrate is the mechanism: held-before/fails-now produces a named, blocking verdict. The mechanism fires.
- **The tool's own guard has never fired.** A post-commit hook runs the same review on the specforge repository itself: 259 guarded commits, zero `BLOCKING`. Either the codebase is clean of temporal and structural regressions in that window, or nothing tripped the pinned properties. No accidental fire has been caught yet — and the series won't pretend otherwise.

That closes the loop the series opened: tests sample instances; these models exhaust shapes and interleavings; findings reproduce on real code or they don't ship; and the models stand guard afterwards. One post remains: [the landscape]({% post_url 2026-11-16-landscape %}) — where this all fits among Specula, vericoding, Axiom Math, Imandra, Qodo, Intent Lab, &Truth, Petra, SDD, and the tradition they share.

{% include series.html %}
