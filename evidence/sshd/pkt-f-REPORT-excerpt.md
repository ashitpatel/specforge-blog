# Excerpt: sshd-fr2/pkt-f REPORT (finding 1 + Alloy section)

Source: the pkt-f tester's first-look report (packet workdir, not in
version control). Section headers carry the original line numbers.
Nothing else is changed.

## Lines 28–52 — findings header and finding 1 (timeout NPE)

> ## Findings (bugs)
>
> Conventions: each bug names its spec, property, confirmation id and the exact
> depend-on question. Kind is undetermined on every bug for one reason, quoted:
> "not decided for Java (J4a): the whole-call re-check is Python's". All confirmations
> carry the same not-checked pair, quoted once here: "value flow (queries.flows)
> through calls more than three deep (a flow across a call is never answered no, only
> yes or unknown)" and "which branch of an action the code takes (branches are not
> compared)".
>
> ### 1. Session-timeout reschedule after stop throws NPE on the IO thread
>
> - Spec `TimeoutSchedule`, property `NoNullSchedule` (violated, 9 states; control
>   `TimeoutSchedule_1t` clean). Confirmation `bd44e24299a0`.
> - Code: `AbstractFactoryManager.stopSessionTimeoutListener` cancels and nulls
>   `timeoutListenerFuture`, removes the listener and nulls `sessionTimeoutListener`
>   (lines 517-535), with no lock. A `sessionCreated` already dispatched (the
>   `sessionListeners` set is a `CopyOnWriteArraySet`, so removal does not retract an
>   in-flight callback) then runs `ensureTimeoutScheduled`, which reads the nulled
>   listener into `scheduleAtFixedRate` (line 511): NullPointerException.
> - Trace: `Cancel(closer) -> StopRemove(closer) -> Ensure(io)`.
> - Depends on: "step 1 (1 StopRemove) in callback:java.util and step 2 (2 Ensure) in
>   caller act on one shared object: the facts pair contexts by class, not by instance
>   (T1)".
> - Covers slice sl-187332bff6.

This is FR2 MATCHES `sshd-fr2/pkt-f` own finding [0]: partial on
`c1f31ee7c9` (schedule-vs-stop aspect). Adjudication: `fr2-S28.json`
(real, race).

## Lines 223–238 — verified structural claims (Alloy, not findings)

> ## Verified structural claims (Alloy, not findings)
>
> - `WriteState.als` (ChannelAsyncOutputStream.WriteState): `NoNegativeOrExcess`
>   (toSend stays within [0, totalLength]) and `PendingImpliesProgress` (a pending
>   packet write belongs to an in-progress write) both hold (9 State, 3 Future,
>   4 Int). Falsifiability: the tool's own "drop fact Trace" plus a seeded defect
>   (`work/WriteStateSeed.als`: onWritten without the `length < toSend` guard) that
>   violates `NoNegativeOrExcess` with toSend = -7. Covers slice sl-fa5b4c7a97.
> - `SftpHandles.als` (SftpSubsystem handles, 4-byte mode): `DisjointLiveRecycled`
>   (live and recycled handles disjoint), `ContiguousPool` (together they form
>   [0..M), so the fresh counter never collides) and `FilesAccounted` (every opened
>   file is mapped or closed; none orphaned, none double-mapped) all hold (9 State,
>   9 FVal, 5 Int; the 5 Int scope was needed: scope 4 cannot represent pool size 8,
>   a scope artefact I first misread as a violation). Falsifiability: seeded defect
>   (`work/SftpHandlesSeed.als`: close pushing without the `h != null` guard)
>   violates all three, including a genuine overwrite-orphan. Covers sl-61024df6ab.
