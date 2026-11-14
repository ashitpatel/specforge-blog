# specforge first look: caddy (Go)

- Root: `caddy/pkt-a/code` [absolute path shortened for publication] (commit `d6f86cc`).
- Mode: static only. No code was run; no evidence policy or answers file was written.
- Deployment: `propose_deployment_model` found no deployment configuration and stored no profile. All verdicts below are under `library (UNCONFIRMED)`. The model was not confirmed: no person is available in this setting, so every elicitation-backed question is recorded in "Questions for the person" and the run carried on as the skills say for unanswered questions (worst case for sharing, code defaults, no fairness scaffold).
- Budget (defaults): depth 3, screen 50. Used 2 depth slots; screen verdicts recorded for 85 proposals (top 50 scored, all 24 structural, 11 below-screen floor spot-checks).

## 1. Bugs

Two findings, both accepted by `report_finding` with "statically confirmed" evidence. Kind is "undetermined" from the tool for both ("not decided for Go (G4): the whole-call re-check is Python's"); the race kind stated per finding below is my own analysis, labelled as such.

### Bug 1: concurrent requests race on the shared passive-health-check logger

- Spec: `PassiveLoggerRace.tla`, property `NoConcurAccess` ("the shared passive-health-check logger is never written while another goroutine writes or reads it").
- Check verdict: outcome "violated", violated "NoConcurAccess", detail "Error: Invariant NoConcurAccess is violated", distinct states 6, strength "bounded: Threads=3 | profile: library (UNCONFIRMED): a library; used by: unknown; python runtime: unknown | neighbours: no neighbours".
- Counterexample trace:
  - `start: pc = <<"start", "start", "start">>, PassiveLogger = "L0"`
  - `ReqEnter(1)`: thread 1 enters the Passive block of `provisionUpstream`
  - `ReqEnter(2)`: thread 2 enters the same block while thread 1 is still inside it
