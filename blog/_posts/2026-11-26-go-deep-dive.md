---
title: "caddy, examined: a logger race matched to its fix, and a fatal race upstream fixed later"
description: "Four blind first-looks at the Caddy web server in Go: a passive-logger race matched exactly to its own upstream fix, an admin-server family found three times but stuck below confirmation, a fatal session-ticket race upstream fixed years later — and the two fixes depth never reached."
layout: post
series: specforge
date: 2026-11-11
---

*Part 18 of 18 in a series on [specforge](https://github.com/ashitpatel/specforge). [Part 14]({% post_url 2026-11-22-evidence-overview %}) opened the file drawer. This post reads the Go drawer all the way through: the first project in a third language. Evidence: [`evidence/go/`](https://github.com/ashitpatel/specforge-blog/tree/main/evidence/go).*

*Level L2 · Needs: comfort reading short Go excerpts. One project, file by file.*

Caddy is a Go web server: HTTP apps, reverse proxying, file serving, TLS, an admin API with live config reloads. The tool looked at it four times. Run 35 is a cleanroom experiment that set blinded testers on unlabelled code trees — four caddy packets (plus four on nats-server, the run's other half); each tester session gets one tree, the engine, and the brief. Each blinded, each on a tree fixed before any tester ran, each working static-only — reading code, never running it. That last clause first, because it bounds everything below: caddy verdicts are statically confirmed plus blind-adjudicated, never demonstrated on running code, and the deployment models are unconfirmed guesses at how the code is called, so multi-goroutine sharing is assumed where the verdicts say so. With that stated: the four testers filed nine findings, clustered into five claim groups, every subclaim judged real by a fresh blind adjudicator — one exact own-fix match, one exact open-fix family found three times, and a fatal race upstream would not fix for years.

## The exact match: the logger the fix moved

One packet (pkt-a) sat on an August 2023 tree and filed two confirmed bugs. Its first read, in full:

> *Concurrent requests race writing the shared passive-health-check logger (`reverseproxy.go:1081`): `provisionUpstream` stores a freshly allocated child logger into the shared `h.HealthChecks.Passive.logger` on every call, on the per-request dynamic-upstreams path, with no happens-before edge between concurrent requests.*

The store sits in the per-request path (`reverseproxy.go:1080-1081`):

```go
if h.HealthChecks != nil && h.HealthChecks.Passive != nil {
    h.HealthChecks.Passive.logger = h.logger.Named("health_checker.passive")
```

One reverseproxy `Handler` serves all requests (`ServeHTTP` has a pointer receiver, line 403; requests run on separate goroutines), so two concurrent requests execute that store with no ordering between them — and the `countFailure` path concurrently loads the same field (`healthchecks.go:462,472,487`). The blind matcher — shown the finding and the upstream fix, never the tree — ruled it **exact** on [`936ee918ee`](https://github.com/caddyserver/caddy/commit/936ee918ee00bcdf05d2f44a7fa292c054d64700) ("reverseproxy: Always return new upstreams", August 2023): the commit's second hunk, titled "Fix healthcheck logger race", moves exactly that assignment from per-request `provisionUpstream` to one-time `Provision`. The tester, blind, suggested exactly that direction: *"assign the logger once at provision time instead of per upstream."* The adjudicator judged it real ([verdict](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/go/run35-C2.json)). Keep the tester's own honesty label: the race is genuine but benign-valued — every store writes a fresh, equivalent logger — so it fails `go run -race` without a crash path. The fix landed three days after the packet's tree.

## The open family: an admin race found three times, confirmed zero

The run's most instructive cluster is one the tooling could not finish. Every config load replaces the package-global `localAdminServer` (`admin.go:338`, inside `replaceLocalAdminServer`), but the `Serve` goroutine each load spawns reads that same global with no lock (`admin.go:349`):

```go
localAdminServer = &http.Server{
    ...
}

adminLogger := Log().Named("admin")
go func() {
    if err := localAdminServer.Serve(ln); !errors.Is(err, http.ErrServerClosed) {
```

Reloads serialize against each other (`currentCfgMu`), but nothing stops a second reload's store from landing between the first replace's spawn and its goroutine's read: the first goroutine serves the *second* load's server on the *first* load's listener — one server Served twice concurrently, the older never served. The remote (mutual-TLS) endpoint is the exact twin (`remoteAdminServer`, lines 478/496-497). Three packets on three trees (2021-06, 2021-02, 2021-08) filed it independently — five findings, all adjudicated real ([local](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/go/run35-C3.json), [remote](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/go/run35-C4.json)) — and the matcher scored all five exact on [`a10910f398`](https://github.com/caddyserver/caddy/commit/a10910f3981908424493c043d26dfcb4e5f8dc25) ("admin: Sync server variables", August 2021), which adds the `serverMu` the code now holds. For pkt-d it was the packet's own fix.

Here is the honest limit: all five stayed model-level. The raced state is a Go package global, and the engine index resolves no package-global `@code` symbol, so the confirmations stall at `uncertain` with a documented reason. Found three times, matched exactly, confirmed zero — by a named engine gap, not by doubt about the code. The gap is filed as run 35's load-bearing follow-up; the post counts the matches and the gap together.

## The race upstream fixed years later

The pkt-a tester's second bug, confirmed and adjudicated real with its twin on pkt-b ([verdicts](https://github.com/ashitpatel/specforge-blog/blob/main/evidence/go/run35-C1.json)), is a session-ticket rotation that copies the `configs` map header under `mu` and then iterates the live map *after* unlocking (`sessiontickets.go:140-144`), while `register`/`unregister` add and delete under `mu` (lines 171, 184):

```go
s.mu.Lock()
s.currentKeys = newKeys
configs := s.configs
s.mu.Unlock()
for cfg := range configs {
    cfg.SetSessionTicketKeys(newKeys)
}
```

A mutation landing mid-iteration is a concurrent map iteration and map write — a fatal Go runtime error that crashes the process. The testers traced two real pairings (provision-time register under map-random app order; unload-time unregister racing a rotation delivery) with file and line for each. Upstream fixed it in [`325c244e`](https://github.com/caddyserver/caddy/commit/325c244ea71a645c224afa1d0b46296ed76ef9fd) ("caddytls: fix TLS state races", May 2026) — which holds `s.mu` across the iteration, the testers' own fix direction — on trees the packets predate by three to five years. It was never a label; depth found it anyway. The fix persists at the clone's HEAD, as do the logger and admin fixes.

## The misses on the same trees

Two labelled fixes drew a blank, on the record. Pkt-b's own fix (don't persist the parsed browse template, `e8ae80adca`) sat at scored rank 250; pkt-c's (the round-robin atomic, `ce5a0934a8`) at rank 140 — both far below the top-50 screen no tester looks past. The proposer saw the admin fix's targets at rank 7–12 and the logger fix's at rank 15, and depth converted all of those; it buried the other two where depth never goes. Coverage is not finding, and on caddy the split is exact: everything the screen surfaced, depth judged; everything it buried, depth missed.

Caddy carried four of run 35's seven fix-matching pairs (nats-server the other three) with zero wrong-direction verdicts across the run. The Go drawer holds four more projects — nats-server's fatal map races, badger's memtable wars, go-redis's pool deadlocks, sarama's channel protocols — in the frozen scores behind [part 14]({% post_url 2026-11-22-evidence-overview %}).

{% include series.html %}
