---
name: clear-writing
description: |
  House writing style for the prose that ships with Hoist code: CHANGELOG entries, PR descriptions, READMEs and design docs, code comments. Why this matters: unaided agents write durable text that is too long and reads as machine-made. Sentences run past 25 words and join with semicolons and em dashes, passive voice hides the actor, "leverage" and "seamless" creep in, and a PR body restates the diff and lists every file. That text lands in CHANGELOGs and PRs that humans read for years. TRIGGER when writing or updating a CHANGELOG entry or release notes; writing a PR title or description; writing a new document or substantially editing one (README, design doc, guide, ADR, CLAUDE.md, wiki page); reviewing a diff, branch, or PR that includes comments, JSDoc, or docs; or any ask to make text clearer, shorter, plainer, more readable, less verbose, less wordy, or less like AI wrote it. SKIP for a single code comment or commit message written in the normal flow of coding (apply the same rules, do not load the skill), chat replies to the user, code and identifiers, UI strings and error messages, and marketing copy.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Clear Writing

House style for the prose XH ships with its code: CHANGELOG entries, PR descriptions, READMEs
and docs, code comments, commit messages. The rules are the mechanical subset of ASD-STE100
Simplified Technical English plus one XH rule: no em dashes. They remove the run-on sentences,
the passive voice, and the filler that mark text as machine-written. They do not apply to code,
identifiers, command syntax, UI strings, or chat replies.

## Three uses

- **Write.** Produce new text under these rules.
- **Rewrite.** Change only what breaks a rule or repeats another passage. Everything else stays
  as written. Keep every fact.
- **Review.** Do not rewrite the document. Output a table `Passage | Rules broken | Replacement`
  with one row per passage, not per violation. Name the rules in a few words. Give one
  replacement the author can paste, or say "delete it".

Rewrite length: shorter is the default, and a change that adds words must buy clarity the reader
can feel. Splitting a sentence, naming an actor, and unpacking an aside all cost words, so do them
where they help and not by habit. Report the linter's `words` count before and after.

Review details: put a multi-line replacement in a code block after the table and point the cell
at it. Close with one line on anything you left alone, and why. Lint a copy of the review with
the Passage column removed, so the quoted originals do not count against you.

Lint first, in every mode. If the text already scores under target, fix only the hard failures
(em dashes, semicolons, contractions, sentences over the cap) and stop.

## Shape by artifact

Start from the shape. Most bloat is structural, not lexical.

**CHANGELOG entry.** One bullet per change, one to three lines. Lead with what changed for the
reader, then the essential why. Put it under the section the project uses (Breaking Changes,
New Features, Bug Fixes, Technical, Libraries). If the section is missing, add it in the order
the project's older entries use.

Name an identifier only when the reader needs it to act: a config key, a flag, a public API.
Leave out internal method names, file paths, exact counts, and version comparisons. Those rot.

**PR description.** Title: imperative, under 70 characters, no semicolon. Body, in this order:
why, in one or two sentences. What changed, as a short bullet list. How to verify, with any
dependency on another branch or an unreleased build stated first. Nothing else: the diff
already lists the files.

**Commit message.** Subject: imperative, under 72 characters. Body: the why, in short
sentences.

Do not hard-wrap a commit body or a PR body. Write each paragraph as one line and let GitHub
and the other display tools wrap it.

**Code comment.** Say why, not what the code plainly does. One or two sentences. No "this
function" narration. A fact the code states itself is not a fact the comment must keep.

Comments and PR descriptions describe the code as it is now, not how it got there. No "no longer
X, now Y", no record of what changed during review, no work-in-progress notes. Bring in the past
only when the reader cannot understand the present without it.

**README, CLAUDE.md, and guides.** Answer three questions in order: what it is, how to use it,
what it depends on. Then the details. One topic per paragraph.

State each rule once. If two passages say the same thing, keep the one at its natural home and
link to it from the other. A pitfalls or FAQ section that restates a rule with its consequence is
a recap, not a duplicate.

**Reference and API docs.** A table beats prose for an option, field, or method list. A table
cell is a label, not a sentence: no length cap, no article rule, one grammatical form down each
column. The word and voice rules still apply inside a cell. Heading text is a link anchor. Do
not change it for style.

## Rules

Numbers in parentheses are rule numbers in ASD-STE100 Issue 9.

**Words**

- One name for one thing (1.11). Pick check, verify, or validate and reuse it. In framework
  docs, name the framework and use that name every time.
- Use the short common word: use (not `utilize`, `leverage`), start (not `initiate`), help
  (not `facilitate`), make sure (not `ensure`), do (not `perform`), before (not `prior to`),
  about (not `regarding`), get (not `obtain`), show (not `demonstrate`), also (not
  `additionally`, `furthermore`, `moreover`), but (not `however`), because (not `since`, for a
  cause). The linter flags a longer list of the same kind and names each hit.
- Keep the modality of the source. `should` stays `should` for a recommendation. Use `must`
  only for a true requirement, one that breaks something when ignored. Use `can` for
  possibility, and keep `may` for permission. That swap does not change strength. Never raise or
  lower the strength of a claim.
