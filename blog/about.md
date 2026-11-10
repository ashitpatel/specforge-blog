---
layout: page
title: About
---

[specforge](https://github.com/ashitpatel/specforge) is a tool that turns requirements or existing code into Alloy and TLA+ models, checks them exhaustively at small scope, reproduces what it finds on the real code, and then guards every later change against the models. It works on two kinds of defect: temporal (races, deadlocks, lost wake-ups, ordering violations) and structural (broken shape invariants in data and APIs).

This series walks through the idea and five worked examples:

1. What tests cannot see — the gap the tool fills.
2. How it works — the two checkers and the loop around them.
3. A pool, specified before it exists — greenfield, from five lines of prose.
4. The commit that Log4j would have flagged — a feature guarded at introduction.
5. The lost wake-up — a latent race in stomp, found blind and demonstrated.
6. The pool that overfilled — the same defect as a structural counterexample in kombu.
7. The guard that fires — catching drift during a change, twice.
8. The landscape — where specforge fits among its neighbors.
9. Slices — what gets checked, what might not, and how to watch the gaps.
10. Specula vs specforge — the same loop, different answers to its critics.
11. Imandra vs specforge — ask the logician, or set the tripwire.
12. Harness² vs specforge — improve the agent, or check the work.
13. How to talk to the tool — the conversation behind the verdicts.

The evidence beside each claim lives in this repository under `evidence/`: specs, checker logs, review verdicts, and the benchmark records each story is built on. Where a demonstration is constructed rather than found — a deliberate probe, a hand-authored regression — the post says so.

## The two checkers, briefly

- **TLA+** (Leslie Lamport) is a language for describing systems as states and the actions that move between them; its TLC model checker explores every reachable state at small scope, hunting interleaving bugs. Start at [Lamport's TLA+ page](https://lamport.azurewebsites.net/tla/tla.html) (free book *Specifying Systems* included) or the hands-on [Learn TLA+](https://learntla.com/).
- **Alloy** (Daniel Jackson, MIT) is a language for declaring a system's relations and asserting what must always hold; its analyzer searches for a snapshot that breaks the claim. Start at [alloytools.org](https://alloytools.org/) (free Analyzer, tutorial, and the book *Software Abstractions*).

Why these two as the guardrails: they split the problem along its natural seam — TLA+ sees behavior over time, Alloy sees shapes in a snapshot — both check exhaustively rather than sampling, both answer violations with concrete counterexamples, both are mature open tools, and both are compact enough for agents to author. Together they cover what testing can't: every interleaving, every shape, at small scope.

The posts here were written by directing an AI agent: I set the direction and made the editorial calls, and the agent drafted them and checked the facts against the evidence. Corrections are welcome as issues.
