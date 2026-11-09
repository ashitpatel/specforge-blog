# specforge-blog

A seven-part blog series on [specforge](https://github.com/ashitpatel/specforge): what it is, why exhaustive checking earns its keep next to testing, and five worked examples — greenfield, a guarded feature, a temporal catch, a structural catch, and two change guards that fire. Written in the style of the author's [ai4sgfinder](https://ashitpatel.github.io/ai4sgfinder/) and [lesson-scaffold-builder](https://ashitpatel.github.io/lesson-scaffold-builder/) series.

## Layout

- `blog/` — the Jekyll site (minima theme, `series` navigation). Posts in `_posts/`, dated 2026-11-09 to 2026-11-15.
- `evidence/` — the primary sources each post cites, vendored so the series stands alone:
  - `pool/` — the greenfield worked example: settled requirements, `Pool.tla`/`Pool.cfg`, `pool.als`, acceptance scenarios, answers file, `replay.py`.
  - `log4j/` — the change-guard data for the two Log4j introducing commits (`intro-c.json`, `intro-d.json`).
  - `stomp/` — the blind-tester match rows and the `S1` adjudication for the lost wake-up.
  - `hikaricp/` — the golden-properties record behind the temporal gate demo.
  - `rounds/` — the benchmark round records the stories quote (R152, R154 prereg + results, MR1 manifestation reading).
  - `kombu/` — the structural story, regenerated for this series: the full Alloy model + run log, and the base/head trees with the golden model and the review verdict (`review.json`) behind the structural drift demo.

## Preview

```bash
cd blog
bundle exec jekyll serve   # or: jekyll serve
```

## Publish

Push this directory as a GitHub repository with Pages enabled (Jekyll, `blog/` as the source or the repo root — adjust accordingly). If the repository is not named `specforge-blog`, update `baseurl` in `blog/_config.yml` (one line) to match.

## License

Apache 2.0 (`LICENSE`). Vendored evidence keeps its sources' provenance: benchmark records from the specforge repository, code trees from the named upstream projects (kombu: BSD-3-Clause).
