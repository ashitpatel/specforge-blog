---
title: "The commit that Log4j would have flagged"
description: "A real feature commit — 'Removes weak references from LoggerRepository' — run through the change guard: 40 touched symbols, 31 flags, the bug's flag first. It shipped in 2.24.2; users hit it within a week."
layout: post
series: specforge
date: 2026-11-12
---

*Part 4 of 9 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 3]({% post_url 2026-11-11-greenfield-pool %}) specified a system before it existed. This post guards a feature commit to a system with millions of users. Evidence: [`evidence/log4j/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/log4j) and [`evidence/rounds/2026-11-02-MR1-manifestation-reading.md`](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/rounds/2026-11-02-MR1-manifestation-reading.md).*

On November 18, 2024, a Log4j commit titled "Removes weak references from `LoggerRepository`" (`a1dfa853c9`) added a new method, `InternalLoggerRegistry.getLoggers()`. It returned a lazy stream — one that escaped the read lock. The change shipped in 2.24.2, and within a week users were filing `ConcurrentModificationException` reports: `Configurator.setLevel` racing logger creation at application start ([issue #3234](https://github.com/apache/logging-log4j2/issues/3234), then [#3283](https://github.com/apache/logging-log4j2/issues/3283), "was just about to report this"). Report to fix: three weeks.

The question this post asks: if the change guard had reviewed that commit, would it have flagged the bug's slice?

## The guard's path

The rule was fixed before running: use the guard's own code path — export the parent's tree and the commit's tree whole, index each, compute the touched symbols, and report which of the head tree's proposals involve one. No special casing, no peeking at the issue.

For `a1dfa853c9` the numbers came out:

- **40 touched symbols**, yielding **31 flags**;
- the bug's flag — the proposal on `InternalLoggerRegistry.loggerRefByNameByMessageFactory` — placed **1st of 31**, flagged as "writes its state" through `getLoggers`, `computeIfAbsent`, and `hasLogger`;
- the visible bar is 10 or better. The bug's flag headed the list.

The [data file](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/log4j/intro-d.json) carries the full row: pattern track rank 2, first-ten listing headed by the bug's state. The guard would have raised it, in a visible place, on the commit that introduced it — before a single user had reported it.

## The sibling

It wasn't the only one. A second Log4j commit from the same study, `eefca5920c` ("Rewrite date & time formatting"), shared a mutable `StringBuilder` between threads in 2.25.0. Users' timestamps broke and Elasticsearch rejected them; one reporter wrote the sentence that justifies this whole series: *"We cannot reproduce the behavior in a unit test."* Report to fix: four days. The guard's numbers: 305 touched symbols, 3 flags, the bug's flag **2nd of 3** — again through "writes its state."

Two feature commits, two regressions on hot paths, both flagged at introduction, both manifested within months — one within a week.

## The honesty section

Three caveats, all from the record itself:

1. **Today's engine, not the one of the time.** The guard ran with the current engine, which has been tuned on Log4j since. The pattern-track rank of 2 may owe something to that tuning. What the study supports is the *flagging* — "a touched function writes the state" has been in the guard since before the tuning — not the exact ranks. The flag order puts writes-its-state flags first whatever their rank, which is why both bugs came near the top.
2. **Change-triggered flags catch change-introduced bugs.** Both bugs here came in with a change, and the flag works when that's true. It does not work for a latent race sitting in dormant code — which was the case for all four bugs in the study's companion half. Neither half replaces the other.
3. **The bug's own fix played no part.** The guard saw only the introducing commit and its parent — the verdict predates the incident, not the other way round.

That second caveat points at the next post. The guard catches what a change brings in. [Part 5]({% post_url 2026-11-13-temporal-stomp %}) is about what was already there: a race sitting in a messaging library since 2013, found by a tester who knew nothing about it.

{% include series.html %}
