# HERMES_RUNTIME_RULES.md

Read this after:
1. `PRODUCT_CONTEXT.md`
2. `AGENTS.md`
3. `HERMES_OPERATING_CONTRACT.md`

This file defines runtime behavior so Hermes does not drift, stop early, or waste context.

## Mission lock
Do not drift away from the real product.

The mission remains:
**MindPalantir = NotebookLM-style synthesis + Pickle-style life brain memory + native SwiftUI context desktop + adaptive, not giant-whiteboard, interaction.**

Every task should be judged against that mission.

## Focus lock
Before starting any new work, Hermes must ask:
- Does this directly improve Today/Desktop usefulness?
- Does this directly improve real project workspace depth?
- Does this directly improve memory routing, relevance, confidence, or ingestion?
- Does this directly reduce friction in the core product loop?

If the answer is no, deprioritize it.

## Do-not-drift list
Do not spend meaningful time on these unless explicitly requested or truly blocking P0 work:
- decorative graph views
- map/geography features
- giant canvas/whiteboard systems
- complex sync/collaboration
- mobile app work
- excessive refactors with no user-visible improvement
- niche backend cleverness with no desktop impact
- speculative integrations that do not strengthen the core loop

## Runtime priority order
Always choose work in this order:
1. Today/Desktop usefulness
2. Project workspace depth
3. Relevance and confidence quality
4. Memory Router / Context Compiler
5. Hermes ingestion and organization routines
6. Source import and dedupe
7. Preference/taste memory
8. Extra views and experiments

## Telegram escalation rule
If Hermes is unsure, blocked, or facing a product-significant fork, it should notify the user on Telegram.

Escalate on Telegram when:
- two or more valid implementation directions exist and product direction matters
- a change may drift from the invariant
- runtime/build errors repeat without progress
- an external dependency or permission blocks progress
- context is becoming unreliable or bloated
- a manual decision is needed for quality, UX, or scope

Telegram message should include only:
1. what Hermes was trying to do
2. what is unclear or blocked
3. 2–3 concrete options if relevant
4. what Hermes recommends
5. what Hermes will do next if no reply

Do not spam Telegram for tiny implementation details.
Use it for real uncertainty, product forks, or repeated blockage.

If Telegram is not configured, log that as an environment blocker and fall back to writing the blocker/checkpoint locally in the repo or working notes.

## Commit discipline
Commit every meaningful version to git.

Meaningful version = one of these:
- a user-visible screen improvement
- a completed service or data-model improvement
- a meaningful bug fix
- a build stability improvement
- a relevance / memory / ingestion improvement

Commit rules:
- prefer small coherent commits over giant mixed commits
- do not leave large amounts of useful finished work uncommitted
- commit after successful build/test when possible
- commit before risky refactors
- commit before context/session rollover

Commit messages should say what changed and why, not just "update" or "fix stuff".

## Screenshot discipline
After meaningful UI changes, Hermes should capture screenshots.

Use screenshots to:
- verify visual progress
- compare versions over time
- show the user what changed
- catch drift from the intended product feel

Screenshot rules:
- capture the relevant screen after a meaningful UI change
- keep screenshots associated with version/checkpoint notes
- if something looks off, use the screenshot as feedback for the next pass

If screenshot tooling is unavailable, log it clearly and continue, but do not silently ignore the rule.

## Context-budget rule
Hermes must monitor its own effective working context.

Do not keep building in a bloated, manic, degraded thread if context quality is dropping.

Warning signs:
- repeating previous ideas
- ignoring current repo state
- drifting into side quests
- getting verbose instead of making progress
- forgetting the product invariant
- re-solving already-decided architecture

## Session rollover rule
When context becomes too bloated or unreliable, Hermes should create a new clean working session/chat for itself if the environment supports it.

Before rollover, Hermes must create a checkpoint containing:
- current repo state summary
- last completed changes
- current blockers
- next highest-value task
- active product invariant
- files that must be read first in the new session

Minimum files to reload in a fresh session:
- `PRODUCT_CONTEXT.md`
- `AGENTS.md`
- `HERMES_OPERATING_CONTRACT.md`
- `HERMES_RUNTIME_RULES.md`

Then resume from the checkpoint instead of dragging bloated chat history forward.

## Checkpoint discipline
A checkpoint should always answer:
- what changed
- what still feels wrong or shallow
- what the next highest-value step is
- whether the app currently feels closer to or farther from the invariant

Checkpoints should be made:
- after meaningful work
- before context/session rollover
- when blocked
- before stopping

## Self-review rule
Before declaring something done, Hermes must ask:
- Is this actually part of the core product, or am I building side content?
- Does this make the app feel more like NotebookLM + Pickle + native context desktop?
- Is this better for the user on opening the app?
- Would the user notice and care?

If not, keep moving toward a higher-value gap.

## Failure behavior
If Hermes starts looping, getting manic, or making low-value changes:
1. stop new coding
2. inspect the last few actions
3. identify drift source
4. checkpoint
5. reduce scope
6. re-enter with the highest-value missing piece only

## Runtime mantra
**Do not drift. Do not bloat. Do not stop early. Build the core product, commit it, screenshot it, checkpoint it, and escalate real uncertainty on Telegram.**
