# specforge-blog

A sixteen-part blog series on [specforge](https://github.com/ashitpatel/specforge): what it is, why exhaustive checking earns its keep next to testing, five worked examples, the landscape and trust point, three deep comparisons, the conversation — and an evidence arc (overview + sshd + celery deep-dives) with the file drawer open. Written in the style of the author's [ai4sgfinder](https://ashitpatel.github.io/ai4sgfinder/) and [lesson-scaffold-builder](https://ashitpatel.github.io/lesson-scaffold-builder/) series.

## Layout

- `blog/` — the Jekyll site (minima theme, `series` navigation). Posts in `_posts/`, dated 2026-11-09 to 2026-11-24.
- `evidence/` — the primary sources each post cites, vendored so the series stands alone:
  - `pool/` — the greenfield worked example: settled requirements, `Pool.tla`/`Pool.cfg`, `pool.als`, acceptance scenarios, answers file, `replay.py`.
  - `log4j/` — the change-guard data for the two Log4j introducing commits (`intro-c.json`, `intro-d.json`).
  - `stomp/` — the blind-tester match rows and the `S1` adjudication for the lost wake-up.
  - `hikaricp/` — the golden-properties record behind the temporal gate demo.
  - `rounds/` — the benchmark round records the stories quote (R152, R154 prereg + results, MR1 manifestation reading).
  - `kombu/` — the structural story, regenerated for this series: the full Alloy model + run log, and the base/head trees with the golden model and the review verdict (`review.json`) behind the structural drift demo.
  - `overview/` — the source ledger for part 14's claims (`SOURCES.md`).
  - `sshd/` — the Java deep-dive: FR2/FR3 match rows, adjudications (KEX, timeout cluster, agent, process), pkt-g report + pkt-f excerpt.
  - `celery/` — the Python deep-dive: FR2/FR3 match rows, adjudications (flush ×5 groups, Timer ×3, LimitedSet), pkt-a report excerpt.

## Preview

```bash
cd blog
bundle exec jekyll serve   # or: jekyll serve
```

## Publish

Push this directory as a GitHub repository with Pages enabled (Jekyll, `blog/` as the source or the repo root — adjust accordingly). If the repository is not named `specforge-blog`, update `baseurl` in `blog/_config.yml` (one line) to match.

## License

Apache 2.0 (`LICENSE`). Vendored evidence keeps its sources' provenance: benchmark records from the specforge repository, code trees from the named upstream projects (kombu: BSD-3-Clause).
