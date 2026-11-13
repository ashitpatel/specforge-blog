# Excerpt: reactor-core/pkt-h REPORT (header + Bug 2)

Source: the pkt-h tester first-look report (packet workdir, not in
version control). Section headers carry the original line numbers.
Nothing else is changed.

## Lines 1–14 — report header (tree, policy)

Code: `code/` at `5f5435fe8` ([release] Next development version 3.5.9-SNAPSHOT;
previous release 3.5.8). Static only, no person available: every elicitation
question stays open and is listed under "Questions for the person"; worst-case
defaults apply (one object shared across user threads; code-default options).

Deployment: `propose_deployment_model` found no deployment configuration
(`profiles: []` — "no deployment configuration found ... treat it as a library
or ask the person how it is deployed"). All checks ran under `profile="library"`;
every verdict's profile line reads `none; no deployment model: checked as a
single process; multi-instance and crash behaviour are not covered`. The library
model is UNCONFIRMED (no person to confirm it).


## Lines 62–101 — Bug 2 (publishOn double-discard)

- Finding index 1, confirmation `7d058d38f019` (`confirmed`), catalogue
  `data-consistency`.
- Subject: `FluxPublishOn.PublishOnSubscriber` onNext vs cancel. Property:
  `NoDoubleDiscard` — an element offered to the queue is discard-handled at
  most once.
- What breaks: `onNext` offers the element OUTSIDE the WIP guard (line 230) and
  only then calls `trySchedule` (line 237). If `cancel` runs in between, it
  sets cancelled, wins WIP (line 280, 0→1) and clears+discards the queue
  contents including the element (line 288); `onNext`'s `trySchedule` then sees
  WIP≠0 with cancelled set and discards the same element AGAIN through
  dataSignal (lines 297–305). The duplicate discard-hook invocation corrupts
  resource accounting (e.g. double release of a refcounted buffer). The code's
  own comment at lines 286–287 ("discard MUST be happening only ... if there is
  no racing ... guaranteed by the WIP guard") is defeated by the offer
  preceding the WIP increment. The mirror class `PublishOnConditionalSubscriber`
  carries the identical shape (screen survivor sl-f80a9afeff, left unmodelled);
  any fix must cover both.
- Counterexample (`bounded: Instances=1, Threads=3`, profile none as above,
  neighbours: no neighbours; 36 distinct states): `UpCheck(1)` → `UpOffer(1)`
  (queue 0→1) → `CancelCheck(2)` → `CancelSet(2)` (cancelled) → `CancelWip(2)`
  (wip 0→1) → `UpSchedule(1)` (wip 1→2, discards 0→1) → `CancelClear(2)`
  (discards 1→2, queue 1→0).
- Falsifiability: violated on `PublishOnDiscard.tla`; holds on the control
  `PublishOnDiscardControl.tla` (onNext and cancel atomic), checked clean
  (15 states).
- Confirmation assumptions: same three as bug 1. Depends on 5× T1
  one-shared-object assumptions. Same not-checked list. Branch conditions not
  checked.
- My verdict assumptions: non-ASYNC sourceMode, non-fused output, unbounded
  queue (offer succeeds), downstream requested ≥ 1 during setup, no terminal
  signal. `onSubscribe` excluded as setup (queue assigned, lines 187–205,
  before downstream onSubscribe at 207, hence before any concurrent cancel;
  upstream onNext only after `s.request` at 209). Fused-output `poll`/`clear`
  excluded with outputFused=FALSE. `onError`/`onComplete`/`request` excluded
  (single-onNext scenario). The worker's WIP reloop is modelled as a single
  settle (a reloop pass over the then-empty queue changes no modelled state
  except wip, which no later step reads). Initial state read from the code.

