# MindPalantir — Product Context

## Core product
MindPalantir is **not** mainly a notes app, whiteboard app, or graph toy.

It is a **context desktop**: a native macOS app that continuously builds a structured snapshot of the user's work and life, then surfaces what matters **now**.

### Product sentence
**A living desktop that knows what matters now, based on everything it knows about you.**

## North star
When the user opens the app, the Today/Desktop screen should feel like:
- "yes, this is what I should be seeing right now"
- not random
- not equal-weight clutter
- not a blank canvas
- not a file browser

If a feature does not improve that feeling, deprioritize it.

## Main value proposition
Most existing tools solve either capture or structure.
MindPalantir is trying to solve **surfacing**:
- the right project
- the right task
- the right person/event
- the right memory/context
- at the right time

## Main screen philosophy
The Today/Desktop view is the product.

It should show a curated, relevance-ranked snapshot of:
- current main project
- active tasks
- relevant recent notes
- important people / upcoming events
- schedule context
- uncertainty that needs user clarification

It should **not** show everything.
It should **not** be a giant infinite canvas.
It should feel like a brain-powered desktop.

## Data model philosophy
One shared system underneath. Many views on top.

### Rule
**One thing exists once.**
Views are queries, not copies.

A note/task/person/event/project/source can appear in many views through links.

## Core node types for v1
Keep v1 to these 6:
- Project
- Note
- Task
- Person
- Event
- Source

Do not add lots of new types unless clearly necessary.

## Core link types for v1
- belongsTo
- relatedTo
- mentions
- scheduledFor
- fromSource

## Critical computed systems
### Relevance
Determines what shows on Today/Desktop.

Should be influenced by:
- recency
- unfinished/open state
- access/use frequency
- project activity
- event proximity
- user pin/boost
- later: richer graph signals

### Confidence
Determines how sure the system is.

Should be influenced by:
- source quality
- evidence amount
- certainty of classification
- certainty of links
- missing metadata

Low-confidence items should be visible in **Needs Clarification**, not silently treated as facts.

## Memory architecture
MindPalantir should not try to stuff the whole brain into a prompt.
It needs a **Memory Router** / **Context Compiler** approach.

### Principle
The AI should not remember everything.
It should know how to fetch the right things.

### Working layers
- Working memory: current task/question only
- Episodic memory: time-based activity and updates
- Semantic memory: stable facts
- Project memory: long-running clusters
- Preference/taste memory: design/code/style preferences

## Hermes role
Hermes is the organizer/ingestor/routine layer.
It is **not** the main UI.
It is **not** the entire product.

### Hermes should do
- ingest raw text/files/imports
- classify nodes
- summarize nodes
- suggest or create likely links
- update relevance inputs
- update confidence
- route uncertain items to clarification
- generate today context
- run daily organize / weekly resurfacing routines

### Hermes should not do in v1
- invent giant hierarchies from scratch
- auto-delete or auto-merge aggressively
- imitate the user socially
- replace the user in public-facing conversations
- overbuild multi-agent behavior

## UX rules
Prefer:
- native SwiftUI
- calm, structured layout
- cards, panels, sidebars
- drill-down navigation
- familiar app-like behavior

Avoid:
- giant whiteboard-first interaction
- graph-first interaction
- Figma-like canvas complexity as the main shell
- over-abstract editor systems before usefulness is proven

## Current repo direction — what is aligned
The current code is on the right path in these areas:
- native SwiftUI app shell
- local SQLite-backed store
- single node/link source of truth
- Today/Desktop view exists
- Timeline, Inbox, Clarification exist
- basic node/link model matches intended architecture

## Current repo direction — what is still missing
These are the most important gaps between current code and actual product vision:
1. **Today/Desktop is still too static**
   - current main project selection is simplistic
   - relevance is not yet a true surfacing engine
2. **Project view is not a real project dashboard yet**
   - current repo has a project list, not a full project detail workspace
3. **Hermes integration is not real yet**
   - placeholders exist, but ingestion/routines/classification are not implemented
4. **No real Memory Router yet**
   - retrieval/context assembly is not implemented
5. **No true dedupe/source pipeline yet**
   - links dedupe, but imported-content dedupe is still missing
6. **No calendar/event-driven relevance yet**
7. **No preference/taste memory yet**

## Build priority
### P0 — must work
- Today/Desktop usefulness
- real project view
- node/link CRUD stability
- inbox/dump flow
- clarification flow
- relevance and confidence becoming meaningful
- Hermes ingestion hooks

### P1 — next
- watched folder import
- basic Hermes classification/linking
- source metadata and dedupe
- improved project/activity-based relevance
- weekly resurfacing / review

### P2 — later
- map view
- graph view
- large integrations
- richer preference/taste memory
- multi-agent system
- mobile app
- sync

## Explicit non-goals for v1
Do not drift into:
- full life-OS fantasy before Today works
- giant canvas product
- decorative graph product
- collaboration
- social clone / personality replacement
- building everything AFFiNE already does

## Acceptance test for v1
The build is moving in the right direction if, after opening the app, the user can say:
- "this project being on top makes sense"
- "these tasks/notes feel relevant"
- "the uncertainty is shown honestly"
- "this is already more useful than a folder of notes"

## Short build mantra
**This is not a whiteboard app. It is a context desktop.**
