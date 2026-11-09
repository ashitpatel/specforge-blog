# evidence/kombu

The structural story, regenerated for this series (see the posts of 2026-11-14 and 2026-11-15).

- `Resource-full.als` — the full R154-style Alloy model of kombu `Resource` (skeleton by
  `specforge_engine.skeleton.alloy` from the packet tree, operation semantics and asserts completed by hand).
- `Resource-full.run.log` — the checker's verdict: witness satisfiable, `NoOverLimit` counterexample
  (`#dirty = 2 > limit 1`), `NoDoubleHold` holds.
- `base/` — the packet's `kombu/` tree plus the golden model (`NoDoubleHold` only) under
  `code/kombu/.specverify/Resource.als`; `base.run.log` is its clean check.
- `head/` — base plus the constructed `release()` regression (marked `BLOG-DEMO` in
  `code/kombu/resource.py`) and the model updated to track it; `head.run.log` is its violated check.
- `review.json` — `review_diff` over base/head: `breaks: ["NoDoubleHold"]`. The `base`/`head`
  fields were relativized to this directory (checker output carries absolute paths); verdicts untouched.

Reproduce with the specforge engine: `check_alloy` on the `.als` files (mode `code`), `review(base, head)`
for the verdict.
