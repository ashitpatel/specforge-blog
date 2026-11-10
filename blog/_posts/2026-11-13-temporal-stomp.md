---
title: "The lost wake-up"
description: "A latent race in the stomp messaging library, found blind from a 2013 tree, matched exactly to the upstream fix, and demonstrated hanging real code — forced, and 10 times in 3,000 unforced trials."
layout: post
series: specforge
date: 2026-11-13
---

*Part 5 of 8 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 4]({% post_url 2026-11-12-feature-log4j %}) flagged a bug at introduction. This one was already there — sitting in dormant code since 2013. Evidence: [`evidence/stomp/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/stomp).*

The tester knew nothing. That is the protocol: a blinded agent receives a tree of the `stomp` messaging library from 2013, before the fix, with no labels and no hints, and is asked to model the riskiest slice and report what the checkers find. Its first finding read, in full:

> *In this tree: send(wait_on_receipt) can block forever: \_\_notify('receipt') notifies before it records the receipt (lost wake-up).*

## The window

The defect fits in two small spans. The sender, in `Connection.send`, holds a condition, sends, then loops (`connect.py:425-434`):

```python
while receipt not in self.__receipts:
    wait()
```

The receiver, in `Connection.__notify`, acquires the condition, notifies, releases (`connect.py:664-666`) — and only *afterwards* records the receipt (`connect.py:668-669`), outside the lock, with no further notify.

If the woken sender reacquires the lock and re-checks the dict inside that window, it finds no receipt and waits again. Nothing ever notifies it. `send()` blocks forever — unless some later, unrelated receipt frame happens to arrive and wake it by accident.

The TLA+ model of the slice found the interleaving; the confirmation step checked it against the code: with the GIL, a thread switch is possible in that window (`release()` is a C call, and the receiver can be switched out when it returns, before line 668). GIL-reachable, not free-threaded-only.

## The match

Blinded testing has a scoring rule: the finding is matched against the upstream fix the tester never saw. The fix for this tree was `de74be6356`, which "moves `self.__receipts[receipt]=None` inside the condition lock before `notify()` in `__notify(receipt`)". The matcher's verdict on finding 0: **exact** — "names exactly this lost wake-up in send/\_\_notify." The tester predicted the fix's content from the pre-fix code alone. (Its other two findings were unrelated to the diff, the record says so, and they matched nothing.)

## The demonstration

A model-level finding is a hypothesis. The adjudicator — an independent pass that re-runs confirmations and re-reads the code — demonstrated this one on real code, on CPython with the GIL:

- **Forced:** holding the receiver just after `release()` hung the sender with the receipt recorded and 2 waits.
- **Unforced:** with nothing forced but a tightened switch interval, **10 of 3,000 trials hung**, each confirmed by assertion (2 waits, receipt recorded).

Ten in three thousand. A test suite passes that. A user with a frozen `send()` does not care that it passes. The adjudication verdict: *real race, GIL-reachable, demonstrated* — with the caveats stated: it needs `wait_on_receipt=True` and a receipt header on `send()`, and the hang lasts only until another receipt frame arrives. Precision about the trigger is part of the verdict, not fine print.

The full adjudication, including the import stand-ins and the simulation setup (a local socket pair, the receiver thread calling what `__receiver_loop` calls), is in [`S1.json`](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/stomp/S1.json); the match table in [`MATCHES-stomp.json`](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/stomp/MATCHES-stomp.json); and the run's predictions, committed before any tester ran, in [`PREREGISTRATION.md`](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/stomp/PREREGISTRATION.md).

## Why this one matters

Three properties make it the series' temporal centerpiece. It was **found blind** — no labels, no fix, the way a user would find it. It **matched the upstream fix exactly** — the model said what the maintainers later did. And it was **demonstrated on real code** — forced and unforced — with the trigger conditions nailed down.

[Part 6]({% post_url 2026-11-14-structural-kombu %}) turns to the other checker: an Alloy counterexample — a different race, in kombu's resource pool — that you read as a snapshot instead of a trace.

{% include series.html %}