- No marketing adjectives: `seamless`, `robust`, `powerful`, `effortless`, `comprehensive`.
- Define an abbreviation at first use, with the expansion in parentheses. Skip terms every
  reader of the doc uses daily: API, UI, ID, URL, HTTP, JSON, SDK, and the acronyms of the
  project's own stack.
- American spelling (1.14).

**Verbs**

- Active voice (3.6). "The store reloads the records", not "the records are reloaded by the
  store". A participle used as an adjective is correct: "the field is required" (3.3).
- Active voice needs an actor. In how-to prose the reader is one: "Define routes in your
  AppModel." If the source names no actor and the reader is not one, keep the passive and flag
  it. Do not invent an actor.
- Simple tenses only (3.2). "We removed the flag", not "we have removed the flag".
- A verb for an action (3.7). "Analyze the log", not "perform an analysis of the log".
- No phrasal verbs (9.3): `spin up`, `kick off`, `roll out`, `dive into`.

**Sentences**

- One idea per sentence. Max 20 words for an instruction, 25 for anything else (5.1, 6.3).
  Split a sentence only when it is over its cap or holds two instructions. A sentence that
  already complies stays whole.
- When you split, keep the logic. A condition, a cause, or a consequence stays tied to the
  clause it governs, with "if", "because", or "so". A benefit of following advice stays
  conditional. Do not restate it as a fact about the system.
- Condition first, then a comma, then the command (5.4): "If the build fails, read the log."
  Commands only. A descriptive sentence keeps its own order.
- Keep the articles (4.2). "Remove the bolts from the panel", not "Remove bolts from panel". A
  list item that is a label can stay a label.
- No contractions.
- No parenthetical asides in running prose, that is, commentary the reader can skip. Cut the
  aside or give it a sentence. Parentheses that hold notation stay: an identifier, a type, a
  default, a unit, a version, an abbreviation gloss, a cross-reference. Parentheses that carry a fact also stay,
  in place or folded into the sentence with commas. A fact can become its own sentence only if
  it stays descriptive. Never turn it into a claim the source did not make.
- Write "for example", not `e.g.`, and "that is", not `i.e.`.
- A multi-word noun has at most three words (2.1). Unpack "the grid column chooser persistence
  key" into "the persistence key for the column chooser".

**Punctuation**

- No semicolons (8.1). Write two sentences.
- No em dashes or en dashes, and no `--` in their place. Use a comma, a period, a colon before
  a list or a literal, or a hyphen with a space on each side.

**Paragraphs**

- One topic per paragraph, max six sentences (6.5, 6.6). A table is not a paragraph.
- Steps the reader performs go in a numbered list, one action per item, imperative form. A
  list that describes what code does stays descriptive.

## Guards

When a rule and a guard conflict, the guard wins.

- Never drop a fact, number, condition, or qualifier to hit a length cap. Keep the longer
  sentence and flag it.
- Never add a fact, actor, or claim the source does not make.
- When you include an identifier, path, error string, or quoted UI text, keep it exact. Heading
  text is an anchor target: treat it the same way.
- When you remove a duplicate, diff it against the copy you keep. Merge any option, value, or
  example that only the dropped copy had. Code examples are content, not prose.
- If the text already complies, return it unchanged and say so.

## Verify

Lint any prose over about 40 words before you present it or write it to a file:

```
python3 "${CLAUDE_PLUGIN_ROOT}/skills/clear-writing/scripts/ste-lint.py" draft.md
```

If `${CLAUDE_PLUGIN_ROOT}` is empty, use the folder that holds this SKILL.md.

The one-line output ends with `per100w=` and `em_dash=`. Target: under 2.5 and zero. Fix the
reported categories, lint once more, then stop. Two passes at most. Report those two numbers
in your reply, not inside the deliverable.

The linter flags sentences over 25 words. Find instructions over 20 words by hand.

Only `total` counts toward the target. The markers outside it are hints: the noun-train count,
sentences of 21 to 25 words, and em dashes inside code fences. Code-fence em dashes are not yours
to fix. If a hit is a false positive, leave the text alone and say so next to the score.

Use `--json` for the breakdown and for `sample_hits`, which names the matched span in each
category. Use `--fail-over 2.5` for an exit code. Pipe from stdin for text not yet in a file.

The score is a heuristic. It counts form, not truth. A paragraph can score 0.0 and still say
nothing, and a rewrite can score better while it reads worse. The Guards outrank the score. If
the word count grew more than a little, you should be able to say what the extra words bought.

If you cannot run commands, check by hand for:

- sentences over 20 words (instruction) or 25 words (anything else)
- semicolons, em dashes, contractions
- has or have plus a participle, passive voice with a known actor, "-ing" main verbs
- nominalizations, phrasal verbs, four-word noun strings
- dropped articles, and two names for one thing

## Provenance

Derived from the `asd-ste100` skill by Ege Chelebi (MIT). See `NOTICE.md` in this folder. The
full ASD-STE100 standard is free at https://asd-ste100.org. Do not paste it. ASD holds the
copyright. This skill is unofficial and not affiliated with ASD.
