# First look: reactor-core (Java) — run34 pkt-a

Static-only first look (no person available; elicitation refused from shell).
Library profile used throughout; the deployment model is UNCONFIRMED (see below).
Root: `code/` (reactor-core 3.4.15-SNAPSHOT, HEAD `2835f17d`).

## Deployment (UNCONFIRMED)

`propose_deployment_model` found no deployment configuration (0 YAML files, 0
runtime files; library, not a service) and no profiles. Per the skill I used
`profile="library"`; every verdict profile line reads `library (UNCONFIRMED)`.
Open deployment questions (asked of nobody — no person available):

- `library/java_runtime`: which JVM runs this code?
- `library/library_usage`: which applications use it, and how (threads, event loop, one thread)?
- F1 options: `reactor.trace.assembly.fullstacktrace=false`,
  `reactor.bufferSize.x=32`, `reactor.tools.agent.installed=(none)`,
  `reactor.bufferSize.small=256` — modelled at code defaults throughout.
- F2 objects: `FluxSwitchOnFirstStressTest.LLLLLLLLL_Result` (Q1–Q9, test code),
  `ConnectableFlux` (Q10, Q12); residual Q11. Default worst case (shared) assumed.
- F4/F5: no fairness and no failure actions scaffolded (nothing answered); the
  specs below are safety-only, so no fairness was assumed.

## Bugs

### 1. NPE in UnicastManySinkNoBackpressure emit paths when subscribe races emit

`subscribe` publishes `SUBSCRIBED` (CAS at
UnicastManySinkNoBackpressure.java:79) *before* writing `actual` (:84). An
emitter that observes `SUBSCRIBED` in between dereferences a null `actual`:
`tryEmitNext` (:112/:120), `tryEmitError` (:136-143) and `tryEmitComplete`
(:160-167). The same deref breaks if `cancel` nulls `actual` (:97-99) after
an emitter passed its state check. Counterexample (TLC, 143 states):
thread 1 `SubscribeCAS`, thread 2 `EmitErrorRead` + `EmitErrorCAS` reaching
`emiterrorderef` with `actual = 0`.

- Property: NoNPE (`UnicastNoBP.tla`, Threads=3, Instances=1). Bounds,
  profile line and neighbours: `bounded: Instances=1, Threads=3 | profile:
  library (UNCONFIRMED): a library; used by: unknown; java runtime: unknown;
  Instances = 1 | neighbours: no neighbours`.
- Confirmation `7f0cd3207fc0`: verdict `confirmed` ("statically confirmed").
  Assumptions: Java memory model interleaving (J7b); lock identity by name.
  Open questions (depends_on): the caller and pool threads act on one shared
  object (T1 instance-sharing; the facts pair contexts by class, not by
  instance). Kind: undetermined for Java (J4a: no whole-call re-check).
  Branch conditions not checked.
- Falsifiability: violated here; `UnicastNoBPControl.tla` (write-before-CAS
  subscribe + snapshot-checked emitters) holds its adapted property over
  1718 states.

### 2. Late subscriber to error-terminated DirectProcessor completes instead of erroring

`tryEmitError` publishes `TERMINATED` (getAndSet at DirectProcessor.java:178)
*before* writing the plain field `error` (:184). A subscriber whose `add()`
observes `TERMINATED` and returns false (:250) then reads `error` (:256) and,
when the read lands before the :184 write, calls `onComplete` instead of
`onError` — a lost terminal error. Counterexample (TLC, 8 states): thread 1
`EmitTerm`, thread 2 `SubCASFail` reaching `subread` with `error = 0`.
Same shape (model-level; the facts reach those methods from no execution
context, so only the DirectProcessor instance confirms): SinkEmptyMulticast
(:80/:85), SinkOneMulticast.tryEmitError (:41/:46) and tryEmitValue (:57/:62,
empty completion instead of the value), SinkManyBestEffort (:167/:173) and
NextProcessor.dispose (:339/:341). Contrast: EmitterProcessor.error is
volatile, and NextProcessor.tryEmitError writes before publishing.

- Property: LateSeesError (`DirectLateError.tla`, Threads=2, Instances=1).
  Bounds, profile line and neighbours: `bounded: Instances=1, Threads=2 |
  profile: library (UNCONFIRMED): a library; used by: unknown; java runtime:
  unknown; Instances = 1 | neighbours: no neighbours`.
