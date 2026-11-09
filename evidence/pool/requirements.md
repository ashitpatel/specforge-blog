# Connection pool — requirements

R0. The system is built in Java 21.
NFR1. Hundreds of threads share one pool.
NFR2. The pool is a single-process library with no replicas or partitions; it is engine-agnostic.
NFR3. Pool configuration persists across restarts; connections are re-established after a restart, lazily as threads call acquire().
R1. The pool holds up to 32 database connections; 32 is a fixed maximum; the pool starts empty and opens connections on demand.
R2. Threads call acquire() to get a connection and release() to return it; any thread holding a handle may release it; a thread may wait for another connection while holding one; releasing a connection that is not checked out is an error.
R3. If no connection is free and the pool holds fewer than 32, acquire() opens a new connection; only when all 32 are checked out does it wait indefinitely until one is returned; a freed connection goes to the longest-waiting thread.
R4. Idle connections past 5 minutes are closed and replaced immediately with a fresh connection; idle time counts in whole minutes; checked-out connections have no hold limit.
R5. The pool shuts down cleanly, waiting indefinitely for checked-out connections to come back; new acquire() calls during shutdown are rejected; threads waiting at shutdown are rejected too; shutdown passes through draining, then down once every connection is back.
