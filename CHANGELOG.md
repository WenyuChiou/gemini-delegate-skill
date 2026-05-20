# Changelog

All notable changes to `gemini-delegate-skill` (the Claude Code skill at
`WenyuChiou/gemini-delegate-skill`). Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning:
[SemVer](https://semver.org/spec/v2.0.0.html).

The repository is `gemini-delegate-skill`; the plugin name in the
`WenyuChiou/ai-research-skills` marketplace is `gemini-delegate`. The
mismatch is intentional and load-bearing (see CONTRIBUTING.md §3 in
the marketplace repo).

## [Unreleased]

## [0.1.0] - 2026-05-14

The initial published version. Captures the skill state at commit
[`4c7f183`](https://github.com/WenyuChiou/gemini-delegate-skill/commit/4c7f183)
("docs(SKILL): apply code-reviewer fixes"), the HEAD on `master` when
this CHANGELOG was first added.

### Included

- `SKILL.md` — Claude Code skill manifest. Triggers when Claude
  benefits from delegating long-context reading, bilingual rewrites,
  second-opinion review, or Traditional Chinese / CJK output to the
  Gemini CLI.
- `references/` — workflow patterns, safe invocation patterns
  (including the `2>&1` redirect for capturing stderr alongside
  stdout), and CLAUDE.md-template snippets that prevent the common
  F1 / F13 / F14 failure modes documented in the maintainer's
  experience report.
- `tests/` — `pytest` covering the wrapper helpers + cross-platform
  shell invocation, added via PR
  [#3](https://github.com/WenyuChiou/gemini-delegate-skill/pull/3).
- `.github/workflows/` — GitHub Actions CI matrix (added in the
  same PR #3) running pytest on push + PR.
- `LICENSE` — MIT.
- `.claude-plugin/plugin.json` declaring `name: gemini-delegate` so
  the marketplace's plugin name resolves while the repo keeps its
  longer `-skill` suffix.

### Known limitations (as of 0.1.0)

- Tested by one graduate-student researcher; not corpus-scale validated.
- Gemini CLI binary must be installed separately (the skill
  documents the install path but does not install it for you).
- Delegation is one-directional (Claude → Gemini). Routing decisions
  among multiple delegates are handled by `research-hub-multi-ai` in
  the `ai-research-skills` catalog, not by this skill alone.
- The `gemini-delegate-skill` ↔ `gemini-delegate` repo-vs-plugin
  name asymmetry is real and easy to miss when copy-pasting install
  paths from one source repo to another; it is documented in the
  marketplace's CONTRIBUTING.md §3.

[Unreleased]: https://github.com/WenyuChiou/gemini-delegate-skill/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/WenyuChiou/gemini-delegate-skill/releases/tag/v0.1.0
