# MR1: what made the fixed bugs manifest, from their commits, issues and pull requests (2026-11-02)

Owner (chat, 2026-11-02): "review fixed bugs' comments and bug reports to see if somewhere in the description there are
pointers to what made these candidates manifest themselves as bugs worthy of a fix."

This is a reading, not a count. It covers:
- FH1's four forward-fixed bugs (`2026-11-02-FH1-results.md`);
- run 33's two other ranked-low misses, Log4j c and d. Like the four, these were listed below the screen and fixed
  upstream.

Sources: the upstream commit messages, plus the public GitHub issues and pull requests they name, read with `gh api`.
Nothing was run.

## The six

| bug | rank listed | how it was found | what made it show | report → fix |
|---|---|---|---|---|
| Ehcache [#2447](https://github.com/ehcache/ehcache3/issues/2447) `timeouts` | 63 | filed and fixed the same day by a maintainer | **a configuration plus load**: a tier created with non-default, higher timeouts, a server request arriving between `fetchEntity` and `setTimeouts`, and "slow and/or heavily loaded machines" | same day |
| Quartz [#1349](https://github.com/quartz-scheduler/quartz/issues/1349) `future` | 71 | **code reading** by a user chasing a memory leak ("If all triggers share the same monitor instance then why only `private ScheduledFuture future;` is kept?") | no reported symptom. It needs two auto-interruptible jobs running at once in a plugin few people use | 16 months, mostly waiting for a merge ([PR #1470](https://github.com/quartz-scheduler/quartz/pull/1470)) |
| Log4j [#2073](https://github.com/apache/logging-log4j2/issues/2073) `scheduledFuture` | ~173 | a user's NPE stack trace | **an extreme configuration**: a cron rollover firing every second, "for testing purposes", with appenders created in an endless loop. The first run can start before `setScheduledFuture`, and it surfaced through `toString()` | 2.6 years. Labelled waiting-for-maintainer; a maintainer-side stress run did **not** reproduce it (1,200 attempts on 2.17.2 and 2.26.0); a first PR ([#3941](https://github.com/apache/logging-log4j2/pull/3941)) stalled, and [#4118](https://github.com/apache/logging-log4j2/pull/4118) landed |
| Log4j Flume `batchEvent` (`5ef4670e7a`) | 350-361 | **another static analyser**: SpotBugs alerts of rank 9 or less, the "scary" category | none reported. The commit says most of those alerts were false positives, and changed this lock anyway | n/a, no report |
| Log4j [#3234](https://github.com/apache/logging-log4j2/issues/3234) (run 33 pkt-d) | 353 | a user's `ConcurrentModificationException`; then more users ([#3283](https://github.com/apache/logging-log4j2/issues/3283), and "was just about to report this") | **a regression on a hot path**: a 2.24.2 refactor (`a1dfa853`) returned a lazy stream that escaped the read lock. `Configurator.setLevel` racing with logger creation at application start | 3 weeks |
| Log4j [#3792](https://github.com/apache/logging-log4j2/issues/3792) (run 33 pkt-c) | 107 | users' broken timestamps, rejected by Elasticsearch | **a regression on a hot path**: the 2.25.0 formatter change shared a mutable `StringBuilder` between threads. Production load: about 20 of 10,000 events a day; "We cannot reproduce the behavior in a unit test" | 4 days |

## The pointers

1. **Recency.** The two bugs fixed fastest (4 days, 3 weeks) were regressions that a recent release had brought in.
   - Many users hit them within weeks, because the code ran on every log call or at every start.
   - The four slow ones sat in code that did not change (FH1b).
   - The same proposal behaves very differently depending on whether its state is new.
2. **Exposure.** Logging core and start-up paths manifest fast. Optional plugins and appenders do not:
   - the Quartz interrupt plugin;
   - Flume;
   - cron rollover.

   The bugs in them were real but sat for years, because few deployments reach them, and fewer at the needed rate.
3. **Configuration and environment shape the timing window.** The reports name what widened or narrowed the race:
   - a cron schedule every second;
   - non-default timeouts;
   - slow or loaded machines;
   - many threads at start-up.

   Two of them are publication or initialisation windows (Ehcache, the cron first run). These manifest at start-up or
   reconfiguration, under load.
4. **A loud consequence gets reported. A silent one is found by reading.**
   - NPE and CME stack traces, and output a downstream parser rejects, produced reports.
   - The Quartz overwrite (a wrong job's monitor cancelled) and the Flume lock had no symptom anyone reported. A
     person reading the code found one; another static tool found the other.
5. **Multiplicity.** Some races need two instances at once: two monitored jobs, or two threads changing levels while
   loggers are created. A deployment with one never sees them.
6. **Even a confirmed race may not reproduce.** The maintainers' reproduction of #2073 failed, and the reporter of #3792
   could not reproduce it in a unit test. Fixes were made from the reasoning and the stack trace, which supports
   judging candidates statically.

## What could be measured statically

These are candidate signals only, not built and not scored.

| pointer | a static measure | in the engine today |
|---|---|---|
| recency | age of the last change to the state's writers; whether the state is new since the last release tag | N1 flags state that is "new with this change" in review; no age term in the score |
| exposure | entry-point fan-in: public API methods (or `main`/start-up paths) that reach the writers, per module; whether the module is optional (its own artifact, a plugin) | not built (named in RK1's answer) |
| loud consequence | the access can throw: dereference of a field that may be null, iteration of a collection being mutated | partly: severity (R140, advisory) |
| initialisation window | the object is reachable by another thread (a callback, a scheduled task, a registry) before a field is set | the detector shapes named after RK1 (Ehcache e, Log4j e), not built |
| multiplicity | the state lives in a singleton or plugin instance shared by many tasks | partly: contexts per proposal, flat on large libraries (RK1) |

**A caution on exposure.** Exposure predicts how soon a race manifests, not whether it is real.
- Ranking by it would push the plugin bugs, which were all real, further down.
- Under the owner's preference for false positives, it suits a second ordering (what will hurt soon) better than a
  filter.

**Limits:**
- six bugs, read by one reader;
- the issue text is the reporters' account;
- the Flume change has no report at all.

## MR1b: would the guard have flagged c and d at the commit that introduced them? (prereg)

Owner (chat, 2026-11-02): "Yes, check it".

**The introducing commits**, found by `git log -S` on the state's name:
- c: `eefca5920c` "Rewrite date & time formatting (#3121)", 2024-10-31. It adds
  `InstantPatternThreadLocalCachedFormatter` and its `lastEpochInstantAndBuffer`.
- d: `a1dfa853c9` "Removes weak references from `LoggerRepository` (#3209)", 2024-11-18. It adds
  `InternalLoggerRegistry.getLoggers()`, whose stream escapes the lock.

**Rule (fixed before running).** The guard's own path is used with today's engine (`guard/hook.py`
`touched_section`, G1 and N1):
1. Export the parent's tree and the commit's tree whole (`git archive`), and index each.
2. Compute `touched_symbols(base, head)`.
3. Compute `touched_proposals(head, ..., proposals=<head's proposals>, base_proposals=<parent's>)`.

**The bug's proposal** is any head proposal whose `state` names the bug's field:
- c: `InstantPatternThreadLocalCachedFormatter.lastEpochInstantAndBuffer`;
- d: a field of `InternalLoggerRegistry`.

**Reported for each:**
- whether it is flagged, and how ("writes its state", "in its functions", or "new with this change");
- its place in the guard's order, where 10 or less is visible;
- the number of flags;
- its rank in the head tree.

**Limit:** today's engine, not the one of the time. The bug's own fix is not part of this.

## MR1b results

Script: `tools/dev/mr1/intro.py`. Data: `evals/cleanroom/mr1/intro-c.json` and `intro-d.json`.

| bug | introducing commit | touched symbols | flags | the bug's flag | its place (visible ≤ 10) | its rank in the head tree |
|---|---|---|---|---|---|---|
| c (#3792) | `eefca5920c` (2024-10-31) | 305 | 3 | `lastEpochInstantAndBuffer`, "writes its state" through `formatTo` | **2 of 3** | scored 101 |
| d (#3234) | `a1dfa853c9` (2024-11-18) | 40 | 31 | `loggerRefByNameByMessageFactory`, "writes its state" through `getLoggers`, `computeIfAbsent` and `hasLogger` | **1 of 31** | pattern 2 |

**Both bugs would have been raised, in a visible place, on the commit that introduced them.** The release then
shipped:
- c manifested 8 months later (2.25.0, June 2025);
- d manifested within a week of 2.24.2.

**How this fits with FH1b.** The change-triggered flag works when the bug comes in with a change. That held for both
regressions here. It does not work for a latent race in dormant code, which was the case for all four of FH1b's bugs.
Neither half replaces the other.

**Caution, protocol section 6.** Today's engine has been tuned on Log4j since run 33 (SA1, TG1 and KP1 among others).
- d's pattern-track rank of 2 may owe something to that tuning.
- c's flag needs only "a touched function writes the state". G1 has had that since 2026-10-29, before run 33.

So what this supports is the flagging, not the ranks. The flag order puts the "writes its state" flags first whatever
their rank, which is why both bugs came near the top here.
