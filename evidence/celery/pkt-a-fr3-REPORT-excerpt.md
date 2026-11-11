# Excerpt: celery-fr3/pkt-a REPORT (findings B5/B6, flush loss + double publish)

Source: the pkt-a tester's first-look report (packet workdir, not in
version control), lines 126–165. Nothing else is changed.

> ### B5. EventDispatcher lost events: append between flush snapshot and clear is wiped unpublished
>
> - Subject: `celery.events.dispatcher.EventDispatcher._outbound_buffer`.
>   Property: `NoLostEvents` — "No lost events: when both callers finish,
>   every event ever buffered is still queued or was published." (catalogue:
>   data-consistency.)
> - Mechanism: `flush` (dispatcher.py:204-205) snapshots (`buf =
>   list(self._outbound_buffer)`) then clears OUTSIDE the mutex. An append
>   (`_publish` :162) landing between snapshot and clear is wiped without
>   ever being published.
> - Check: VIOLATED. Bounds: Threads=2, Instances=1, MaxEvents=8 (MaxEvents=9
>   gives the identical violation and state count).
> - Confirmation `b85c21526e39`: verdict `confirmed`, kind `race` ("with
>   whole calls TLC finds no violation, so the failure needs a thread switch
>   inside a call"). Switch: call `list`, line 204; locks pass. Reasons:
>   none. Assumptions: ghosts `created, nextId, sent` not compared; cpython
>   3.14.6 bytecode switch points; one shared object; sharing assumed yes.
>   depends_on: "Is one `EventDispatcher` object used by several threads at
>   once? [sharing:celery.events.dispatcher.EventDispatcher]" (Q55, open).
>   Branch conditions not checked. Evidence: statically confirmed.
> - Control `EventDispatcherBufferControl` (snapshot+clear merged): HOLDS
>   (31 states, clean; shown able to fail).
> - Spec: `code/celery/.specforge/EventDispatcherBuffer.tla`, cfg
>   `EventDispatcherBuffer.cfg`. Notes: `work/specs/EventDispatcherBuffer.md`.
>
> ### B6. EventDispatcher duplicate publish: concurrent flushes publish every event twice
>
> - Subject: `celery.events.dispatcher.EventDispatcher._outbound_buffer`.
>   Property: `NoDuplicatePublish` — "No duplicate publish: a flush never
>   publishes the same buffered event twice." (catalogue: data-consistency.)
> - Mechanism: two threads both `FlushSnap` the same events, both clear, both
>   publish (dispatcher.py:204-205, outside the mutex).
> - Check: VIOLATED. Bounds: Threads=2, Instances=1, MaxEvents=8 (bound+1 stable).
> - Confirmation `1536570b614b`: verdict `confirmed`, kind `race` (same
>   whole-call reason). Both snap->clear preemptions pass (call `list`,
>   line 204). Same assumptions and depends_on as B5 (Q55, open). Branch
>   conditions not checked. Evidence: statically confirmed.
> - Control: HOLDS (31 states). The snapshot/clear window is the whole defect.
> - Spec: `code/celery/.specforge/EventDispatcherBuffer.tla`, cfg
>   `EventDispatcherBuffer_Dup.cfg`. Notes: `work/specs/EventDispatcherBuffer.md`.

B5 is FR3 MATCHES `celery-fr3/pkt-a` own finding [4]: exact on
`f85031f612` (defect + mechanism). Adjudication: `fr3-C5.json`
(real, race, GIL-reachable). B6's verdict is `fr3-C6.json`
(real, race, GIL-reachable).
