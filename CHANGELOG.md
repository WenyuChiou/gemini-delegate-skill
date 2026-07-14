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

### Changed

- **Legacy Gemini CLI backend now fails closed** (2026-07-14): both
  wrappers refuse a `gemini` backend with FATAL + exit 1 unless
  `GEMINI_DEPRECATED_OVERRIDE=1` is set — the consumer tier Google killed
  on 2026-06-18 makes the non-interactive CLI silently emit pseudo-code.
  The `agy` backend is unaffected. README (both locales), SKILL.md, and
  `references/wrapper.md` updated consistently; status banner points to
  the maintained, evidence-backed
  [antigravity-delegate](https://github.com/WenyuChiou/antigravity-delegate)
  lane.

### Added

- `references/gemini-prompt-blocks.md` — composable XML prompt blocks
  (`<language_variant_lock>`, `<source_fidelity>`, `<glossary_grounding>`,
  `<proper_noun_policy>`, `<reviewer_role>`, …), four task recipes, and a
  prompt anti-pattern table for drift-sensitive briefs. Designed for Gemini's
  actual failure modes (terminology drift, over-translated proper nouns,
  invented dates, zh-TW/zh-CN mixing) — a sibling of, not a copy of,
  `codex-delegate`'s `codex-prompt-blocks.md`.
- `tests/test_wrappers.py`: regression coverage for `files_changed` —
  populated on a git repo (bash + PowerShell) and `[]` on a non-git repo.

### Changed

- `scripts/run_gemini.sh` and `scripts/run_gemini.ps1` now auto-populate the
  `files_changed` field of `result.json`. The wrapper takes a
  `git status --porcelain` snapshot before and after the Gemini run and diffs
  them, so `files_changed` attributes edits to that run only. It degrades to
  `[]` when the repo is not a git work tree, git is absent, or nothing
  changed. The wrapper's own log / sentinel / `result.json` files are written
  after the snapshot, so they never leak in. This complements `--verify-file`:
  `--verify-file` checks that *expected* outputs exist; `files_changed`
  reveals *everything* Gemini touched, catching scope drift.
- `SKILL.md` and `references/task-template.md` now point drift-sensitive
  tasks (published reports, bilingual mirrors, long-context synthesis,
  second-opinion review) at the new prompt-blocks reference; tiny low-stakes
  drafts keep the flat template.
- `references/output-contract.md`: documented which `result.json` fields the
  wrapper fills. `tests_run` and `risks` are deliberately *not* auto-filled —
  Gemini-delegate work is drafting, not test execution, and risk is a
  judgment call; both stay Claude's to fill during publication review.
- `scripts/run_gemini.ps1` `Write-ResultJson` now assembles JSON by hand:
  Windows PowerShell 5.1 `ConvertTo-Json` renders an empty `@()` hashtable
  property as `null`, not `[]`, which broke the array contract. Hand-built
  JSON also keeps the two wrappers byte-compatible.

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
