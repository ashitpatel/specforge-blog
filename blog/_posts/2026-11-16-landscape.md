---
title: "The landscape: where specforge fits"
description: "Specforge against its neighbors: Specula's bug-hunting agents, vericoding's proven code, Axiom Math's Lean proofs, Imandra's neurosymbolic reasoning, AI code review (Qodo, CodeRabbit, Claude Code Review), and more."
layout: post
series: specforge
date: 2026-11-11
---

*Part 8 of 17 in a series on [specforge](https://github.com/ashitpatel/specforge). The previous seven posts built the case from the inside: [the gap]({% post_url 2026-11-09-what-tests-cannot-see %}), [the machinery]({% post_url 2026-11-10-how-it-works %}), and five worked examples. This one steps outside and places the tool among its neighbors — all characterizations as of November 2026, from the linked sources.*

*Level L2 · Needs: parts 1–2. Twelve neighbors, one map.*

Everyone in this post agrees on the premise: AI now writes code faster than humans can check it, and "trust me, the AI wrote it" is not a verification strategy. They differ on what checking means. That difference is the landscape. But first, where the landscape came from.

## Origins: two machines, one synthesis

In 1936, two men answered the same question — what is mechanically computable? — and gave opposite answers that turned out equivalent. Alonzo Church's lambda calculus says computation is functions-as-values: apply, substitute, reduce. Alan Turing's machine says computation is state-and-transition: read, write, move, repeat. Same power (the Church–Turing thesis), opposite engineering instincts — and Hilbert's Entscheidungsproblem got its negative answer along the way: no general procedure decides all truths. That "no" still bounds everything below.

The field inherited both bloodlines. The **Church side** — logic, types, proof — became proof assistants (Coq, Lean) and contract verifiers (Dafny, Verus): vericoding and Axiom Math live here, proving functions correct. The **Turing side** — states, transitions, explicit exploration — became model checking: TLC walks machine configurations the way Turing walked tape; bounded scope is the halting lesson internalized (can't decide in general, so exhaust small scope and name the bound). Alloy straddles the line: relational logic with Church's precision, SAT-backed bounded search with Turing's honesty about limits.

The **neurosymbolic synthesis** is younger: neural nets propose (fluent, statistical, unsound) and symbolic systems check (exact, exhaustive or proven). The pendulum swung from GOFAI — 1950s-style AI as hand-written rules and logic — to connectionism — intelligence as neural nets learned from data, culminating in LLMs — and now to this synthesis of the two: neural fluency checked by symbolic rigor. It became economical only when LLMs learned to write formal artifacts cheaply. Its clearest enterprise statement comes from Dr. Ashwin Rao — o9 Solutions' AI strategy & R&D lead, not the red-teaming researcher or the RL-in-finance author of the same name — whose 10-80-10 model flips typical agent architecture. His line: *"The LLM plays a focused role at the interface, while grounded enterprise reasoning carries the majority of the workload."* Neural first and last mile; symbolic middle mile of plans, constraints, and decisions. Specforge is that shape applied to code: interview and scenarios as the neural miles, TLC/Alloy plus falsification gates as the symbolic middle. Imandra, Bedrock's Automated Reasoning, even Harness²'s enforce-rather-than-instruct middleware are the same synthesis under different rules.

Where specforge stands, then: a Turing-side engine, Church-side discipline (specs as precise terms, composition through interfaces as modular reasoning), and a neurosymbolic loop on top. The falsification rule — mutants must violate, controls must pass, unrefuted properties ship nothing — is the meeting point both traditions agree on: neither trusts an unverified artifact.

## Specula: the closest neighbor

[Specula](https://www.aiinsiders.net/article/speculas-bug-hunting-agent-impresses-a-reviewer-but-not) (August 2026) is the nearest thing to specforge's from-code door: an agentic system that writes TLA+ specifications from code, validates them against observed traces, model-checks for concurrency bugs, and reproduces every confirmed bug as a timed integration test. Applied to slices of 48 concurrent and distributed systems — MongoDB, etcd, SONiC, libgomp among them — it surfaced 249 bugs, 207 previously unknown, across seven languages, at a median $57 in tokens per system.

Same core loop, same checker, same reproduce-or-it-doesn't-count rule. The informative part is where the two designs diverge, because reviewer Murat Demirbas's [objections to Specula](https://muratbuffalo.blogspot.com/2026/08/specula-scaling-formal-specifications.html) — on his Metadata blog — read like specforge's requirements list:

- *Circularity.* 87% of Specula's invariants come from the implementation code and its comments, risking encoding an existing bug as intended behavior. Specforge's greenfield door answers by deriving specs from prose plus interview — independent of any code — and its from-code door adds falsification controls (mutants that must violate, controls that must pass) so a vacuous model can't survive.
- *Composition.* Specula builds one model per module and mocks the interactions rather than reasoning about the whole system. Specforge composes module specs through published, version-pinned interfaces, re-checking clients when an interface changes.

Specula proves the from-code loop works at scale; specforge's wager is that the loop needs the two things Specula leaves out — independent requirements and composition — plus a second checker (Alloy) and tripwires afterwards. Closest kin, honest differences.

## Vericoding: proven code from specs

[Vericoding](https://blog.icme.io/vericoding-the-end-of-trust-me-bro-the-ai-wrote-it/) inverts the usual pipeline: instead of generating code and testing it, generate code *with a proof* from a formal specification — in Dafny, Verus, or Lean. The headline numbers are striking (82% success in Dafny with off-the-shelf models), and the [AlgoVeri benchmark](https://arxiv.org/abs/2602.09464v1) adds discipline: 77 classical algorithms under identical contracts across all three languages, where frontier models manage 40.3% in Dafny, 24.7% in Verus, and 7.8% in Lean. Its verdict on the field: "critical capability gaps" remain, with language design shaping what models can repair.

The relation to specforge is complementary, along two axes. First, *what* is proven: vericoding proves functional correctness — this sort sorts, this parser parses — typically of sequential algorithms. Specforge checks temporal and structural properties — no interleaving loses the wake-up, no state overfills the pool — typically of concurrent, stateful systems. Second, *which direction*: vericoding synthesizes code from specs; specforge runs the other way too, extracting checkable models from existing code, and then guards both against future change. A mature pipeline wants both: prove the function correct, then prove the system around it can't misuse it concurrently. Neither subsumes the other.

## The lightweight tradition

A [1998 CMU survey](https://users.ece.cmu.edu/~koopman/des_s99/formal_methods/) of formal methods — Larch, SML, HOL, Petri nets — ends with a conclusion worth quoting in full: heavyweight methods that try to describe *all* of a system have overreached and generally failed, and "the lightweight approach, which provides a compromise between the necessities of engineering and the goals of formal design, provides a good compromise and is the most productive route for future research."

Specforge is that route, 28 years later, with one change the survey couldn't foresee: the models are now written by agents, not by engineers trained in type theory. Alloy is the canonical lightweight method (small scopes, automatic counterexamples); TLA+ is its pragmatic sibling (engineers at AWS and elsewhere check real designs with it). The series' honesty section in part 1 — bounded scope, two defect families, verification *complementing* testing rather than replacing it — is the 1998 conclusion restated as a feature list. The bet is the same; the labor economics finally look viable.

## Spec-driven development: specs as prompts

[Spec-driven development](https://www.stride.page/learn/ai-coding-agents/spec-driven-development) is the dominant AI-coding methodology of 2026: GitHub's Spec Kit (open source, 139,000 stars, v1.0 in August 2026), AWS's Kiro IDE (July 2025, now the Q Developer successor), OpenSpec, Tessl. The workflow runs spec → plan → tasks → implement, with the spec as source of truth. The movement's shorthand is "the spec is the prompt" — [a saying in the AI coding community](https://www.mbakayoko.com/en/blog/spec-driven-development-in-the-ai-era).

That phrase marks the boundary. SDD specs are prose or structured markdown written to be *consumed by an LLM* — they steer generation. Nothing checks them exhaustively; a contradictory or incomplete spec steers the agent into building the wrong thing, with no check to flag the contradiction. Specforge specs are formal models written to be *consumed by solvers* — they verify behavior. SDD answers "what should the agent build?"; specforge answers "does what was planned or built actually hold, in every interleaving and every state?"

They stack rather than compete: SDD upstream (intent → plan → code), specforge as the verification stage and the guardrails afterward. The narrow overlap sits inside Kiro itself, whose workflow includes an [automated-reasoning pass](https://aws.amazon.com/blogs/machine-learning/trust-in-depth-giving-agents-more-autonomy-without-losing-control/) checking plans for contradictions and gaps, plus generated property-based tests — consistency-checking a plan: adjacent to exhaustive property verification, without demonstrated reproductions. Same "specs as artifacts" lineage, opposite ends of the rigor spectrum.

## Imandra: the neurosymbolic kin

[Imandra's CodeLogician](https://www.imandra.ai/) shares the neurosymbolic shape: LLMs construct explicit formal models of software, and an automated reasoning engine (ImandraX, deployed in financial markets and safety-critical systems) judges them. Their [paper](https://arxiv.org/abs/2601.11840) reports that formal augmentation closes a 41–47 percentage-point accuracy gap over LLM-only reasoning about program logic, and pointedly frames it as prerequisite, not optimization — the abstract's opening sentence: LLMs "fundamentally lack the ability to perform precise, exhaustive mathematical reasoning about program behavior."

The differences are scope and endpoint. Imandra reasons about program logic broadly — state spaces, control flow, decision boundaries of the code as written — and answers rich semantic questions. Specforge specializes: temporal properties (interleavings) and structural properties (shapes), with the loop terminating not in answers but in *verdicts* — demonstrated bugs, pinned goldens, blocking gates. If CodeLogician is a logician you consult, specforge is a tripwire you install. The two agree on the deep point: the LLM proposes, the solver judges.

## AI code review: governance for the other 95%

[Qodo](https://www.qodo.ai/) attacks the same bottleneck — review capacity — from the governance side: multi-agent code review on every pull request, organizational standards enforced automatically, codebase knowledge brought into the agentic SDLC. "Code review for agents. Governance for humans."

Two more reviewers fill out that layer.
- **[CodeRabbit](https://www.coderabbit.ai/)** is the broadest. It reviews pull requests on GitHub, GitLab, Azure DevOps and Bitbucket, and also runs in the IDE and from a CLI. Parallel agents explore a sandboxed clone of the repository, with the findings of 50-plus linters and scanners as hints. It posts summaries, inline comments, fixes and generated tests, learns from replies, and can block a merge on natural-language pre-merge checks.
- **[Claude Code Review](https://code.claude.com/docs/en/code-review)** is the narrowest. Several agents read a GitHub pull request and the code around it, a verification pass filters their candidates, and what survives is posted by severity: important, nit, or pre-existing. It targets correctness bugs only, never runs the code, and never approves or blocks. Its review rules are read from the protected base branch, so a pull request cannot rewrite them.

Neither documents model checking or a dedicated concurrency analysis. Both use races as examples of what they flag, and both decide by a model's reading. CodeRabbit publishes customer acceptance rates; Claude Code Review warns that a clean review is no proof of correct code. (Both were compared from their documentation, 2026-11-13, not from runs.)

This is the complementary layer, not a competitor. AI review judges what reviewers judge — standards, coverage, blast radius, suspicious patterns — at machine speed. Exhausting interleavings isn't its job — review judges the change, it doesn't enumerate schedules; no reviewer, human or artificial, can eyeball whether a freed slot reaches the longest waiter under every schedule. The honest stack is both: an AI reviewer on every PR for the things judgment covers, specforge-style exhaustive checking for the properties judgment can't see. Part 4's Log4j story is the boundary case: a review agent might flag the escaping stream, but only the model says which interleavings break.

The two layers also meet in the middle. When a reviewer writes "this races with logout", that sentence is a claim about interleavings. It is exactly what specforge's confirm path settles: model the slice, check it, replay the trace against the code. And they guard against the same thing: Claude Code Review reads its rules only from the base branch, for the same reason specforge's bot-team mode will not count answers the dev bot could have written. What judges a change must not be editable by the change. Specforge's own change review does not yet hold to that: it still reads the answers and screen records in the tree under review. The fix is planned ([RV1](https://github.com/ashitpatel/specforge/blob/main/docs/project/rounds/2026-11-13-RV1-plan.md)), borrowed from Claude Code Review's protected-branch rule.

## Intent Lab: fellow TLA+ travelers

[Intent Lab](https://intentlab.ai/) (Yangqing Jia's team) builds an autonomous "fleet" that turns rough human intent into production systems. Notably, it uses TLA+ to build mission-critical infrastructure like their Agent FS filesystem, checking millions of states and working to ensure the TLA+-to-Rust/C conversion doesn't weaken end-to-end correctness.

This is convergent evolution, and the series takes it as corroboration: a frontier lab, aiming at full autonomy, independently lands on TLA+ as the load-bearing verification for the parts that must not break. The difference is product shape: Intent Lab wields TLA+ inside a system-building fleet; specforge packages the verification half — interview to spec to guardrail — as the tool itself, usable on systems the fleet didn't build. Same checker, different seat at the table.

## &Truth: the moonshot

[&Truth](https://andtruth.com/) states the maximal version of the premise: a "universal verification machine" that reads code in any language and mathematically proves it safe, secure, and correct, with independently checkable proofs. (Pre-release as of this writing; their roundtable includes the inventor of Lean.)

Take the mission statement at face value and specforge is the scoped-down version that works today: not any language (Python and Java), not any property (temporal and structural), not proof (bounded checking), and a human still in the loop. If &Truth is the moonshot, specforge is the base camp that already returns samples — real races demonstrated, real regressions blocked. The moonshot's success would subsume the base camp; until then, scoped and working is what returns samples. The series' wager is that the base camp teaches the moonshot something about which properties matter.

## Axiom Math: proofs at startup scale

[Axiom Math](https://menlovc.com/perspective/ai-will-write-all-the-code-mathematics-will-prove-it-works/) (Palo Alto, founded March 2025) raised a $200M Series A led by Menlo Ventures at a $1.6B valuation to do with Lean what vericoding does in the lab: its AxiomProver system and AXLE API generate machine-checkable proofs that software performs as specified.

In November 2026 it announced the formalization of the 7,654-page Stacks Project — roughly 16 million lines of checked Lean, described as the largest integrated body of formalized mathematics ever built. A metadata analysis by AI Proved What? ([summary](https://www.techtimes.co.uk/axiom-math-stacks-project-lean-library-review-1809778)) counts ~97% of its formalised tags in the AI-written StacksFrontier tier still awaiting human review — tiers [Axiom's own site](https://stacks.axiommath.ai/) labels the same way.

The relation mirrors vericoding's — complementary along the same two axes (functional versus temporal/structural, synthesis versus checking) — now with $200M behind industrializing it. A proof says the sort sorts at any scale; a model check still says no schedule loses the wake-up.

(A note for the careful: axiom.ai, a browser-automation product, is an unrelated company with a similar name. This section is about Axiom Math.)

## Harness²: improve the agent

[Google's Harness²](https://github.com/google-research/harness2) (October 2026, Apache 2.0, [paper](https://arxiv.org/abs/2610.14224)) freezes the model weights and rewrites the harness instead — prompts, guardrails, memory, skills, tools, subagents — per task, in a Propose–Probe–Compose loop that keeps what scores. Gains are large (+11.8pp on the LAB legal benchmark, +11.5 on WorkBuddy-Bench). The loop shape is kin to specforge's propose→confirm→record, and its middleware — a plugin that "enforces a behavior rather than instructs it" ([Appendix D](https://arxiv.org/html/2610.14224v1)) — echoes specforge's mechanism-over-prompting.

The fork: Harness² judges by task performance and rewrites its own guardrails — the right shape for an optimizer; specforge judges by checker verdicts and holds its bar fixed — the requirement for a verifier. The two stack: optimize the agent with Harness², verify the work with specforge.

## Petra: guardrails over MCP

[Petra](https://www.petracode.co.uk/) is worth watching for its delivery bet: verified code generation plus "solver proofs and state-space guardrails" served through an MCP server into Claude, Cursor, Copilot, and autonomous agents — the same shape as specforge's own MCP tools. Petra's emphasis is agent containment and reliability for mission-critical systems (including, per their published work, the first deductive verification of an agentic framework itself, PocketFlow in Dafny). The split: Petra guards the *agents*; specforge guards the *code* — temporal and structural properties of the software being built, whatever built it.

## Bedrock Automated Reasoning: the pattern at hyperscale

Amazon Bedrock's [Automated Reasoning checks](https://aws.amazon.com/about-aws/whats-new/2026/06/amazon-bedrock-guardrails-sydney/) (GA since August 2025, from the AWS Automated Reasoning Group) compile natural-language policies into formal logic and check model outputs against them with SMT solvers — LLM proposes, solver judges, with AWS quoting up to 99% accuracy on grounded content. The method is the same neurosymbolic pattern this series runs on; the target differs (output/policy compliance rather than code properties). Its existence at hyperscaler scale is corroboration that the pattern, not just the premise, has arrived.

## The map

One picture for the whole landscape. The rows are what each neighbor contributes; the columns are the questions that separate them:

| | proves what? | from what? | ends in what? |
|---|---|---|---|
| Specula (model checking) | concurrency bugs | code → TLA+ | reproduced bugs |
| Harness² (neurosymbolic loop) | agent performance | tasks + scores | better harnesses |
| Vericoding (deductive) | functional correctness | formal specs | proven code |
| Axiom Math (deductive) | functional correctness | specs → Lean | checked proofs |
| Lightweight methods (both) | scoped properties | engineer-written models | counterexamples |
| SDD (prompts) | steering, not proving | prose specs | agent-built code |
| Imandra (neurosymbolic) | program-logic questions | code → formal models | answers + proofs |
| Qodo (review) | standards, review coverage | PRs + repo knowledge | governed merges |
| Intent Lab (model checking) | infra correctness | intent → systems | verified systems |
| &Truth (deductive, pre-release) | everything | any code | checkable proofs |
| Petra (neurosymbolic) | agent + code reliability | agent workflows | guarded agents |
| Bedrock AR (neurosymbolic) | output/policy compliance | NL policies | valid/invalid |
| **specforge (model checking + neurosymbolic loop)** | temporal + structural | prose *or* code | demonstrated bugs + tripwires |

The last row is this series' claim to a seat: a tool that starts from plain prose or from existing code alike, demonstrates its findings on real code, and then stands guard over later changes to what it modeled. The neighbors each do something it doesn't; it does something none of them do. By bloodline: the deductive half proves functions; the model-checking half exhausts behaviors; the neurosymbolic entries — Imandra, Petra, Bedrock, Harness², and this tool — all pair a proposer with a judge.

One post remains: [slices]({% post_url 2026-11-17-slices %}) — what gets checked, what might not, and how to watch the gaps.

{% include series.html %}
