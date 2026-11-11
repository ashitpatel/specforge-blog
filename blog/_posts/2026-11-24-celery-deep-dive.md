---
title: "celery, examined: the flush defect, found unlabelled, then matched"
description: "Twelve blind first-looks at celery: an event-loss race found by ten testers across two runs, matched exactly to its upstream fix, plus a timer race and a structural LimitedSet catch still present at HEAD."
layout: post
series: specforge
date: 2026-11-11
---

*Part 16 of 16 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 15]({% post_url 2026-11-23-sshd-deep-dive %}) read the Java drawer. This post reads the Python one — and closes the series. Evidence: [`evidence/celery/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/celery).*

*Level L2 · Needs: comfort reading short Python excerpts. One project, file by file.*

Celery is a Python task queue: workers, timers, event dispatch, result backends. The tool looked at it twelve times. FR2 and FR3 are two cleanroom experiments that set blinded testers on unlabelled code trees; each tester session — a packet — gets one tree, the engine, and the brief. Eight packets in FR2, four in FR3: each blinded, each on a tree fixed before any tester ran, each working static-only — reading code, never running it. Same bounds as the sshd post: statically confirmed plus blind-adjudicated, never demonstrated, sharing assumed where the verdicts say so. The headline here is the arc across the two runs: a race the tool found seven times before it was a label, then matched exactly three times once it was.

## Found seven times, unlabelled

FR2's four celery fixes were a hub-scheduling race, two Redis races, and an autoscale desync. None of them was the event-dispatcher flush. Seven of the eight testers found the flush loss anyway — packets pkt-a, pkt-b, pkt-d, pkt-e, pkt-f, pkt-g and pkt-h — and all seven verdicts came back real, each reachable under CPython's GIL (an ordinary thread switch fits the window). The mechanism, identical in every packet:

```python
def flush(self, errors=True, groups=True):
    """Flush the outbound buffer."""
    if errors:
        buf = list(self._outbound_buffer)
        self._outbound_buffer.clear()
        with self.mutex:
            for event, routing_key in buf:
                self._publish(event, self.producer, routing_key)
```

while a concurrent publish whose broker write fails appends under the mutex (`_publish`, line 162) — free to land between lines 204 and 205, where the event is in neither the snapshot nor the buffer afterwards. Silently dropped. (Line numbers from the FR3 pkt-a tree; the FR2 September trees carry identical numbers per the [FR2 flush verdict file](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/celery/fr2-C1.json).)

## Matched three times, exactly

FR3 selected a new fix: [`f85031f612`](https://github.com/celery/celery/commit/f85031f61247dae1dcf19ca88cc057edba1534ee) ("don't drop buffered events appended during publish", #10435, July 2026). Its message could be the finding's twin: *"events appended by other threads during the publish were in neither the payload just sent nor the buffer afterwards. They were destroyed silently."* Three packets matched it exactly — pkt-a and pkt-c on the fix's own parent tree (four days before the fix), pkt-b on a tree eleven months older, where the defect was already present. Both reading arms found it independently — arm A, which reads the top-50 ranked suggestions, through its screen (rank 10); arm B, which reads everything, through judgement order (place 9 of 50). The depth story is the method working as designed: `NoLostEvents` violated at Threads=2 — and identically with one more event allowed, so the verdict doesn't hang on the bound — confirmed as a race that needs a thread switch inside a call (whole calls in sequence don't fail), with a merged snapshot-and-clear control that holds. One sharing question stayed open — is one EventDispatcher shared across threads? — and was carried as a dependency, not assumed away.

Now the wrinkle, stated plainly because "exact" needs it. The testers found the **errors-buffer** instance (`_outbound_buffer`, above); the upstream fix repaired the sibling **group-buffer** instance:

```diff
                     batch = list(events)
                     self._publish(batch, self.producer, '%s.multi' % group)
-                    events[:] = []  # list.clear
+                    del events[:len(batch)]
```

Same defect, same mechanism, adjacent lines — the blind matcher's "exact" verdict is on defect+mechanism (it sees findings and fixes, never the trees), and the post claims exactly that, no more. (A later upstream rework, the shutdown-synchronization era, has since moved the errors path under the mutex too; the record doesn't say the race was the reason.) The same window also yields the mirror image — two threads flushing concurrently publish everything twice — adjudicated real alongside the loss.

## Potential issues, still present at HEAD

**Timer double-start**, filed in eight packets across both runs, real every time. `ensure_started` checks, then starts, with no lock (`timer2.py:110-118`):

```python
def ensure_started(self) -> None:
    if not self.running and not self.is_alive():
        if self.on_start:
            self.on_start(self)
        self.start()

def _do_enter(self, meth: str, *args: Any, **kwargs: Any) -> Entry:
    self.ensure_started()
    with self.mutex:
```

`running` is set only inside `run()` by the new thread itself, so it cannot guard the window; two threads sharing one Timer both pass the check and the loser's second `start()` raises `RuntimeError`. The verdicts name live in-tree callers on both sides (worker strategy paths, heartbeat setup) and carry the standard sharing caveat. Unchanged at the clone's October HEAD.

**LimitedSet purge-evicts-live**, the structural catch. This one is single-threaded and deterministic — no race at all, which is why Alloy caught it: `NoPrematureEvict` violated. `discard` pops `_data` but leaves the heap entry (`collections.py:613`); `purge` peeks the heap top and pops whenever the stamp reads expired (`:632-636`); `pop` skips heap entries missing from `_data` and evicts the next *present* item (`:640-647`):

```python
def pop(self, default: Any = None) -> Any:
    """Remove and return the oldest item, or :const:`None` when empty."""
    while self._heap:
        _, _, item = heappop(self._heap)
        try:
            self._data.pop(item)
        except KeyError:
            pass
        else:
            return item
```

A stale expired entry therefore triggers the eviction of a live unexpired item — `add('a',0), discard('a'), add('b',100), purge(now=100)` with `expires=10` evicts unexpired `'b'`. Adjudicated real with no caveats attached, a rarity in these runs. The discard/purge/pop shape is unchanged at HEAD.

## The misses on the same trees

Celery blanked FR2's fix-matching entirely (sshd's mirror image): the hub unlocked-add, both Redis defects, and the autoscale desync matched nowhere in eight packets. FR3's greenlet-drainer hang went 0 for 4. The pattern is systematic, and it matches the kombu/huey run's recall-zero autopsy (run 15): broker-bound state the ranking step never surfaces, event-loop and greenlet shapes it frames as threads, a GC-finalizer re-entrancy no detector covers. Two near-misses sharpen the other edge: a top-50 tester skipped the rank-2 slice covering its labelled fix as weaker, and a full-read survivor covering its labelled fix sat at judgement place 41 of 77, below the bar. Kept but unmodelled — the bar buries keeps, and the record keeps the burials.

## The series, filed

Sixteen posts: the gap, the machinery, five worked examples, the neighbors, the trust point, three deep comparisons, the conversation — and now the file drawer, an overview, and two projects read end to end. The three sentences from part 14 still hold: precise at depth, noisy at the surface, demonstrated at the core. Everything above is checkable from the evidence folders beside the posts. Don't trust it. Check it.

{% include series.html %}