- Control: `PassiveLoggerRaceControl.tla` (the store hoisted to provision time; request path never writes) is clean: outcome "clean", detail "no error found", 12 states. So the property is falsifiable and holds once the defect is removed.
- Static confirmation: verdict `confirmed`, id `7d5c0aaf9a37`, evidence "statically confirmed". Assumptions: "Go memory model: no interpreter lock, so any two statements of different goroutines may interleave; a located step (@at) is read between its location and the next, an unlocated one over its whole functions" and "lock identity by name: a lock is one object across the threads, as the model's shared state implies". Open question (depends_on): "step 0 (1 ReqEnter) and step 1 (2 ReqEnter) are reached only from the user's own threads (caller context): this needs two user threads, or processes, acting on one object (the sharing assumption)". Branch conditions not checked.
- What breaks: `provisionUpstream` (modules/caddyhttp/reverseproxy/reverseproxy.go:1081) stores a freshly allocated child logger into the shared `h.HealthChecks.Passive.logger` on every call, and it is called per request on the dynamic-upstreams path (reverseproxy.go:465). One reverseproxy `Handler` serves all requests (`ServeHTTP` has pointer receiver, reverseproxy.go:403; requests run on separate goroutines), so two concurrent requests execute that store with no happens-before edge between them (write/write race). The `countFailure` path concurrently loads the same field to log errors (healthchecks.go:462,472,487), which is the same race as read/write.
- Honest severity: this is a genuine data race, but a benign-valued one: every store writes a freshly allocated, functionally equivalent `*zap.Logger`, so last-writer-wins loses nothing observable, and a reader always loads a valid logger. It will fail `go run -race` and is formally undefined under the Go memory model, but I see no crash or corruption path. Fix direction: assign the logger once at provision time instead of per upstream.
- Kind (my analysis, not the tool's): race. Two goroutines are required; nothing here is reachable single-threaded.

### Bug 2: session-ticket rotation iterates the configs map after releasing its lock

- Spec: `STEKConfigsRace.tla`, property `NoMutateDuringIter` ("while stayUpdated walks the configs map after releasing the lock, nobody adds to or removes from that map").
- Check verdict: outcome "violated", violated "NoMutateDuringIter", detail "Error: Invariant NoMutateDuringIter is violated", distinct states 6, strength "bounded: Threads=2 | profile: library (UNCONFIRMED): a library; used by: unknown; python runtime: unknown | neighbours: no neighbours".
- Counterexample trace:
  - `start: Configs = {"c1"}, MutatedDuringIter = FALSE`
  - `IterStart` (stayUpdated snapshots the map and starts iterating)
  - `MutateAdd` (register adds a config): `Configs: {"c1"} -> {"c1", "c2"}; MutatedDuringIter: FALSE -> TRUE`
- Control: `STEKConfigsRaceControl.tla` (the updater holds `s.mu` across snapshot-plus-iteration) is clean: outcome "clean", detail "no error found", 12 states.
- Static confirmation: verdict `confirmed`, id `a4d8baec9469`, evidence "statically confirmed". The mutating step's write was verified against the code: "step 1 (2 MutateAdd) writes Configs: between its location and the next (modules.caddytls.SessionTicketService.register lines 171-173) modules.caddytls.SessionTicketService.configs is written at modules.caddytls.SessionTicketService.register:171". Assumptions: the Go-memory-model and lock-identity assumptions as in Bug 1, plus "ghost variables not compared to the code". Open question (depends_on): "step 0 (1 IterStart) in thread:modules.caddytls.SessionTicketService.stayUpdated and step 1 (2 MutateAdd) in caller act on one shared object: the facts pair contexts by class, not by instance (T1)". Branch conditions not checked.
- What breaks: `stayUpdated` copies the map header under `mu` and then iterates the live map after unlocking (modules/caddytls/sessiontickets.go:138-144), while `register`/`unregister` add/delete under `mu` (lines 169-172, 183-185). A mutation landing mid-iteration is a concurrent map iteration and map write, which is a fatal Go runtime error ("fatal error: concurrent map iteration and map write") that crashes the process. Two real pairings on one service instance: (a) provision-time `register` (connection policies provision in http App.Provision, app.go:313, after the TLS app's `provision` started the goroutine, tls.go:201; app provision order is map-random, so this needs TLS-first order) vs a rotation delivery; (b) unload-time `unregister` (cleanup funcs run before `SessionTicketService.stop()` in the wrapped cancel, context.go:57-74 with connpolicy.go:245 and tls.go:327-331) vs a rotation delivery. Pairing (b) is the primary mechanism: the old service's rotation goroutine is provably still alive while unregister runs on every config unload.
- Honest severity: fatal class, narrow window. The crash additionally needs a keysChan delivery (rotation event, default every 12h, user-configurable) to land inside the microsecond register/unregister window. Rare per event, but it recurs on every reload times every rotation, and the effect is a process crash, not a stale read. Fix direction: hold `mu` across the snapshot-plus-loop, or copy the map under the lock and iterate the copy.
- Kind (my analysis, not the tool's): race. Two goroutines (rotation loop plus provision/unload) are required.

## 2. Model-level findings

None. Every counterexample produced in this run was statically confirmed (see §1). No finding is left at model level, so there is nothing here that "may be an abstraction artefact".

## 3. Structural weaknesses

From `census_report` (counts are structural weaknesses, not bugs) with the clone boundary quoted alongside, as required:

- Boundary (census): "this tree holds 38 package(s), 164 Go file(s), 38 bundle(s)"; history "none: the Go census reads no history (G3a)"; switch note "Go: no interpreter lock; any two statements of different goroutines may interleave"; 0 unparsed files.
- Boundary (`clone_boundary_report`, Python-oriented, quoted for completeness): "this clone holds 0 modules (0 bundles, 0 packages, 0 files); the full system size is unknown", `python_target` "3.x (no Python 2 evidence found); switch-point analysis assumes CPython 3.12-3.14". This tool does not count Go trees; the census boundary above is the operative one. No `python_target` caveat applies to the Go verdicts.
- Counts: 410 race candidates, 306 sharing questions, 28 execution contexts, 255 unresolved calls; 172 multi-writer attributes, 59 multi-writer states, 400 check-then-act sites, 65 in-process lock sites, 32 workers; 0 import cycles, 0 retries, 0 timeouts, 0 state machines, 0 consumers.
- `not_detected`: "Go: no detector for SQL writes, state machines, retries, timeouts, consumers or in-process state; those counts are 0 by absence, not measured (G3a)". So the zeros above are absence of detectors, not clean bills.
- No deployment mismatches (no profiles were proposed, so there is nothing to mismatch against; the two library questions in §6 stay open).
- Top risk modules (weak prior only): caddyconfig/httpcaddyfile 277.0, modules/caddyhttp 214.0, modules/caddyhttp/reverseproxy 203.0, modules/caddytls 159.0, (default) 109.0.
- Data model (`data_model_check`): refused with "no schema found: no CREATE TABLE in the code or in .sql files (ORM models are not read yet)". Nothing further was checkable at this layer.

## 4. How each slice was chosen

- `propose_slices` returned 410 scored proposals (screen 50, depth budget 3, threshold 1.5), 0 pattern, 0 sequential, and 24 structural proposals. The top-20 default was re-read with `limit: null`.
- Screen: 85 verdicts, recorded via `choose_slices` (`screened=`), all accepted (391/391 eligible accounted, floor quota 5 met with 11 below-screen checks):
  - Top 50 scored: 2 survivors (ranks 15, 16, chosen for depth), 48 falsified. The falsifications cluster into a few mechanisms, each verified by reading the exact writers and their goroutines: setup-before-share (provision/adaptation/caddyfile/one-shot-CLI writes on fresh pre-live objects, e.g. ranks 1, 5, 7-14, 17-19, 22, 24, 26-30, 32-39, 41-44, 46, 47, 50); lock-held (UsagePool upv/up RWMutex, maxLatencyWriter mu, default-logger RWMutex, Handler connectionsMu, caddyauth Cache mu, ranks 4, 20, 21, 45, 55); thread-local copies (NetworkAddress value receivers/parameters, Context value semantics, per-request Replacer/recorder/log-fields, ranks 2, 3, 6, 13, 23, 26, 41, 49); lifecycle-ordered (events Subscribe/Start/Emit, pidfile, ranks 42, 84); shutdown-path stale-read-only with no effect (admin servers, rank 40 and below-screen rank 64); no in-repo writer (networkTypes/RegisterNetwork, configAdapters/RegisterAdapter except init, ranks 25, 28).
  - Below-screen floor spot-checks (ranks 51, 55, 57, 59, 60, 61, 64, 73, 84, 85, 98): all falsified, including the extras the scan surfaced (stopChan ordered by goroutine creation; identityCertCache touched only on the run goroutine under rawCfgMu).
  - All 24 structural: falsified (single co-writing provision method with no partial writer and no invariant; connections/Cache fully locked; UsagePool zero value never constructed; per-request/per-connection confinement; several vacuous: no writers, no state, or no functions).
- A full-tree scan of all 410 proposals for non-setup writers with cross-goroutine contexts found no further runtime-writer candidate stronger than the two survivors (the remaining hits are per-request/confined state in fastcgi, rewrite, headers, encode, and fileserver sorts; the FilterEncoder and basic-auth leads were read and cleared: provision-time write and local-copy mutation respectively).
- Chosen for depth: sl-e2b148d49b (rank 15) and sl-7376080c8e (rank 16): 2 of 3 slots. The third slot was deliberately left unused: the screen produced no third survivor, and the below-screen scan gave no candidate worth stretching the bar for. Slice briefs: `code/.specforge/slices/sl-e2b148d49b.yaml`, `code/.specforge/slices/sl-7376080c8e.yaml`; choice record: `code/.specforge/choices.jsonl`.
- Screen reminder, quoted with the coverage map as required: "scored track: 360 of 410 proposals sit below the screen (screen_slices=50 from default) and were not examined: pass limit=null to read every proposal, name any for depth through choose_slices (own slices, or over_budget_reason past the budget), or raise first_look.screen_slices in .specforge/policy.yaml". A bug buried below the screen is not a clean bill; the 330 remaining below-screen eligible proposals are recorded as owed debt with that reason.

## 5. The specs written

- `code/modules/caddyhttp/reverseproxy/.specforge/PassiveLoggerRace.tla` (+ `.cfg`): Bug 1 main spec (2 request threads + countFailure reader; `NoConcurAccess`).
- `code/modules/caddyhttp/reverseproxy/.specforge/PassiveLoggerRaceControl.tla` (+ `.cfg`): Bug 1 control (store hoisted to provision; property holds).
- `code/modules/caddytls/.specforge/STEKConfigsRace.tla` (+ `.cfg`): Bug 2 main spec (rotation round + register/unregister; `NoMutateDuringIter`).
- `code/modules/caddytls/.specforge/STEKConfigsRaceControl.tla` (+ `.cfg`): Bug 2 control (lock held across iteration; property holds).
- Writer coverage: Bug 1 models the request-time writer `provisionUpstream` and the `countFailure` reader; `Provision`/`UnmarshalCaddyfile` and the provision-time `provisionUpstream` calls run pre-share (sequential `run()`) and are folded into Init as a stated assumption. Bug 2 models `stayUpdated`, `register`, and `unregister` (an unlisted writer: a map delete is a write); `provision` is folded into Init as a stated assumption. No composition spec was owed (`needs_composition: false` on both slices; STEK key sources interact only through delivered keys).

## 6. Questions for the person

No elicitation was possible, so all of these are unanswered; the run used the skills' unanswered-question defaults.

- Deployment (`ask_deployment_question`, profile `library`): which Go toolchain builds this code (version, or 'unknown')? Is this a library, and which applications use it — from several goroutines at once, or one goroutine only? Then `confirm_deployment_model` for the profile used.
- F2 usage/lifecycle (`answer_question`, `usage:<object>` / `lifecycle:<object>`): 44 public objects were listed (top: `modules.caddyhttp.App` covering 64 sharing questions, `modules.caddyhttp.reverseproxy.Handler` covering 40). The two findings rest on sharing assumptions that these answers would settle formally: one reverseproxy `Handler` serving concurrent requests (code reading says yes: pointer-receiver `ServeHTTP`, reverseproxy.go:403), and one `SessionTicketService` shared by its rotation goroutine with the provision/unload goroutine (yes by construction).
- F4 progress (`progress:<op>`): for each of Replacer.Get, Stop, deleteListener.Close, fakeClosePacketConn.Close, fakeCloseQuicListener.Close, caddyevents App.Stop, caddyhttp App.Stop, encode responseWriter Close/Flush, http2Listener.Shutdown, lengthReader.Close, reverseproxy bodyReadCloser.Close, fastcgi client.Get, fastcgi clientCloser.Close, fastcgi streamWriter.Flush, PKI.Stop, TLS.Stop, notClosable.Close, unixConn.Close, unixListener.Close: must it return once called (yes, yes within N seconds, or no)? No fairness was assumed in either spec.
- F5 failure model (`failure:<kind>`): must the code survive worker_kill (guess yes), conn_drop (yes), partition (yes), peer_restart (no), process_restart, hostile_peer, and sigterm (drain/kill/no)? No failure actions were modelled.
- F1 was not asked: "F1 is not asked on Go trees: option values cannot drive specs without guards, and the Go extractor reads none (E8). All findings assume code defaults."

## 7. Confidence

- Bug 1 (passive-logger race): high that the race is real (statically confirmed; the sharing pairing is structural — one Handler pointer, per-request goroutines — and every access is lock-free); low practical severity, as stated (benign-valued stores, valid logger on every read). Main residual risk: none on the mechanism; the consequence assessment is my reading, not a checked claim.
- Bug 2 (STEK configs iteration): high that the code shape is exactly as modelled (statically confirmed, and the mutating write was verified at register:171); medium-high that the window is reachable in production (pairing (b) recurs on every unload; it still needs a rotation delivery inside a microsecond window, which I did not observe — static only). If that delivery lands, the effect is certain (fatal runtime error), not probabilistic.
- Screen: high that the falsified top-50 verdicts hold — each names the locking, phasing, or confinement mechanism with file:line, and three extractor misattributions found along the way were corrected by reading rather than trusted. The known gap is the 330 unexamined below-screen proposals (owed debt), mitigated only by the runtime-writer scan, which is a heuristic, not a verdict.

## 8. Coverage map

The `coverage` tool's output, unedited:

```json
{
 "modules": [
  {
   "bundle": "modules/caddyhttp/reverseproxy",
   "members": [
    "modules/caddyhttp/reverseproxy"
   ],
   "state": "examined",
   "depth": "partial spec",
   "specs": [
    "modules/caddyhttp/reverseproxy/.specforge/PassiveLoggerRace.tla",
    "modules/caddyhttp/reverseproxy/.specforge/PassiveLoggerRaceControl.tla"
   ],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 203.0,
   "modelled_private": [
    "modules.caddyhttp.reverseproxy.Handler.countFailure",
    "modules.caddyhttp.reverseproxy.Handler.provisionUpstream"
   ],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddytls",
   "members": [
    "modules/caddytls"
   ],
   "state": "examined",
   "depth": "partial spec",
   "specs": [
    "modules/caddytls/.specforge/STEKConfigsRace.tla",
    "modules/caddytls/.specforge/STEKConfigsRaceControl.tla"
   ],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 159.0,
   "modelled_private": [
    "modules.caddytls.SessionTicketService.register",
    "modules.caddytls.SessionTicketService.stayUpdated",
    "modules.caddytls.SessionTicketService.unregister"
   ],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "caddyconfig/httpcaddyfile",
   "members": [
    "caddyconfig/httpcaddyfile"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 277.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp",
   "members": [
    "modules/caddyhttp"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 214.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "(default)",
   "members": [
    "(default)"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 22,
   "modelled": [],
   "unmodelled": [
    "APIError",
    "AdminAccess",
    "AdminConfig",
    "AdminPermissions",
    "AdminRoute",
    "BaseLog",
    "Config",
    "ConfigSettings",
    "Context",
    "CustomLog",
    "DiscardWriter",
    "IdentityConfig",
    "LogSampling",
    "Logging",
    "ModuleInfo",
    "NetworkAddress",
    "RemoteAdmin",
    "Replacer",
    "SinkLog",
    "StderrWriter",
    "StdoutWriter",
    "UsagePool"
   ],
   "stale_tags": [],
   "risk": 109.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "caddyconfig/caddyfile",
   "members": [
    "caddyconfig/caddyfile"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 67.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/fileserver",
   "members": [
    "modules/caddyhttp/fileserver"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 41.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddypki",
   "members": [
    "modules/caddypki"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 34.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/logging",
   "members": [
    "modules/logging"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 29.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/caddyauth",
   "members": [
    "modules/caddyhttp/caddyauth"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 25.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/headers",
   "members": [
    "modules/caddyhttp/headers"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 24.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/rewrite",
   "members": [
    "modules/caddyhttp/rewrite"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 17.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/encode",
   "members": [
    "modules/caddyhttp/encode"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 16.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/reverseproxy/forwardauth",
   "members": [
    "modules/caddyhttp/reverseproxy/forwardauth"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 16.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/reverseproxy/fastcgi",
   "members": [
    "modules/caddyhttp/reverseproxy/fastcgi"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 12.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyevents",
   "members": [
    "modules/caddyevents"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 11.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddypki/acmeserver",
   "members": [
    "modules/caddypki/acmeserver"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 11.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "cmd",
   "members": [
    "cmd"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 2,
   "modelled": [],
   "unmodelled": [
    "Command",
    "Flags"
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
   "bundle": "modules/caddytls/distributedstek",
   "members": [
    "modules/caddytls/distributedstek"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 5.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/map",
   "members": [
    "modules/caddyhttp/map"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/caddyhttp/push",
   "members": [
    "modules/caddyhttp/push"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/caddyhttp/templates",
   "members": [
    "modules/caddyhttp/templates"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/caddytls/standardstek",
   "members": [
    "modules/caddytls/standardstek"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "caddytest",
   "members": [
    "caddytest"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 2,
   "modelled": [],
   "unmodelled": [
    "Defaults",
    "Tester"
   ],
   "stale_tags": [],
   "risk": 3.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyevents/eventsconfig",
   "members": [
    "modules/caddyevents/eventsconfig"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 2.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/encode/gzip",
   "members": [
    "modules/caddyhttp/encode/gzip"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 2.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/proxyprotocol",
   "members": [
    "modules/caddyhttp/proxyprotocol"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 2.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/caddyhttp/tracing",
   "members": [
    "modules/caddyhttp/tracing"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 2.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "modules/filestorage",
   "members": [
    "modules/filestorage"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
   "stale_tags": [],
   "risk": 2.0,
   "modelled_private": [],
   "skeletons": [],
   "unparsed_files": [],
   "py2_rewritten": [],
   "file": null,
   "parse_error": null
  },
  {
   "bundle": "caddyconfig",
   "members": [
    "caddyconfig"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 2,
   "modelled": [],
   "unmodelled": [
    "HTTPLoader",
    "Warning"
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
   "bundle": "cmd/caddy",
   "members": [
    "cmd/caddy"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "internal",
   "members": [
    "internal"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "internal/metrics",
   "members": [
    "internal/metrics"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/caddyhttp/encode/brotli",
   "members": [
    "modules/caddyhttp/encode/brotli"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/caddyhttp/encode/zstd",
   "members": [
    "modules/caddyhttp/encode/zstd"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/caddyhttp/requestbody",
   "members": [
    "modules/caddyhttp/requestbody"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/caddyhttp/standard",
   "members": [
    "modules/caddyhttp/standard"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/metrics",
   "members": [
    "modules/metrics"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "modules/standard",
   "members": [
    "modules/standard"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
   "bundle": "notify",
   "members": [
    "notify"
   ],
   "state": "examined",
   "depth": "census only",
   "specs": [],
   "exported": 0,
   "modelled": [],
   "unmodelled": [],
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
  "files": 183,
  "unparsed": 0,
  "py2_rewritten": 0,
  "parsed_directly": 183,
  "unparsed_files": [],
  "py2_rewritten_files": [],
  "note": "every file was parsed"
 }
}
```
