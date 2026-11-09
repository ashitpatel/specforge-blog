// Connection pool: structural snapshot + state invariants (time lives in TLA+).
// nfr:scope: model deeply, in this order: acquire; release; idle-reaper; shutdown.
// nfr:topology. Stored placement: "single in-process pool, no replicas or partitions"
// nfr:survival. Stored recovery: "pool configuration persists; connections are re-established after restart"
// nfr:deadlines: deferred (R3/R5 waits are indefinite, no deadline to bound).

-- @req R0 NFR2
one sig Pool {
  conns: set Connection,
  waiters: set Thread,
  state: one PoolState
}

-- @req R5
abstract sig PoolState {}
one sig Open, Draining, Down extends PoolState {}

-- @req NFR1 R2
sig Thread {}

-- @req R1 R4
sig Connection {
  holder: lone Thread,
  lastUsed: one Int
}

-- @req R4
one sig Clock { now: one Int }

-- @req NFR3
one sig PoolConfig { maxConnections: one Int }

-- @req R1
fact Capacity { #Pool.conns <= PoolConfig.maxConnections }

-- @req R1 NFR3
fact ConfigFixed { PoolConfig.maxConnections = 32 }

-- @req R2
fact HoldersArePooled { all c: Connection | some c.holder implies c in Pool.conns }

-- @req R3
fact WaitOnlyWhenEmpty { some Pool.waiters implies no { c: Pool.conns | no c.holder } }

-- @req R4
fact ReapedInTime { all c: Pool.conns | no c.holder implies minus[Clock.now, c.lastUsed] <= 5 }

-- @req R4
fact TimeSane { all c: Connection | c.lastUsed <= Clock.now }

-- @req R5
fact DownMeansEmpty { Pool.state = Down implies no { c: Pool.conns | some c.holder } }

-- @req NFR3
pred restart_keeps_config[c, c2: PoolConfig] { c2.maxConnections = c.maxConnections }

-- @req R1
assert CapacityBounded { #Pool.conns <= 32 }
check CapacityBounded for 33 but 7 Int

-- @req R1 R3
fact GrowBeforeWait { some Pool.waiters implies #Pool.conns = 32 }

-- @req R5
fact NoWaitersWhileClosing { Pool.state in Draining + Down implies no Pool.waiters }

run Witness {
  some c: Pool.conns | some c.holder
  some Pool.waiters
  Pool.state = Open
} for 33 but 7 Int

-- @question A thread waits while the pool holds fewer than 32 connections. Must the pool grow first, or is waiting allowed?
-- @req R1 R3
run WaitBelowCapacity { some Pool.waiters and #Pool.conns < 32 } for 33 but 7 Int

-- @req R2 R3
run HoldWhileWaiting { some t: Pool.waiters | t in Connection.holder } for 33 but 7 Int

-- @req R4
run HeldPastFive { some c: Pool.conns | some c.holder and minus[Clock.now, c.lastUsed] > 5 } for 33 but 7 Int

-- @question Threads are still waiting while the pool is shutting down or shut down. Is that allowed?
-- @req R5
run ShutdownWithWaiters { Pool.state in Draining + Down and some Pool.waiters } for 33 but 7 Int
