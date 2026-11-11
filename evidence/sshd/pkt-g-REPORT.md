# First look: Apache MINA sshd (sshd-fr2/pkt-g)

12 findings: 11 bugs + 1 deterministic defect, all statically confirmed (static-only evidence policy; no person available, so every question below is open and every verdict carries its assumptions). 6 TLA+ control specs hold. 2 structural Alloy models verify. 2 chosen slices falsified at depth by audit. Full screen: 788 proposals, 327 survivors, 10 depth slots.

## What was examined

- Tree: Apache MINA sshd (Java), 1063 files, 0 unparsed, 157 modules. Full clone, no shallowing (see `work/boundary.json`).
- Deployment: `server` profile, UNCONFIRMED, inferred from the `ScpCommandMain` CLI entry point. sshd is really a library; the tool refused to propose a library profile on a Python-oriented heuristic. Verdicts say `server (UNCONFIRMED)`.
- Evidence policy: static only (`bug_requires: statically confirmed`), the default — no person chose otherwise.
- Coverage: every file parsed; depth touched the server channel/command/session, client, agent, common session/crypto, SFTP server subsystems (see `work/firstlook.json` §4).

## Open questions (no person; all unanswered)

- Library-vs-server: is sshd used as an imported library (which entry points, which threads call them)? The server profile stands in.
- F1 options: 7 behaviour-changing options (negotiation toggles, `usePty`, heartbeat, `registerFipsProviders`, `useDefaultSecurityProvider`, `properties`, `ldapEnv`) — none answered; models assume defaults.
- F2 usage/lifecycle: 40 public objects (pools, sessions, channels, factories, agents...); sharing of one object across threads/tasks unanswered for all. Every two-thread confirmation therefore depends on the T1 instance-pairing assumption (quoted per finding).
- F4 progress: 36 wait/end-work operations (close/stop/join/pump/endOfFile...); none answered must-return.
- F5 failure model: 7 failure kinds; best guesses recorded in `work/f45.json`, none confirmed.
- Deployment dimensions: threads, db_engine/isolation/replica_reads, cache, sessions, messaging, failure, rollout, java_runtime — all open.

## Screen and choice

- 690 scored + 74 pattern + 24 structural proposals, all screened blind (41 subagents, <=20 each; verdicts in `work/screen/verdicts-*.json`): 317 first-pass survivors, 471 falsified.
- 48 hashed second reads (3 fresh subagents): 10 overturned to survivor → 327 survivors.
- Budget: 0.15 × 327 capped at `depth_max` 10 → 10 slots. The bar is global across tracks (learned from a refusal). Choice covers global judgement #1–#18 except three skips:
  - #9 sl-57de762fd0 (skip: same SessionHelper setter-staleness shape as #10, weaker cross-thread pair),
  - #10 sl-7ffcc33912 (skip: consequence-2 staleness, slot traded for the corruption-grade #5),
  - #14 sl-d956c37eba (skip: Services-monitor nesting links to the chosen KEX/encode/future pair only via one merged-signal function).
- Chosen: 8 temporal groups (15 proposals, 5 companion pairs/chains) + 2 structural. 309 survivors below the line, owed not clean — nearest: ChannelPipedOutputStream.closed (p3/c2/e2), TcpipServerChannel.connector (p2/c3/e2), AbstractClientChannel.out (proposer rank 1), SftpOutputStreamAsync.buffer, ChannelSession.out/asyncOut (same S1 cluster, weaker members).

## Bugs (statically confirmed)

Shared assumptions on every two-thread confirmation: Java memory model (no GIL, any interleave); ghosts not compared; lock identity by name; T1 instance pairing (quoted per finding as D); branch conditions not checked.

