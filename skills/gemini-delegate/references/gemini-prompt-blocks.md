# Gemini prompt blocks — phrasing the task so Gemini drafts cleanly

`task-template.md` defines the *shape of the brief file* (Context / Goal /
Language / Constraints / Acceptance). This file defines the *phrasing layer*: a
set of composable XML-tagged blocks you drop **inside** the brief's Goal,
Language, and Constraints sections to head off Gemini's recurring drift.

These blocks are deliberately **not** a copy of `codex-delegate`'s
`codex-prompt-blocks.md`. Gemini's strengths (long-context reading, CJK and
bilingual drafting, cross-file synthesis) and its failure modes are different
from a code model's, so the blocks target Gemini's actual drift — the list in
`SKILL.md` § "Common drift to watch": terminology drift, over-translated proper
nouns, missing banned phrases, invented dates, and zh-TW/zh-CN mixing.

For a tiny, low-stakes draft the flat template is enough — do not bolt every
block on. Reach for them when an invented fact, a slipped term, or a wrong
language variant would actually hurt: published reports, bilingual mirrors,
long-context synthesis, second-opinion review.

## Where the blocks go

The wrapper runs `--prompt "Read .ai/gemini_task_<name>.md and execute..."`, so
Gemini reads the brief file. XML tags inside that markdown are read fine. Put
the blocks under the brief's Goal (what done looks like), Language (variant and
register), or Constraints (what must not happen). Keep them compact — a sharper
contract beats a longer pep talk.

Core rules:

- One clear deliverable per Gemini run. Split unrelated asks into separate runs.
- Name the language variant explicitly; never write just "Chinese".
- Cite files (glossary, sources, banned-word list) by path — Gemini follows a
  cited file far better than an abstract instruction.
- Add a block only where the task needs it; remove redundant ones before sending.

## Block library

Wrap each block in the XML tag shown. Pick the smallest set that fits.

### `task` — use in nearly every brief

```xml
<task>
The concrete deliverable, the source material to draw from, and the expected
end state.
</task>
```

### `output_contract` — when the response shape matters

```xml
<output_contract>
Return exactly the requested structure (sections, headings, length).
Put the highest-value content first. No preamble, no meta-commentary.
</output_contract>
```

### `source_fidelity` — Gemini's anti-hallucination block; use whenever facts matter

```xml
<source_fidelity>
Every claim must trace to one of the provided source files.
Do not add facts, history, or context that the sources do not contain.
If a needed fact is absent, write [unknown] rather than guessing.
</source_fidelity>
```

### `no_invented_specifics` — dates, numbers, versions, names

```xml
<no_invented_specifics>
Do not invent dates, version numbers, statistics, or proper nouns.
Use only specifics present in the sources, copied verbatim.
If the brief underspecifies one, leave a [TODO: confirm] marker — do not fill it.
</no_invented_specifics>
```

### `language_variant_lock` — the single most important CJK block

```xml
<language_variant_lock>
Write the entire output in Traditional Chinese (zh-TW). [or: Simplified (zh-CN)]
Do not switch variants mid-document. Convert any source text quoted from the
other variant into the target variant, including punctuation (「」 vs “”).
</language_variant_lock>
```

### `proper_noun_policy` — stop over-translation

```xml
<proper_noun_policy>
Keep organisation names, product names, and person names in their original
language. Translate a proper noun only when an official localised name exists;
otherwise leave it as-is. Never invent a translation.
</proper_noun_policy>
```

### `glossary_grounding` — terminology, cited as a file

```xml
<glossary_grounding>
Follow the glossary at <path/to/glossary.md> for every listed term.
For a term not in the glossary, pick one rendering on first use and reuse it
verbatim everywhere after.
</glossary_grounding>
```

### `terminology_consistency` — when there is no glossary file

```xml
<terminology_consistency>
Choose one rendering per concept on first use; reuse it verbatim for the rest
of the document. Do not let a term drift across sections.
</terminology_consistency>
```

### `register` — tone, formality, audience

```xml
<register>
Tone: <formal | concise | executive | technical>. Audience: <who reads it>.
Match that register consistently; do not default to mid-formal.
</register>
```

### `section_language_map` — for mixed-language output

