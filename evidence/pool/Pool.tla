---- MODULE Pool ----
\* Connection pool: acquire / release / idle reaper / shutdown / restart.
\* nfr:scope: model deeply: acquire; release; idle-reaper; shutdown.
\* nfr:partitions: single in-process pool, no replicas or partitions.
\* nfr:deadlines: deferred (waits are indefinite, no deadline to bound).
\* Check values are small (2 conns, 2 threads, reap age 2); R1 fixes 32 and
\* R4 fixes 5 minutes, both checked at full size in the Alloy model.
\* Slots stand for pool positions: a replaced connection keeps its slot with
\* a fresh timestamp, since generations are unobservable.

EXTENDS Integers, Sequences, FiniteSets

\* @bound MaxConns conns
\* @bound ReapAge now
\* @bound MaxTime now
CONSTANTS MaxConns, Threads, MaxTime, ReapAge

VARIABLES conns, held, used, waitQ, poolState, now, lastError

vars == <<conns, held, used, waitQ, poolState, now, lastError>>

SlotIds == 1..(MaxConns + 1)
NoError == <<0, "none">>
Idle == {c \in conns : \A t \in Threads : <<c, t>> \notin held}
HeldConns == {c \in conns : \E t \in Threads : <<c, t>> \in held}
WaitElems == {waitQ[i] : i \in 1..Len(waitQ)}
StaleAt(n) == {c \in Idle : \E tm \in 0..MaxTime : (<<c, tm>> \in used /\ n - tm > ReapAge)}

Init ==
  /\ conns = {}
  /\ held = {}
  /\ used = {}
  /\ waitQ = <<>>
  /\ poolState = "open"
  /\ now = 0
  /\ lastError = NoError