- Confirmation `c9363eead6bd`: verdict `confirmed` ("statically confirmed").
  Assumptions: Java memory model interleaving (J7b); lock identity by name.
  Open questions: caller/pool threads act on one shared object (T1).
  Kind: undetermined for Java (J4a). Branch conditions not checked.
- Falsifiability: violated here; `DirectLateErrorControl.tla` (error stored
  before the TERMINATED publish) holds LateSeesError over 16 states.

### 3. MonoSubscriber double-discard when cancel races complete

`complete(v)` stores `v` via `setValue` (Operators.java:1820/:1934-1940)
and, when its state CAS fails after a concurrent `cancel`, falls into the
cancelled branch that discards `v` again (:1807-1811) — while `cancel`
(:1760-1765) already discarded the value it read. Three interleavings: (a)
setValue-discard + loop-discard (shown below); (b) store, cancel takes and
discards, loop-discard; (c) store, request flips the state, deliver path
while cancel takes the stored copy. For ref-counted values (e.g. ByteBuf)
this is a double release. Counterexample (TLC, 101 states): `CompReadNRNV`,
cancel `CancReadNull`/`CancNullN`/`CancSetN`, `CompSetCanc` (discard 1),
`CompReadOther` (discard 2). Subclass cancels (MonoCollect, MonoCollectList)
share the read-then-discard shape while `complete()` takes no lock.

- Property: NoDoubleDiscard (`MonoSubValue.tla`, Threads=3, Instances=1).
  Bounds, profile line and neighbours: `bounded: Instances=1, Threads=3 |
  profile: library (UNCONFIRMED): a library; used by: unknown; java runtime:
  unknown; Instances = 1 | neighbours: no neighbours`.
- Confirmation `5d777a10ab40`: verdict `confirmed` ("statically confirmed").
  Assumptions: Java memory model interleaving (J7b); ghost variables
  (`discarded`, `delivered`) not compared to the code; lock identity by
  name. Open questions: caller/pool threads act on one shared object (T1).
  Kind: undetermined for Java (J4a). Branch conditions not checked.
- Falsifiability: violated here; `MonoSubValueControl.tla` (atomic takes +
  stored-aware deliver) holds both properties over 123 states.

### 4. MonoSubscriber delivers a value cancel already discarded

`request`'s deliver path (Operators.java:1901-1909: CAS to HAS_REQUEST_HAS_
VALUE, read `value`, deliver) races `cancel`'s read-null-discard
(:1760-1765): cancel reads the stored value and releases it while request
delivers the same object downstream — use-after-discard. Counterexample
(TLC, 175 states): complete stores + CAS-wins, `ReqReadNRHV`/`ReqCASWin`,
`CancReadV`, `ReqDelSome` (delivers), `CancNullV`/`CancSetV`/`CancDiscV`
(discards).

- Property: NoDeliverAndDiscard (`MonoSubValue.tla` under
  `MonoSubValue_Deliver.cfg`, Threads=3, Instances=1). Bounds, profile line
  and neighbours: `bounded: Instances=1, Threads=3 | profile: library
  (UNCONFIRMED): a library; used by: unknown; java runtime: unknown;
  Instances = 1 | neighbours: no neighbours`.
- Confirmation `175a56e24ba0`: verdict `confirmed` ("statically confirmed").
  Assumptions: Java memory model interleaving (J7b); ghosts not compared;
  lock identity by name. Open questions: one shared object (T1). Kind:
  undetermined for Java (J4a). Branch conditions not checked.
- Falsifiability: violated here; the same `MonoSubValueControl.tla` holds
  this property too (123 states).

## Model-level findings

None: every counterexample confirmed statically. (The SinkEmptyMulticast /
SinkOneMulticast / SinkManyBestEffort / NextProcessor.dispose instances of
bug 2's shape are reported inside bug 2 as same-shape, model-level: the
facts reach those methods from no execution context, so no confirmation was
possible there; they are not separate findings.)

## Structural weaknesses (census — not bugs)

Boundary (`clone_boundary_report`): "this clone holds 19 modules (14 bundles,
0 packages, 468 files); the full system size is unknown"; full history
available; no missing imports; no unparsed files; `python_target`: "n/a: Java
(no interpreter lock)"; switch note: "Java: no interpreter lock; any two
statements of different threads may interleave".

Counts (`census_report`): 455 files indexed; 745 check-then-act sites (729 in
`reactor.core.publisher`); 325 multi-writer attributes; 155 in-process lock
sites; 686 concurrency candidates over 9 contexts (1 caller + 8 scheduler
worker/pool threads); 12 sharing questions; 1726 unresolved calls; 1 import
cycle (`reactor.core` → `reactor.core.publisher` → `reactor.core.scheduler` →
`reactor.util` → `reactor.util.concurrent` → `reactor.util.retry`); 0
mismatches. No detector on Java for SQL writes, state machines, retries,
timeouts, consumers or in-process state (those counts are 0 by absence, C1J).

