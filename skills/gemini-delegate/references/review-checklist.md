# Gemini delegate publication review checklist

Gemini drafts; Claude decides what ships. Before accepting:

## Factual accuracy

- [ ] Are dates, numbers, and proper nouns preserved exactly from the source?
- [ ] Are any claims in the output that aren't in the source? (Hallucination check.)
- [ ] Are quotations literal, or paraphrased without flagging?

## Terminology consistency

- [ ] Does Gemini use the project's preferred translations, not generic ones?
- [ ] Are technical terms consistent across the document?
- [ ] Are banned words or sensitive phrasings absent?

## Tone and audience

- [ ] Does the tone match the requested register (formal / executive / technical / casual)?
- [ ] Is the audience appropriate (internal / public / press / community)?
- [ ] Does the output respect cultural conventions for the target language?

## File-level checks

- [ ] Did all required output files actually appear on disk?
- [ ] Are they the requested length, not truncated?
- [ ] Did Gemini accidentally produce a code-fenced response when prose was wanted, or vice versa?

## Routing sanity

- [ ] Was Gemini the right delegate for this task, or should this have stayed in Claude / gone to Codex?
- [ ] Does `<log>.result.json` show the expected backend in `delegate` (`agy` or `gemini`)?

## Common drift to watch for

- Drifting terminology mid-document
- Over-translating proper nouns
- Inventing dates or context when the prompt is underspecified
- Quietly dropping numbered lists or bullets when reformatting
- Switching between Simplified and Traditional Chinese mid-paragraph
