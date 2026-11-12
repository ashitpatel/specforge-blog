---
title: "sshd, examined: the KEX match and the agent that stayed racy"
description: "Twelve blind first-looks at Apache MINA SSHD: a KEX race matched exactly to its upstream fix, a timeout cluster matched in part, agent and process races still present at HEAD — and the fixes depth never reached."
layout: post
series: specforge
date: 2026-11-11
---

*Part 15 of 16 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 14]({% post_url 2026-11-22-evidence-overview %}) opened the file drawer. This post reads one drawer all the way through: the Java half. Evidence: [`evidence/sshd/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/sshd).*

*Level L2 · Needs: comfort reading short Java excerpts. One project, file by file.*

Apache MINA SSHD is a Java SSH library: client and server sessions, channels, key exchange, agents, SFTP. The tool looked at it twelve times. FR2 and FR3 (FR = full read) are two cleanroom experiments that set blinded testers on unlabelled code trees; each tester session — a packet — gets one tree, the engine, and the brief. Eight packets in FR2, four in FR3: each blinded, each on a tree fixed before any tester ran, each working static-only — reading code, never running it. That last clause first, because it bounds everything below: sshd verdicts are statically confirmed plus blind-adjudicated, never demonstrated on running code, and the deployment models are unconfirmed guesses at how the code is called, so multi-threaded sharing is assumed where the verdicts say so. With that stated: testers' findings were clustered into 45 claim groups in FR2 and 53 in FR3, each judged by a fresh blind adjudicator — one exact fix match and three partials across the two runs, plus potential issues you can still read at HEAD.

## The exact match: KEX driven before it exists

One packet (pkt-g) sat on a March 2025 tree and filed twelve findings. Its twelfth read, in full:

> *KEX exchange driven before assignment completes — `doKexNegotiation` CASes state to RUN, but `kex` is assigned+initialized later on the KEXINIT-write completion (IO thread). A pipelined peer KEX message in between passes RUN validation and drives a null/uninitialized exchange (`handleKexMessage:771`).*

The window is three spans. The field is plain (`AbstractSession.java:163`):

```java
protected KeyExchange kex;
```

The state flips to RUN before the field is assigned — `doKexNegotiation` CASes at line 891 and queues the actual initialization as a future listener (lines 918–928), which runs `performKexNegotiation` and only there assigns and inits `kex` (lines 948–949). And the message handler validates the state but not the field (`handleKexMessage`, lines 767–771):

```java
protected void handleKexMessage(int cmd, Buffer buffer) throws Exception {
    validateKexState(cmd, KexState.RUN);
    ...
    if (kex.next(cmd, buffer)) {
```

A pipelined peer KEX message landing between the CAS and the listener passes line 768 and dereferences a null `kex` at line 771. The blind matcher — shown the finding and the upstream fix, never the tree — ruled it **exact** on [`7849e4875d`](https://github.com/apache/mina-sshd/commit/7849e4875d85dced5f26d4b95a09a7f488474692) ("Fix another race condition in KEX", Thomas Wolf, October 2026): *"Same bug, wording differs."* The fix queues `kex.next()` behind a new `kexPreparedFuture` fulfilled only after `kex.init()`. The tester predicted the fix's mechanism from a tree nineteen months older than the fix. The adjudicator judged it real, with two caveats the post keeps: it calls the kind a race where the tester said deterministic defect (single-threaded trace vs. cross-thread race — same window, different framing), and the match is open, not own — it matched a different fix than the packet's labelled one, on a tree where its own fix touched nothing modelled. Depth finds labelled bugs mostly where the rule does not look.

## The partials: a timeout cluster, honestly partial

Three more findings overlap a second fix — and the post labels them partial because the overlap is real but incomplete. Fix [`c1f31ee7c9`](https://github.com/apache/mina-sshd/commit/c1f31ee7c91db471605712ccc158a3a9f40f55b2) ("Avoid race condition when closing a SshClient", January 2026) did two things: an `isOpen()`-guarded scheduling of the session-timeout task, and an AtomicReference rework of its async cancellation. The testers found the first aspect three times, the second never:

- **Session-timeout reschedule after stop throws NPE** (packet pkt-f, on the fix's ancestor tree, three days before it): stop cancels and nulls the timeout future while an in-flight `sessionCreated` reschedules onto the nulled listener — NPE on the IO thread. Spec `TimeoutSchedule`, 9 states, control clean. This was also FR2's only case of a packet's labelled fix reaching depth — entering when the tester swapped it in on a second look.
- **Timeout leak and wrong-cancel** (packet pkt-c): concurrent start/stop leaks the timeout task, and a stop cancels a timeout task scheduled after stop began — restart runs with no monitoring.

The code both sides share (`AbstractFactoryManager`, setup vs. stop, no lock between):

```java
private void ensureTimeoutScheduled() {
    if (timeoutListenerFuture == null) {
        timeoutListenerFuture = getScheduledExecutorService().scheduleAtFixedRate(sessionTimeoutListener, 1, 1,
                TimeUnit.SECONDS);
    }
}
[...cancelSessionTimeout between: cancels and nulls timeoutListenerFuture...]
protected void stopSessionTimeoutListener(AbstractSessionFactory<?, ?> sessionFactory) {
    cancelSessionTimeout();
    ...
    if (sessionTimeoutListener != null) {
        try {
            removeSessionListener(sessionTimeoutListener);
        } finally {
            sessionTimeoutListener = null;
        }
    }
}
```

All three adjudicated real (the [reschedule verdict](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/sshd/fr2-S28.json), the [leak verdict](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/sshd/fr2-S26.json), the [wrong-cancel verdict](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/sshd/fr2-S27.json)). Partial means what it says: the scheduling half, not the AtomicReference half.

A fourth near-miss belongs in this section, framed as what it is. In FR3, one packet, on the 2021 parent of the KEX fix [`c425`](https://github.com/apache/mina-sshd/commit/c425ac53e8df95684563d297cde6101b4db77255), filed a rekey-vs-encode torn read: the IO thread swaps the outbound cipher and size without the encode lock while another thread reads them in two non-atomic steps — new cipher with old size. Adjudicated a real race. The matcher scored it partial on `c425` but wrote the gap plainly: same KEX family, different defect (torn encode read vs. negotiation on a missing proposal). Count it as a same-family catch, not as the fix predicted.

## Potential issues, still present at HEAD

Two clusters the testers found, the adjudicators confirmed, and no fix has touched — verified against the clone's October 30 HEAD, with each verdict's sharing caveat attached.

**The agent races.** `AgentImpl.keys` is a plain `ArrayList`, iterated by `getIdentities` and mutated by `addIdentity`, with no synchronization anywhere in the class (`AgentImpl.java:53–113`):

```java
private final List<Map.Entry<KeyPair, String>> keys = new ArrayList<>();
...
public Iterable<? extends Map.Entry<PublicKey, String>> getIdentities() throws IOException {
    ...
    return GenericUtils.map(keys, kp -> new SimpleImmutableEntry<>(kp.getKey().getPublic(), kp.getValue()));
}
...
public void addIdentity(KeyPair key, String comment, SshAgentKeyConstraint... constraints) throws IOException {
    ...
    keys.add(new SimpleImmutableEntry<>(Objects.requireNonNull(key, "No key"), comment));
}
```

Six packets independently filed the torn iteration (`ConcurrentModificationException`), six filed add-slipping-in-after-close (check at line 106, `close()` flips and clears at 145–146, the add lands at 113 in a closed agent). All twelve verdicts came back real. One agent is shared across sessions via `LocalAgentFactory`, which is the sharing the verdicts assume and the unconfirmed deployment leaves open. The field, the iteration, and the mutation are byte-identical at HEAD.

**The process leak.** `ProcessShell.destroy` no-ops on a null process; `start` assigns it later (`ProcessShell.java:176` vs. `:119`):

```java
public void destroy(ChannelSession channel) {
    ...
    if (process != null) {
        ...
        process.destroy();
    }
```

```java
process = builder.start();
```

If a channel close interleaves after `sendResponse` passes its null check (`ChannelSession.java:372`) but before `builder.start()` returns, destroy sees null while the OS process launches with its only reference dropped: a leaked process. The report's control detail is the exhibit worth quoting: mutual exclusion alone does *not* fix it (either order leaks); start must refuse once destroyed — the control models exactly that and holds, while a lock-only control still violates. Adjudicated real, with the in-tree path (`handleExec` guard → close completes → `sendResponse` starts, no closing check there). The shape persists at HEAD.

## Structural, honestly: verified clean, not caught

No Alloy model caught a defect on sshd, and the post will not manufacture one. What the structural track did is still worth recording: two packets verified WriteState coupling and SFTP handle disjointness clean — ten asserts across the two — each shown able to fail by seeded defect (drop the `length < toSend` guard: `toSend = -7`; drop the `h != null` guard: a genuine overwrite-orphan). And one model flagged what the audit then cleared: remove the lifecycle guard from the SftpHandles model and a key collision reproduces — but in code the clearing runs in a single-run loop finally with no handle op after it, so the wart is documented and benign. Flagged by the model, investigated, cleared: the process working, not over-claiming.

## The misses on the same trees

The same twelve packets missed plenty, on the record. Neither of the other two FR2 sshd fixes matched anywhere: the never-closed IoSession registration and the close-state ordering drew a blank in all eight packets. FR3's stale-future fix went 0 for 4 at depth — even though the static layer covers its location (a two-fix recall benchmark the team keeps as a regression anchor: the stale-future case went from uncovered to covered when the stale-install detector shipped, and the detector fires exactly where the fix lands — two sites on the parent tree, only the Nio2 transport's site remaining after the fix added its recheck, zero on 39 other trees). Covered is not found: the oldest gap in the file drawer, measured again. And six FR2 packets sat on trees where their own labelled fix touched nothing modelled — including pkt-g, which then matched a different fix exactly.

sshd carried FR2's fix-matching entirely (all three matches; celery none) and lost it in FR3 (one partial; celery three exacts). [Part 16]({% post_url 2026-11-24-celery-deep-dive %}) is the mirror: the flush defect the tool found seven times before it was a label.

{% include series.html %}
