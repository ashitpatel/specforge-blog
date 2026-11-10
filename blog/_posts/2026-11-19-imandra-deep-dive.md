---
title: "Imandra vs specforge: ask the logician, or set the tripwire"
description: "A deep comparison with the neurosymbolic kin: shared LLM-proposes-solver-disposes shape, and the fork between answering semantic questions and shipping blocking verdicts."
layout: post
series: specforge
date: 2026-11-19
---

*Part 11 of 12 in a series on [specforge](https://github.com/ashitpatel/specforge). The [landscape]({% post_url 2026-11-16-landscape %}) called Imandra the closest kin. This post draws the fork precisely.*

## What Imandra is

[Imandra](https://www.imandra.ai/) builds neurosymbolic reasoning: its CodeLogician agent has LLMs construct explicit formal models of software, and its ImandraX engine — deployed in financial markets and safety-critical systems — reasons over them to answer rich semantic questions about program logic: state spaces, control flow, decision boundaries, edge cases. Their [paper](https://arxiv.org/abs/2601.11840) introduces code-logic-bench and reports that formal augmentation closes a 41–47 percentage-point accuracy gap over LLM-only reasoning. Their framing is blunt: LLMs "fundamentally lack the ability to perform precise, exhaustive mathematical reasoning about program behavior."

## Capability overlap

- **Same architecture.** LLM builds the formal model; automated reasoning judges it. Both systems refuse to let the LLM's word be final about behavior — the solver is the adult in the room.
- **Same diagnosis of the gap.** Code-logic-bench exists because engineering benchmarks don't require semantic rigor and theorem-proving benchmarks don't touch real software. Specforge's blinded recall runs exist for the same reason: measure reasoning about real code, with ground truth, reproducibly.
- **Same exhaustiveness claim.** Region decomposition over program logic and state-space exhaustion over interleavings are the same move in different spaces: don't sample behaviors, cover them.
- **Same audience pressure.** Both sell to teams where wrong behavior costs real money — trading, infrastructure, safety-critical — not to teams optimizing for demo velocity.

## Differences

- **Answers vs verdicts.** CodeLogician answers semantic questions ("what does this code do at this boundary?"). Specforge ships verdicts: bug / deterministic defect / model-level finding, each with its reproduction and evidence bar — and then pins goldens that block future changes. Consultation versus tripwire.
- **Breadth vs specialization.** Imandra reasons about program logic broadly — types, states, relations, control flow. Specforge specializes in two defect families (temporal, structural) and goes deep: fairness conditions, GIL switch windows, composition interfaces.
- **Question-asking vs gatekeeping.** Imandra's loop centers on the model answering well; specforge's loop centers on the model being *falsifiable* — mutants must violate, controls must pass, unrefuted properties ship nothing.
- **After the answer.** A CodeLogician session ends with understanding. A specforge run ends with artifacts that keep working: pinned properties, change guards, scenario digests. Understanding is the input; enforcement is the output.

## How to use each

- *Imandra:* sign up for Universe, point CodeLogician at a codebase, and ask semantic questions — what this function does at edge inputs, where a decision boundary lies, whether two regions overlap. Best for: understanding complex logic before changing it.
- *specforge:* install the wheel, open an agent session, and run verify-then-guard: model the slice, reproduce the finding, pin the property. Best for: proving a property holds and keeping it held.

Use Imandra before the change ("what does this actually do?") and specforge across it ("prove it still holds, then guard it").

## Contrasting example: the 41-point gap meets the lost wake-up

Imandra's exhibit: across tested models, LLM-only reasoning about program logic fails exhaustively — edge cases, decision boundaries, state coverage — and formal augmentation recovers 41–47 points of accuracy. The gap is the product: it measures exactly what statistical guessing can't do.

Specforge's mirror exhibit is the stomp lost wake-up ([part 5]({% post_url 2026-11-13-temporal-stomp %})): an LLM reading `__notify` would likely call it correct — notify, release, record, all present. The defect isn't in any line; it's in the interleaving *between* lines 666 and 668, which only exhaustive state exploration finds and only a forced-schedule replay demonstrates (10 hangs in 3,000 unforced trials). An LLM asked "is this correct?" says yes with high confidence. A checker asked "show me every interleaving" hands over the hang.

Same moral, both directions: the model proposes, the solver disposes — Imandra recovering what guessing misses in logic space, specforge recovering what it misses in interleaving space. Ask the logician to understand; set the tripwire to enforce.

{% include series.html %}