Module risk is dominated by `reactor.core.publisher` (1564.0), then
`reactor.core.scheduler` (46.0) and `reactor.core` (21.0).

## How the slices were chosen

`propose_slices` returned 685 scored + 19 pattern + 0 sequential + 30
structural proposals (history from 2324 non-merge commits; thread-safety
intent read for 261 classes). Budget: `depth_slices=3`, screen at top 10% per
track, floor 50 (scored depth 69). Everything in screen was read: 69 scored +
19 pattern + 30 structural = 118 verdicts (10 scored / 1 pattern / 5
structural survivors; the rest falsified with reasons, recorded via
`choose_slices`). 616 scored proposals below the screen were not examined
(one `below_screen_reason` covers them as owed debt: open, not clean).

Chosen (3 slots):

- Rank 1 `sl-8e5f56c546` (`Operators.MonoSubscriber.value`, score 13.498):
  cancel-vs-complete double-discard, verified by direct reading
  (Operators.java:1760-1765 vs 1790-1825).
- Rank 14 `sl-3d6b64954c`
  (`UnicastManySinkNoBackpressure.actual`, score 10.6): check-then-deref NPE,
  verified by direct reading (UnicastManySinkNoBackpressure.java:79-84 vs
  112-120/141-143/165-167).
- Own slice `own-c2b1826288` (cross-class late-subscriber wrong-terminal
  signal): `error`/`value` written after the TERMINATED publish in
  SinkEmptyMulticast, SinkOneMulticast, SinkManyBestEffort, DirectProcessor
  and NextProcessor.dispose; both caller chains quoted in the choice record
  with file:line.

Skipped survivors (with reasons in the choice record): ranks 3, 4, 5, 6, 8,
11 (narrower fused-race shapes, post-cancel best-effort delivery, or
metrics-only consequences), rank 15 (next-in-line single-class post-cancel
resurrection), rank 58 (needs a person ruling on whether concurrent
tryEmitNext+tryEmitError is in-contract for EmitterProcessor), pattern rank 1
(single-threaded accounting skew on user-supplier throw), structural ranks 1,
6, 8, 9, 13 (debug-info-only, best-effort Scannable, thread-leak, metrics-path
and lower-confidence shapes). Full per-proposal verdicts: `work/screened.json`
(118 entries) and the choice record in `code/.specforge/slices/choices.jsonl`.

## The specs

- `code/benchmarks/.specforge/UnicastNoBP.tla` (+ `.cfg`, Threads=3): NPE
  spec for the rank-14 slice; property NoNPE.
- `code/benchmarks/.specforge/UnicastNoBPControl.tla` (+ `.cfg`): control
  (write-before-publish subscribe + snapshot checked emitters); NoNPEFixed holds.
- `code/benchmarks/.specforge/MonoSubValue.tla` (+ `.cfg` Threads=3, +
  `MonoSubValue_Deliver.cfg`): double-discard / deliver-and-discard spec for
  the rank-1 slice; properties NoDoubleDiscard, NoDeliverAndDiscard.
- `code/benchmarks/.specforge/MonoSubValueControl.tla` (+ `.cfg`): control
  (atomic takes + stored-aware deliver); both properties hold.
- `code/benchmarks/.specforge/DirectLateError.tla` (+ `.cfg`, Threads=2):
  lost terminal error spec for the own slice, represented by
  DirectProcessor (the SinkEmptyMulticast instance has the identical shape
  but the facts reach its methods from no execution context, so it cannot
  confirm); property LateSeesError.
- `code/benchmarks/.specforge/DirectLateErrorControl.tla` (+ `.cfg`):
  control (error written before TERMINATED publish); LateSeesError holds.

## Questions for the person

- Deployment: JVM version/distribution? Which applications use the library,
  from how many threads (F2 objects above, residual Q11)?
- F1: do you set any listed option to a non-default value?
- Sharing: is one sink/subscription shared across user threads (the T1
  instance-sharing assumption behind each confirmation)?
- Is concurrent tryEmitNext+tryEmitError in-contract for EmitterProcessor
  (rank 58), or must callers serialize per Reactive Streams rule 1.3?