1. **ChannelSession close-vs-request NPE in sendResponse** — `ChannelSession:372` null-checks `commandInstance`, `:400` re-reads and starts it; `closeImmediately0:217` nulls between. NPE on the request thread. Schedule: guard→create→prepare→check→(close begins, snapshots, destroys+nulls)→start. Confirmation `487458815d42`. Catalogue: atomicity. Fix: read once into a local / common close-vs-request lock. Slices sl-f29d2f46c6 (+companions err/asyncErr). D: T1 pairing on all four cross-thread preemptions.
2. **ChannelSession command created after close is never destroyed** — guard passes, close completes, request creates: the command misses both destroy (already ran) and start accounting. Leak. Confirmation `77fbec56cfcd`. Catalogue: interleaving. Same fix direction.
3. **ChannelSession streams created racing close are never closed** — async pair snapshotted null by `getInnerCloseable:140` then created (`:734`); or sync pair created after `closeImmediately0:221` read them. Leak. Confirmation `4fe8b6d2662a`. Catalogue: interleaving. Same fix direction.
4. **AgentImpl concurrent use throws ConcurrentModificationException** — `keys` is a plain ArrayList, mutated by add/remove/removeAll/close and traversed by getKeyPair, no sync. One agent is shared across sessions (`LocalAgentFactory:44,60-63`). Fail-fast traversal + concurrent mutation → CME. Confirmation `1414aed3abf0` (IterBegin; ClearAll). Catalogue: interleaving. Fix: synchronize methods / concurrent list.
5. **AgentImpl addIdentity slips in after close** — `isOpen` check `:106` then `keys.add :113`; close (`getAndSet(false)` + clear `:145-146`) between → key added to a closed agent. Confirmation `7b72df9f2a55`. Catalogue: atomicity. Same fix. (Bound raised 2→3: verdict stable, `AgentImplKeys_Bound3.cfg`.)
6. **SshClient stop-vs-connect NPE in doConnect** — null-check `:658`, use `:665`; close lambda nulls `:496` between. Confirmation `1309b1dcd830`. Catalogue: atomicity. Fix: read once / start-close exclusion.
7. **SshClient factory resurrected after close** — `getIoServiceFactory` has no closed-guard: after close nulls the factory, the lazy getter creates a fresh live one on a closed client (never disposed). Confirmation `d2ba9ec91a35` (close completes, then check+create). Catalogue: interleaving. Confidence note: this is lifecycle (post-close call), not a mid-close race — a create-during-close variant was modelled and holds (the null appears only at close end), so the getter needs a closed-guard, which the control models. Lower severity than the NPEs.
8. **SshServer start-vs-close NPE on acceptor bind** — start creates `:313`, close nulls `:389`, start binds `:340`. Confirmation `c39fed31623a`. Catalogue: atomicity. Fix: start-close exclusion.
9. **ProcessShell destroy-vs-start leaks the OS process** — destroy on a null process is a no-op; start then launches. In-tree path exists: exec guard passes → channel close completes → `sendResponse` starts (no closing check there). Mutual exclusion alone does NOT fix it (either order leaks); start must refuse once destroyed — the control models exactly that and holds, while a lock-only control still violated. Confirmation `450a3f4f1684`. Catalogue: interleaving.
10. **ProcessShell streams wired after destroy escape closing** — destroy closes what exists; start wires after. Confirmation `57acc4344c62`. Catalogue: interleaving. Same fix.
11. **Rekey torn read in public createBuffer** — `setOutputEncoding` swaps outCipher+outCipherSize (+mac pair) under encodeLock; public `Session.createBuffer` reads them unlocked (user thread opening a channel mid-rekey, e.g. `AbstractClientChannel:356`) → new cipher with old size (or reverse) → mis-sized crypto buffer. Confirmation `e25264c28c1f` (write cipher; read cipher; read size; write size). Catalogue: data-consistency. Fix: same lock in the reader (control holds).

## Deterministic defect (statically confirmed)

12. **KEX exchange driven before assignment completes** — `doKexNegotiation` CASes state to RUN, but `kex` is assigned+initialized later on the KEXINIT-write completion (IO thread). A pipelined peer KEX message in between passes RUN validation and drives a null/uninitialized exchange (`handleKexMessage:771`). Single-threaded trace (decode runs fully first), hence deterministic-defect, not bug: fires whenever the message precedes the listener. Confirmation `18833ceb7a9b`. Catalogue: ordering-causality. Assumption: async write completion (sync transports inline the listener). Fix: validate readiness, not just RUN (control holds).

## Depth non-findings

- **T1 WriteState (Alloy, clean).** PendingWrite/writeInProgress coupling + toSend/totalLength bounds hold in all reachable states (6 State, 3 Future, 4 Int; falsifiable by construction). Separately verified: every `writeState` access sits in a `synchronized (writeState)` block. The class is correct; no finding.
- **T2 SftpHandles (Alloy, clean).** Live/recycled disjointness, [0,size) keys with empty deque, and fresh-key uniqueness hold (6 State, 5 Int) — with a load-bearing lifecycle premise: `closeAllHandles` clears handles but not the recycle deque and takes no lock; removing the lifecycle guard from the model reproduces a key collision (States $4–$5 of the scratch check), but in code it runs in the single-run loop finally with no handle op after it. Wart documented, benign. No finding.
- **S7 BaseCipher.secretKey (falsified at depth, no model).** Write-once in `init` (`:122`); `update`/`reInit` only read it. Every init/update call site is under the direction lock: out direction under encodeLock (`doWritePacket:1172` takes it; `setOutputEncoding:727` under `:721`), in direction under decodeLock (`messageReceived:504-517` around `decode` and `handleNewKeys→setInputEncoding`), fresh cipher published under the same lock as its updates. `CipherInformation` is read-only. No second lock, no race — the screen survivor does not survive the call-site audit.
- **P1 KEX/future/encode lock order (falsified at depth, no model).** Full take-site audit of kexLock (read/write), futureLock, encodeLock, decodeLock: kex→encode order is consistent on both paths (`writeOrEnqueue:305` read→encode; `flushQueue:501` write→encode); no `updateState` lambda (8 sites) takes any lock or awaits; futureLock setValue/notifyAll always outside kexLock (`shutdown:207`, flush tail `:534+`, or null-lock/private-monitor futures); `sendNewKeys` deliberately avoids kexHandler under encodeLock (documented `:722-724`); waits (`writeOrEnqueue:353`, `waitFor:287`, `await0`) release while waiting and take no kex lock while holding futureLock. The pattern proposals' merged signals name no realizable cycle (one screen reason cites a nonexistent `requestKeyExchange`). No deadlock; no finding.

## Controls

All six control specs check clean: ChanSessionCloseControl (26 states), AgentImplKeysControl, ClientServerCloseControl (49 states; needs the closed-guard, `@control`-tagged dead action), ProcessShellStartControl (9 states; needs destroyed-flag, lock-only still violated), KexAssignWindowControl (10 states), RekeyTornReadControl (9 states). Every reported property was violated in its main spec (falsifiable) and holds in its control.

## Method notes

- Screen was blinded (no rank/score/signals shown); 10/48 second reads overturned. One lax batch (scored-21, 0/20 falsified) was absorbed: its two top survivors got full depth treatment (one in a confirmed cluster, one falsified).
- TLA+ specs live in `code/<module>/.specforge/` beside the bundles; verdict files and this report's inputs in `work/`. `FRICTION.md` logs every tooling surprise.