\* @req R2 R3
AcquireTake(t, c) ==
  /\ poolState = "open"
  /\ c \in Idle
  /\ t \notin WaitElems \/ (waitQ # <<>> /\ Head(waitQ) = t)
  /\ held' = held \union {<<c, t>>}
  /\ waitQ' = IF t \in WaitElems THEN Tail(waitQ) ELSE waitQ
  /\ UNCHANGED <<conns, used, poolState, now, lastError>>

\* @req R1 R3
AcquireCreate(t) ==
  /\ poolState = "open"
  /\ Idle = {}
  /\ Cardinality(conns) < MaxConns
  /\ \E s \in SlotIds \ conns : (conns' = conns \union {s} /\ used' = used \union {<<s, now>>} /\ held' = held \union {<<s, t>>})
  /\ UNCHANGED <<waitQ, poolState, now, lastError>>

\* @req R3
AcquireWait(t) ==
  /\ poolState = "open"
  /\ Idle = {}
  /\ Cardinality(conns) = MaxConns
  /\ t \notin WaitElems
  /\ waitQ' = Append(waitQ, t)
  /\ UNCHANGED <<conns, held, used, poolState, now, lastError>>

\* @req R2
Release(t, c) ==
  /\ \E t2 \in Threads : <<c, t2>> \in held
  /\ held' = {p \in held : p[1] # c}
  /\ used' = {p \in used : p[1] # c} \union {<<c, now>>}
  /\ UNCHANGED <<conns, waitQ, poolState, now, lastError>>

\* @req R2
ReleaseInvalid(t, c) ==
  /\ \A t2 \in Threads : <<c, t2>> \notin held
  /\ lastError' = <<c, t>>
  /\ UNCHANGED <<conns, held, used, waitQ, poolState, now>>

\* @req R4
Tick ==
  /\ now < MaxTime
  /\ now' = now + 1
  /\ used' = {p \in used : p[1] \notin StaleAt(now + 1)} \union {<<c, now + 1>> : c \in StaleAt(now + 1)}
  /\ UNCHANGED <<conns, held, waitQ, poolState, lastError>>

\* @req R5
Shutdown ==
  /\ poolState = "open"
  /\ poolState' = "draining"
  /\ waitQ' = <<>>
  /\ UNCHANGED <<conns, held, used, now, lastError>>

\* @req R5
FinishShutdown ==
  /\ poolState = "draining"
  /\ HeldConns = {}
  /\ poolState' = "down"
  /\ UNCHANGED <<conns, held, used, waitQ, now, lastError>>

\* @req NFR3
Restart ==
  /\ poolState # "down"
  /\ conns' = {}
  /\ held' = {}
  /\ used' = {}
  /\ waitQ' = <<>>
  /\ poolState' = "open"
  /\ lastError' = NoError
  /\ UNCHANGED <<now>>

DownStutter ==
  /\ poolState = "down"
  /\ UNCHANGED vars

Next ==
  \/ (\E t \in Threads : (\E c \in SlotIds : (AcquireTake(t, c) \/ Release(t, c) \/ ReleaseInvalid(t, c))))
  \/ (\E t \in Threads : (AcquireCreate(t) \/ AcquireWait(t)))
  \/ Tick \/ Shutdown \/ FinishShutdown \/ Restart \/ DownStutter

\* Fairness for liveness: a holder given infinite chances eventually releases, and
\* each waiter's take eventually fires when infinitely often possible. Strong, not
\* weak: freed slots appear intermittently (take/release alternation), never
\* continuously, so WF would impose nothing. Without these, "eventually served" is
\* false by construction (a holder may hold forever; a barging thread may steal forever).
ReleaseAct == \E t \in Threads : \E c \in SlotIds : Release(t, c)
TakeAct(t) == \E c \in SlotIds : AcquireTake(t, c)
Fairness ==
  /\ SF_vars(ReleaseAct)
  /\ \A t \in Threads : SF_vars(TakeAct(t))

Spec == Init /\ [][Next]_vars /\ Fairness

TypeOK ==
  /\ conns \subseteq SlotIds
  /\ held \subseteq SlotIds \X Threads
  /\ used \subseteq SlotIds \X (0..MaxTime)
  /\ waitQ \in Seq(Threads)
  /\ Len(waitQ) <= Cardinality(Threads) + 1
  /\ poolState \in {"open", "draining", "down"}
  /\ now \in 0..MaxTime
  /\ lastError \in (SlotIds \X Threads) \union {NoError}

\* @req R0 R1 R2 NFR2 NFR3
PoolShape ==
  /\ Cardinality(conns) <= MaxConns
  /\ \A c \in conns : Cardinality({t \in Threads : <<c, t>> \in held}) <= 1

\* @req R3 NFR1
WaitShape ==
  /\ waitQ # <<>> => Cardinality(conns) = MaxConns
  /\ Len(waitQ) <= Cardinality(Threads)

\* @req R4
IdleFresh ==
  \A c \in Idle : \E tm \in 0..MaxTime : (<<c, tm>> \in used /\ now - tm <= ReapAge)

\* @req R5
ShutdownClean ==
  /\ poolState = "down" => HeldConns = {}
  /\ poolState # "open" => waitQ = <<>>

\* @req R3
AcquireDiscipline ==
  [][(Cardinality(conns') > Cardinality(conns) => (Idle = {} /\ Cardinality(conns) < MaxConns))
    /\ (Len(waitQ') > Len(waitQ) => (Idle = {} /\ Cardinality(conns) = MaxConns))]_vars

\* @req R5 NFR3
DownStaysDown == [][poolState = "down" => poolState' = "down"]_vars

\* @req R2
InvalidReleaseErrors ==
  [][((lastError' # lastError /\ lastError' # NoError) => (\E t \in Threads : \E c \in SlotIds : ((\A t2 \in Threads : <<c, t2>> \notin held) /\ lastError' = <<c, t>>)))
    /\ (((used' \ used) # {}) /\ now' = now => (\E c \in SlotIds : ((\E t2 \in Threads : <<c, t2>> \in held) /\ (\A t2 \in Threads : <<c, t2>> \notin held'))) \/ (\E s \in SlotIds : (s \notin conns /\ s \in conns')))]_vars

\* @req R3
TakeServesHead ==
  [][\A t \in Threads : \A c \in SlotIds : ((<<c, t>> \notin held /\ <<c, t>> \in held' /\ t \in WaitElems) => t = Head(waitQ))]_vars

\* Every waiter eventually leaves the queue: served in FIFO order, or dropped
\* by shutdown or restart. Needs Fairness: without it a holder may hold forever.
\* @req R3 R5
WaiterResolves ==
  \A t \in Threads : (t \in WaitElems ~> t \notin WaitElems)

====