- F4/F5: must any close/stop/drain operation return; which failures must the
  code survive? (Safety-only run: nothing was assumed.)

## Confidence

- Bug 1 (unicast NPE): high. Plain check-then-deref across two volatiles with
  a genuinely empty window (subscribe publishes before writing); the
  counterexample is a 4-step, two-thread schedule with no subtle
  precondition beyond two threads sharing one sink (T1, open).
- Bug 2 (lost terminal error): high for the mechanism (write-after-publish
  of a plain field, no happens-before edge), medium for observability: the
  window is a few instructions wide, so it needs precise timing or a weak
  memory model (ARM) to bite; the in-codebase contrast (volatile error in
  EmitterProcessor, write-before-publish in NextProcessor) supports it.
- Bugs 3-4 (double-discard / deliver-and-discard): high for the mechanism
  (three distinct violating interleavings fall out of one small spec, and
  the setValue-then-loop double discard needs no second value in flight);
  consequence severity depends on the value type (benign for plain objects,
  double-release for ref-counted ones).
- All four rest on T1 (two threads, one shared object) and on non-fused
  operation where stated; fused paths were not modelled.

## Coverage map

```json
{
 "modules": [
  {
   "bundle": "reactor.core+reactor.core.publisher+reactor.core.scheduler+reactor.util+reactor.util.concurrent+reactor.util.retry",
   "members": [
    "reactor.core",
    "reactor.core.publisher",
    "reactor.core.scheduler",
    "reactor.util",
    "reactor.util.concurrent",
    "reactor.util.retry"
   ],
   "state": "examined",
   "depth": "partial spec",
   "specs": [
    "benchmarks/.specforge/DirectLateError.tla",
    "benchmarks/.specforge/DirectLateErrorControl.tla",
    "benchmarks/.specforge/MonoSubValue.tla",
    "benchmarks/.specforge/MonoSubValueControl.tla",
    "benchmarks/.specforge/UnicastNoBP.tla",
    "benchmarks/.specforge/UnicastNoBPControl.tla"
   ],
   "exported": 69,
   "modelled": [],
   "unmodelled": [
    "BaseSubscriber",
    "BoundedElasticSchedulerBlockhoundTest",
    "BufferOverflowStrategy",
    "CompositeDisposableHashcodeBenchmark",
    "ConditionalStressSubscriber",
    "ConnectableFlux",
    "CorePublisher",
    "CoreSubscriber",
    "DirectProcessor",
    "Disposable",
    "Disposables",
    "EmitterProcessor",
    "Exceptions",
    "Flux",
    "FluxConcatMapNoPrefetchStressTest",
    "FluxMergeStressTest",
    "FluxMetricsFuseableTest",
    "FluxMetricsTest",
    "FluxOperator",
    "FluxProcessor",
    "FluxSink",
    "FluxSwitchMapStressTest",
    "FluxSwitchOnFirstConditionalStressTest",
    "FluxSwitchOnFirstStressTest",
    "Fuseable",
    "GroupedFlux",
    "Hooks",
    "Logger",
    "Loggers",
    "Metrics",
    "MetricsTest",
    "Mono",
    "MonoDelayStressTest",
    "MonoDelayUntilStressTest",
    "MonoInnerProducerBaseStressTest",
    "MonoMetricsFuseableTest",
    "MonoMetricsTest",
    "MonoOperator",
    "MonoProcessor",
    "MonoSink",
    "MonoUsingWhenStressTest",
    "NonBlocking",
    "Operators",
    "ParallelFlux",
    "Queues",
    "ReactorBlockHoundIntegration",
    "ReactorBlockHoundIntegrationSPITest",
    "ReactorBlockHoundIntegrationTest",
    "ReplayProcessor",
    "Retry",
    "RetryBackoffSpec",
    "RetrySpec",
    "Scannable",
    "Scheduler",
    "Schedulers",
    "SchedulersMetricsTest",
    "Signal",
    "SignalType",
    "SinkEmptySerializedStressTest",
    "SinkManyBestEffortStressTest",
    "SinkManySerializedStressTest",
    "SinkOneSerialized",
    "SinkOneSerializedStressTest",
    "Sinks",
    "StressSubscriber",
    "StressSubscription",
    "SynchronousSink",
    "Timed",
    "UnicastProcessor"
   ],
   "stale_tags": [],
   "risk": 1564.0,
   "modelled_private": [
    "reactor.core.publisher.DirectProcessor.subscribe",
    "reactor.core.publisher.DirectProcessor.tryEmitError",
    "reactor.core.publisher.Operators.MonoSubscriber.cancel",
    "reactor.core.publisher.Operators.MonoSubscriber.complete",
    "reactor.core.publisher.Operators.MonoSubscriber.request",
    "reactor.core.publisher.Operators.MonoSubscriber.setValue",
    "reactor.core.publisher.UnicastManySinkNoBackpressure.cancel",
    "reactor.core.publisher.UnicastManySinkNoBackpressure.request",
    "reactor.core.publisher.UnicastManySinkNoBackpressure.subscribe",
    "reactor.core.publisher.UnicastManySinkNoBackpressure.tryEmitComplete",
    "reactor.core.publisher.UnicastManySinkNoBackpressure.tryEmitError",
    "reactor.core.publisher.UnicastManySinkNoBackpressure.tryEmitNext"
   ],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor",
   "members": [
    "reactor"
   ],
   "state": "examined",
   "depth": "partial spec",
   "specs": [
    "benchmarks/.specforge/DirectLateError.tla",
    "benchmarks/.specforge/DirectLateErrorControl.tla",
    "benchmarks/.specforge/MonoSubValue.tla",
    "benchmarks/.specforge/MonoSubValueControl.tla",
    "benchmarks/.specforge/UnicastNoBP.tla",
    "benchmarks/.specforge/UnicastNoBPControl.tla"
   ],
   "exported": 3,
   "modelled": [],
   "unmodelled": [
    "AssemblyTraceBenchmark",
    "CheckpointBenchmark",
    "TailCallBenchmark"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.core.scrabble",
   "members": [
    "reactor.core.scrabble"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 4,
   "modelled": [],
   "unmodelled": [
    "ShakespearePlaysScrabble",
    "ShakespearePlaysScrabbleOpt",
    "ShakespearePlaysScrabbleParallelOpt",
    "ShakespearePlaysScrabbleRegular"
   ],
   "stale_tags": [],
   "risk": 6.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.tools.agent",
   "members": [
    "reactor.tools.agent"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 3,
   "modelled": [],
   "unmodelled": [
    "ReactorDebugAgent",
    "ReactorDebugByteBuddyPlugin",
    "ReactorDebugJavaAgentTest"
   ],
   "stale_tags": [],
   "risk": 4.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "demo",
   "members": [
    "demo"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 1,
   "modelled": [],
   "unmodelled": [
    "SomeClass"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "io.reactor.gradle",
   "members": [
    "io.reactor.gradle"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 2,
   "modelled": [],
   "unmodelled": [
    "DetectCiPlugin",
    "JavaConventions"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "java.lang",
   "members": [
    "java.lang"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 1,
   "modelled": [],
   "unmodelled": [
    "StackWalker"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.adapter",
   "members": [
    "reactor.adapter"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 1,
   "modelled": [],
   "unmodelled": [
    "JdkFlowAdapter"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.core.publisher.tck",
   "members": [
    "reactor.core.publisher.tck"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 6,
   "modelled": [],
   "unmodelled": [
    "AbstractFluxVerification",
    "AbstractProcessorVerification",
    "EmitterProcessorVerification",
    "FluxBlackboxProcessorVerification",
    "FluxGenerateVerification",
    "FluxSwitchOnFirstVerification"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.tools",
   "members": [
    "reactor.tools"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 1,
   "modelled": [],
   "unmodelled": [
    "JarFileShadingTest"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.util.annotation",
   "members": [
    "reactor.util.annotation"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 3,
   "modelled": [],
   "unmodelled": [
    "NonNull",
    "NonNullApi",
    "Nullable"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.util.context",
   "members": [
    "reactor.util.context"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 2,
   "modelled": [],
   "unmodelled": [
    "Context",
    "ContextView"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "reactor.util.function",
   "members": [
    "reactor.util.function"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 8,
   "modelled": [],
   "unmodelled": [
    "Tuple2",
    "Tuple3",
    "Tuple4",
    "Tuple5",
    "Tuple6",
    "Tuple7",
    "Tuple8",
    "Tuples"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "sun.misc",
   "members": [
    "sun.misc"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 2,
   "modelled": [],
   "unmodelled": [
    "JavaLangAccess",
    "SharedSecrets"
   ],
   "stale_tags": [],
   "risk": 0.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  }
 ],
 "parse": {
  "files": 468,
  "unparsed": 0,
  "py2_rewritten": 0,
  "parsed_directly": 468,
  "unparsed_files": [],
  "py2_rewritten_files": [],
  "note": "every file was parsed"
 }
}
```
