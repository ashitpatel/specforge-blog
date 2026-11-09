# J6c: golden properties on the Java benchmarks, from the end-to-end runs (2026-10-29)

Owner (chat, 2026-10-29): "Add Java goldens based on end-to-end runs so far." This settles the choice J6b left open
(`2026-10-28-J6b-java-goldens.md`): the curated specs live outside the clones' history. Static throughout; engine at
`6262cbd` plus T1's uncommitted text changes, which no verdict reads.

**In one sentence:** each Java golden store now holds the property of its end-to-end run, and HikariCP has a store of its
own. HikariCP's golden is a variant tagged at the functions that share the list, because the H run's spec gives a false
"confirmed" on the fixed code. A probe commit that removes the fix is blocked by the gate.

## Where the specs live: a local branch per clone

Each clone has a local branch `specforge-goldens`:
- it is the approved ref plus one commit adding the spec and cfg under `<pkg>/.specverify/`;
- it was built with git plumbing (`read-tree`, `hash-object`, `commit-tree`) on a temporary index, so no working
  tree or checked-out branch changed;
- it is not upstream and is never pushed.

| clone | base ref | branch commit | pkg | property |
|---|---|---|---|---|
| `benchmarks/java/commons-pool` | `rel/commons-pool-2.13.1` | `837402de` | `src/main/java` | `BaseGenericObjectPoolEvictionIterator` (J3a) |
| `benchmarks/java/curator` | `apache-curator-5.9.0` | `d72d9a1c` | `curator-recipes` | `InterProcessMutexSession` (J3b) |
| `benchmarks/java/resilience4j` | `v2.4.0` | `2047329` | `resilience4j-circuitbreaker` | `CircuitBreakerHalfOpen` (J3c) |
| `benchmarks/java/hikaricp` | `a4d93f4f` (HEAD) | `d868334d` | `src/main/java` | `FastListTracked` (below) |

Only the main spec and cfg were added. The control cfgs stay with the runs. Resilience4j's `.specverify` also holds
`CircuitBreakerHalfOpenHarness.java`, which was left out: a `.java` file under the package would be read as project
code.

## The approval

1. **`golden_review`** with `accept`, in-process, at `specforge-goldens`.
2. **`golden_approve`** at the same ref, which re-snapshots the slices with the accepted property. The stores are in
   `~/projects/benchmarks/java/goldens/`.

| store | slices | property | verdict at approval | sha256 prefix |
|---|---|---|---|---|
| `commons-pool.json` | 16 | `BaseGenericObjectPoolEvictionIterator` | confirmed | `41da07f9cab81bf1` |
| `curator-recipes.json` | 24 | `InterProcessMutexSession` | uncertain | `c2fb375626a10c1c` |
| `resilience4j-circuitbreaker.json` | 23 | `CircuitBreakerHalfOpen` | confirmed | `cbeba12606a3ad78` |
| `hikaricp.json` (new) | 66 | `FastListTracked` | **refuted** | `8a24a807dde16fdb` |

The three earlier verdicts equal the regression set's (J3a confirmed, J3b uncertain, J3c confirmed).

**What a baseline means.** The gate blocks a change that flips a property to confirmed from what it was at approval.
- **J3a and J3c** are open findings on the approved code, so their baselines are confirmed. They record the defects;
  they do not guard against them. A fix shows as an FYI change.
- **HikariCP's** is a fixed bug, so it guards against the bug coming back.

## HikariCP: why the H run's spec could not be the golden

`FastListSize` (the H run's spec) confirmed at H3's parent. At HEAD, where #591 is fixed, the review also said
**confirmed**. At HEAD, `trackStatement`, `untrackStatement` and `closeStatements` are all `synchronized` on the
connection.

**The cause.** The spec's steps are tagged `@code FastList.add` and `FastList.remove`. The lock check takes the locks
held on entry from every context that reaches those functions. `ConcurrentBag` also calls `FastList`, on its
per-thread lists and with no lock, so the connection's monitor drops out.
- This is M1's location problem, now inside a confirmation. The race is located at the container, not at the callers
  that share one instance.
- A golden on that spec would record a false defect on fixed code.

**`FastListTracked`** is the same model, with each step tagged at the sharing caller:
- `@code ProxyConnection.trackStatement`, `@at …ProxyConnection.java: openStatements.add(statement)`;
- `@code ProxyConnection.untrackStatement`, `@at …: openStatements.remove(statement)`.

A copy is kept at `benchmarks/java/hikaricp-h3/.specverify/golden/`. `confirm_counterexample` on its TLC
counterexample (`Tracked` violated) gave:

| tree | verdict | why |
|---|---|---|
| H3's parent (`hikaricp-h3`) | confirmed `34344de25aaa` | `untrackStatement` is already synchronized (H2's fix came first), `trackStatement` is not |
| HEAD | refuted `e9d6b034f093` | both steps hold `monitor:ProxyConnection` |

Without the `@at` lines, HEAD gave **uncertain**: the monitor is taken inside a whole-function region, so the check
cannot place the pause.

## The gate, probed

1. A throwaway local commit, `specforge-golden-probe` (`3250d787`, since deleted), removed `synchronized` from
   `trackStatement` on top of `specforge-goldens`.
2. `golden_run(base=specforge-goldens, head=probe, gate=True)` gave exit 1: "BLOCKING FastListTracked.tla — golden
   property FastListTracked.tla (curated) held before this change and fails now".

## What this records

- **The Java golden stores carry properties.** Three record known findings, and one guards a fix.
- **A confirmation built on a container's own functions can confirm fixed code.** This is a second consequence of
  M1's cause, after recall. The fix used here is in the spec, and the skill should say so: tag a step at the function
  that shares the instance. Teaching `generate_skeleton` to tag container callers (M1's `container_callers`) would
  make it mechanical. That is not done here.
