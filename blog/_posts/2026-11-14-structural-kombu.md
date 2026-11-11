---
title: "The pool that overfilled"
description: "Kombu's resource pool through the structural lens: a limit check at line 59, the add at line 99, no lock between — and an Alloy counterexample that reads as five snapshots ending in #dirty = 2 > limit 1."
layout: post
series: specforge
date: 2026-11-11
---

*Part 6 of 16 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 5]({% post_url 2026-11-13-temporal-stomp %}) traced a race through time. This post reads one as a snapshot. Evidence: [`evidence/kombu/Resource-full.als`](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/kombu/Resource-full.als) and its [run log](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/kombu/Resource-full.run.log).*

*Level L2 · Needs: part 5 or equal comfort with code. Snapshots, not traces.*

The defect spans forty lines in kombu's `Resource`, a generic pool behind Celery's connections. `_add_when_empty` tests the limit (`resource.py:59`):

```python
if self.limit and len(self._dirty) >= self.limit:
    raise self.LimitExceeded(self.limit)
```

…but `_dirty.add` happens later, in `acquire` (line 99), with no lock in between. With `limit=1`, two threads can both pass the check before either adds: each creates and takes a resource, and the pool holds 2 against a limit of 1. The temporal packet confirmed it as a real, reproduced race — and, just as telling, confirmed the neighboring property *clean*: each resource still goes to exactly one holder. The defect is the limit, not double-checkout.

A later pilot asked whether Alloy could mirror that verdict structurally. It could — `NoOverLimit` counterexample, `NoDoubleHold` holds, no disagreement with TLA+ anywhere both checkers spoke. But the pilot's model texts lived in `/tmp` and were never committed. The record quotes the outcomes; the models themselves are gone. That gap bothered the author enough to repair it for this post: what follows is a regeneration with today's skeleton generator, committed beside the post.

## The regeneration

The generator reads the class and drafts the model's structure: the state fields it holds (`_closed`, `_resource`, `_dirty`), one operation predicate per public method with frame conditions, and a trace fact tying state changes to the operations. The judgment — what the operations *mean* — is authored: `acquire` is split into its check (`Op_add`, the line-59 test plus queueing a fresh resource) and its take (`Op_take`, the line-99 move from queue to checked-out), because the code separates them and the separation is the bug.

Two asserts, preregistered in spirit from the pilot:

- `NoOverLimit`: the pool never holds more checked-out resources than its limit.
- `NoDoubleHold`: a resource is never both queued and checked out at once.

The witness is satisfiable, `NoDoubleHold` holds — and `NoOverLimit` comes back with a counterexample that reads as five snapshots:

```
State$0: _resource = {};                 _dirty = {}
State$1: _resource = {Elem$1};           _dirty = {}
State$2: _resource = {Elem$0, Elem$1};   _dirty = {}
State$3: _resource = {Elem$0};           _dirty = {Elem$1}
State$4: _resource = {};                 _dirty = {Elem$0, Elem$1}
```
(per-state `_closed` values and the trailing signature lines omitted; the [run log](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/kombu/Resource-full.run.log) has the complete instance at `5 State, 2 Thread, 3 Elem`)

Two checks pass while `_dirty` is empty (states 1–2), then two takes land (states 3–4): `#dirty = 2 > limit 1`. No thread schedule to replay, no timing to squint at — the violation is a *shape*, and you can see it sitting there in state 4.

## What the second checker adds

Honestly assessed in the pilot's own record: for these slices, Alloy found nothing TLA+ hadn't — it agreed everywhere. Its value is elsewhere, and this post is the exhibit:

1. **Snapshots beat traces for shapes.** A limit violation *is* a state, and reading it as one takes seconds. Interleaving-shaped defects want traces; relational ones — disjointness, tiling, holder/count consistency — want snapshots.
2. **An independent second checker.** The pilot's stop rule: where both checkers speak, they must agree, and a disagreement is itself a finding about the models. The regeneration reproduces the agreement exactly — counterexample where the race is, holds where the code is clean.

The repaired model is now committed where the pilot's wasn't, which sets up the next post. A model that holds is a tripwire waiting for a change — and [part 7]({% post_url 2026-11-15-drift-kombu-hikari %}) springs two of them.

{% include series.html %}
