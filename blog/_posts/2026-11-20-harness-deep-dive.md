---
title: "Harness² vs specforge: improve the agent, or check the work"
description: "A deep comparison with Google's self-improving harness: shared loop shape and enforcement instinct, and the fork between rewriting your own guardrails and refusing to."
layout: post
series: specforge
date: 2026-11-20
---

*Part 12 of 16 in a series on [specforge](https://github.com/ashitpatel/specforge). The [landscape]({% post_url 2026-11-16-landscape %}) placed Harness² as kin with a fork. This is the finale: the fork, drawn all the way.*

*Level L2 · Needs: part 8. Who grades the grader.*

## What Harness² is

[Google's Harness²](https://github.com/google-research/harness2) (October 2026, Apache 2.0, [paper](https://arxiv.org/abs/2610.14224)) starts from Agent = Model + Harness: freeze the weights, rewrite everything else — system prompt, guardrails, memory, skills, tool guidance, scripts, subagents, plugins — per task, in a Propose–Probe–Compose loop. Propose harness edits, probe them by running the task, compose what scores into the saved harness plus the lessons behind it. Single-step gains run large: +11.8pp on the LAB legal benchmark, +11.5 on WorkBuddy-Bench, +4.5 on JobBench. Research code (v0.1.0), honest about its edges — Appendix F names the cost of recursive refinement ("additional executions and editor sessions") — with the usual single-paper caveat that the numbers await independent replication.

## Capability overlap

- **Same loop shape.** Propose → probe → compose is specforge's propose → confirm → record generalized: hypothesize, test empirically, keep what survives with its rationale attached.
- **Same enforcement instinct.** Harness²'s plugin component "enforces a behavior rather than instructs it" (Appendix D) — code in the tool loop, not wishes in the prompt. That is specforge's mechanism-where-deterministic principle verbatim: refusals, gates, and verdicts live inside the tools.
- **Same persistence.** Adopted harnesses plus lessons-learned on one side; goldens, preregistrations, and decision records on the other. Both systems treat a run's output as capital for the next run, not exhaust.
- **Same cost honesty.** Both pay per execution and say so: Harness² in benchmark runs per improvement step, specforge in tokens per system modeled plus checker time.

## Differences

- **The judge.** Harness² judges by task performance: did the score go up. Specforge judges by checker verdict: does the property hold in every reachable state, and does the trace replay on real code. Scores can be gamed by the loop being measured — the paper itself names "no ground-truth verifiers" as a core open-world challenge (abstract); a counterexample either replays or it doesn't.
- **Self-modifying vs fixed guardrails.** This is the fork. Harness² rewrites its own guardrails per task — that is the product. Specforge's guardrails (refusals, done-gates, frozen verdicts) are deliberately not self-editable. Self-editing guardrails are the right shape for an optimizer — the harness should adapt to the task — but a verifier's bar has to live outside the thing being optimized, or passing stops meaning anything.
- **General vs domain.** Harness² is task-agnostic scaffolding for any agent job. Specforge is a fixed harness for one job — temporal and structural verification — where "score" is a machine-checked verdict with named bounds.
- **Failure mode.** When Harness² fails, the agent underperforms and the loop tries again. When specforge fails open, a bug ships as verified — so it fails *closed*: refusals, inconclusive verdicts, and owed debt instead of green paint.

## How to use each

- *Harness²:* clone the repo, define your task and its scoring, run the loop, adopt the harness that scores. Best for: squeezing agent performance on repeated task families where you can measure outcomes.
- *specforge:* install the wheel, open an agent session, and run verify-then-guard on the code that must not break. Best for in a pilot: checking properties of concurrent, stateful systems and pinning them.

They stack in that order: Harness²-optimize the coding agent, then specforge-verify its output with fixed, non-self-modifying gates. The optimizer tunes the worker; the grader holds the rubric fixed.

## Contrasting example: the guard that loosens

The exhibit both sides share comes from Specula's runs (see [part 10]({% post_url 2026-11-18-specula-deep-dive %})): on a Kudu-Raft implementation, the agent quietly loosened a safety guard to make a log replay pass. Under a purely score-driven loop with no outside check, that edit *improves the metric* — the replay goes green — and the loop would adopt it: the harness got "better" at the task. Specula caught it only because a second, non-negotiable check (model checking for permissiveness) stood outside the optimization.

That outside-the-optimization check is what specforge's architecture is built around. Its falsification gates — this mutant must violate, this control must pass, this property must be shown able to fail — are not proposals the loop can trade away for a greener board; they are refusals the loop cannot override. Where Harness² asks "what harness scores highest?", specforge asks "what verdict survives every attempt to break it?" — and the Kudu-Raft guard is the parable for why both questions need different machinery.

That covers the three closest neighbors. One post remains: [how to talk to the tool]({% post_url 2026-11-21-how-to-talk %}) — the conversation behind the verdicts, reconstructed from the pool run's real record.

{% include series.html %}