```xml
<section_language_map>
State which language each section uses, e.g. headings in English, body in
zh-TW. Do not mix languages within a section unless the brief says so.
</section_language_map>
```

### `synthesis_scope` — for cross-file synthesis

```xml
<synthesis_scope>
Synthesise only what the sources contain. Keep "stated in the sources" separate
from "reasoned inference", and label inferences. Do not editorialise.
</synthesis_scope>
```

### `long_context_coverage` — when reading many files

```xml
<long_context_coverage>
Consult every listed source before drafting. Do not summarise from only the
first few. If a source could not be used, name it and say why.
</long_context_coverage>
```

### `banned_phrasing` — project-specific forbidden terms

```xml
<banned_phrasing>
Avoid the terms in <path/to/banned-words>. Do not paraphrase a banned term into
an equivalent that still carries the same prohibited meaning.
</banned_phrasing>
```

### `reviewer_role` — for second-opinion review tasks

```xml
<reviewer_role>
Review only. Do not rewrite or "fix" the text. Flag each issue with a quoted
span, a severity, and a one-line reason. Leave the decision to the reader.
</reviewer_role>
```

## Recipes

Copy the smallest recipe that fits, then trim. These slot into the brief's
Goal / Language / Constraints; the brief still carries Context (source files)
and Acceptance (verification files) per `task-template.md`.

### CJK report drafting

```xml
<task>
Draft <report> from the listed source files.
</task>
<language_variant_lock>
Entire output in Traditional Chinese (zh-TW). No variant mixing.
</language_variant_lock>
<register>
Tone: <formal/executive>. Audience: <who>.
</register>
<source_fidelity>
Every claim traces to a source file. Absent facts → [unknown].
</source_fidelity>
<no_invented_specifics>
No invented dates, numbers, or proper nouns.
</no_invented_specifics>
<glossary_grounding>
Follow <path/to/glossary.md>.
</glossary_grounding>
```

### Bilingual mirror sync (EN ↔ zh-TW)

```xml
<task>
Produce the <target-language> mirror of <source-language> document <path>.
The two must convey exactly the same facts and structure.
</task>
<section_language_map>
Mirror section-for-section; same headings, same order.
</section_language_map>
<language_variant_lock>
Target variant: zh-TW. [or zh-CN]
</language_variant_lock>
<proper_noun_policy>
Keep org / product / person names in the original language.
</proper_noun_policy>
<source_fidelity>
Add nothing the source document does not state; drop nothing it does.
</source_fidelity>
```

### Long-context synthesis

```xml
<task>
Synthesise <question> across the listed source files.
</task>
<long_context_coverage>
Consult every source; name any that could not be used.
</long_context_coverage>
<synthesis_scope>
Separate stated facts from inference; label inferences.
</synthesis_scope>
<output_contract>
Return: 1. synthesis  2. supporting sources per point  3. open questions.
</output_contract>
```

### Second-opinion review

```xml
<task>
Review <document/path> for <facts / terminology / tone / clarity>.
</task>
<reviewer_role>
Review only — do not rewrite. Flag each issue: quoted span, severity, reason.
</reviewer_role>
<source_fidelity>
Ground each comment in the document text or the cited sources, not assumptions.
</source_fidelity>
```

## Prompt anti-patterns

These are about *prompt phrasing*, distinct from the brief-file anti-patterns
in `task-template.md` (vague goals, missing tone, no acceptance file).

| Anti-pattern | Bad | Fix |
|---|---|---|
| Variant left to Gemini | "Translate this into Chinese." | `language_variant_lock` with zh-TW or zh-CN named. |
| Glossary as abstract rule | "Keep terminology consistent." | `glossary_grounding` citing the glossary file path. |
| "Make it sound natural" | "Make it sound natural." | `register` with explicit tone + audience. |
| No source list | "Write about the project." | List the source files in Context; add `source_fidelity`. |
| Asking Gemini to decide | "Decide the best approach and write it up." | Ask it to *synthesise what the sources say*; decisions stay with Claude. |
| Review that turns into a rewrite | "Review and fix this." | `reviewer_role` — flag, do not rewrite. |

## Cross-references

- `task-template.md` — the brief-file shape these blocks slot into
- `examples.md` — concrete end-to-end invocations
- `review-checklist.md` — Claude's publication gate after the run
