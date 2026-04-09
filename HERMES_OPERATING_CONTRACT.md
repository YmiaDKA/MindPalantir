# HERMES_OPERATING_CONTRACT.md

Read this after `PRODUCT_CONTEXT.md` and `AGENTS.md`.

This file exists to stop drift, early stopping, and vague agent behavior.

## Core invariant
MindPalantir must always move toward this exact product shape:

**NotebookLM-style synthesis + Pickle-style life brain memory + a native SwiftUI context desktop that adapts automatically without becoming a giant whiteboard.**

Expanded:
- **NotebookLM-style synthesis**
  - strong summarization
  - context-aware recall
  - useful synthesis across sources
  - not just raw storage
- **Pickle-style life brain memory**
  - life + work memory
  - persistent context across time
  - relevance-ranked present-day awareness
  - not flat equal-weight bubbles
- **Native SwiftUI context desktop**
  - calm, app-like, Apple-native feel
  - cards, panels, sidebars, drill-down
  - more desktop/dashboard than canvas
  - adaptive and interactive
  - not too whiteboardy

This invariant is non-negotiable.

## Product interpretation rules
When making product decisions, prefer:
- synthesis over raw dumping
- context desktop over canvas
- relevance over equal-weight display
- useful hierarchy over decorative graphing
- interaction and surfacing over abstract visual novelty
- native SwiftUI feel over web-tool feel

Avoid drifting into:
- giant infinite whiteboard
- decorative graph toy
- generic notes app
- generic task manager
- social clone/personality replacement
- backend-only memory tool with no product feel

## Operating objective
Hermes should not merely generate code.
Hermes should continuously move the repository toward the real product.

Main objective:
**Make MindPalantir feel like a brain-powered desktop that already knows what matters now.**

## Anti-give-up rule
Do not stop after one pass if the result is obviously incomplete, shallow, placeholder-like, or off-invariant.

Do not treat:
- a stub view
- a fake placeholder service
- a naive scoring system
- a one-pass sketch
as finished work when it clearly does not satisfy product intent.

If the result is still structurally wrong, continue iterating.

## Required operating loop
Run in a loop:

1. **Inspect**
   - inspect current repo state
   - inspect current product files
   - inspect implemented screens/services/models
   - compare actual implementation against the invariant

2. **Gap-detect**
   - identify highest-value mismatch between current code and target product
   - rank by user-visible impact

3. **Plan**
   - choose the smallest meaningful next improvement
   - avoid overbuilding adjacent systems first

4. **Implement**
   - make concrete repo changes
   - prefer working code over vague scaffolding

5. **Test**
   - build
   - run
   - inspect runtime behavior
   - verify no obvious regressions

6. **Review**
   - ask: does this make the product feel more like NotebookLM + Pickle + native context desktop?
   - if no, revise

7. **Checkpoint**
   - write down what changed
   - write down what remains broken or shallow
   - write down the next highest-value step

Then repeat until blocked.

## Blocked-state rule
If blocked:
- do not silently stop
- do not pretend complete
- write the blocker clearly
- save current checkpoint/state
- choose the next adjacent high-value task that is still unblocked
- continue useful work

## Heartbeat / watchdog behavior
Hermes should behave like a persistent worker, not a one-shot code generator.

Conceptually maintain:
- **heartbeat**: periodic liveness and progress signal
- **watchdog**: detect no-progress, crash, or repeated failure
- **checkpointing**: save plan, completed work, open problems, next step
- **planner/executor/reviewer loop**: think, do, inspect, improve

Practical rule:
If progress stalls, switch from build mode to diagnosis mode.
If diagnosis succeeds, return to build mode.
If a feature is too uncertain, reduce scope and keep moving.

## Research behavior
Hermes is allowed and expected to inspect adjacent products, frameworks, and repos to improve decisions.

Research should support the invariant, not distract from it.

Primary external reference products:
- **NotebookLM** → synthesis, summarization, contextual research feel
- **Pickle** → life memory / present-day awareness / brain snapshot feel
- **MemPalace** → hierarchical memory retrieval, layered recall, hooks, context loading
- **AFFiNE / BlockSuite** → structure ideas only, not frontend direction

Research questions Hermes should keep asking:
- what makes NotebookLM feel useful beyond search?
- what makes Pickle’s memory feel alive, and what are its UX weaknesses?
- what backend memory ideas from MemPalace are useful without turning MindPalantir into a geek CLI tool?
- how can these ideas be translated into a native SwiftUI desktop experience?

## Current strategic truth
MindPalantir is not trying to win by being the deepest CLI memory engine.
It is trying to win by turning good memory + retrieval into a product that feels instantly useful and visually familiar.

That means:
- backend ideas are useful
- but frontend usefulness is the wedge
- the Today/Desktop experience remains the top priority

## Build priority order
Always prefer work in this order:

1. **Today/Desktop usefulness**
2. **Real Project workspace depth**
3. **Relevance and confidence becoming meaningful**
4. **Memory Router / Context Compiler**
5. **Hermes ingestion and organization routines**
6. **Source import + dedupe pipeline**
7. **Preference/taste memory later**
8. **Map/graph/extra views much later**

## What “done” means for any feature
A feature is not done because it exists.
A feature is done when it improves the actual product feel.

Examples:
- Today screen is not done because cards render
- Today screen is done when what appears there feels plausibly right
- Project view is not done because a list exists
- Project view is done when a project actually feels like a living workspace
- Hermes integration is not done because a service stub exists
- Hermes integration is done when raw input actually becomes better structured context

## Memory architecture rule
Do not treat conversation history as the main memory.
Conversation history is only **working memory**.

Use a retrieval/routing model:
- detect intent
- choose anchor (Today / Project / Person / Date / Event / Source)
- retrieve nearest relevant nodes
- compress into a context pack
- answer or act from that

This should evolve toward a **Memory Router / Context Compiler**.

## Keep these product truths loaded
MindPalantir should feel like:
- a context desktop
- a brain snapshotter
- a surfacing engine
- a living project-and-life memory layer

MindPalantir should not feel like:
- an infinite canvas
- a graph gimmick
- a database admin tool
- a backend-only memory benchmark project

## If uncertain
Choose the option that makes the app feel:
- more native
- more relevant
- more adaptive
- more calm
- more obviously useful on opening

## Short operational mantra
**Do not just store memory. Route it, surface it, and make it feel alive in the desktop.**
