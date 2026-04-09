# Checkpoint — April 9, 2026 ~17:00 CEST

## Session summary
Built MindPalantir improvements in 3 operating loop iterations following HERMES_OPERATING_CONTRACT.md.

## What changed (3 commits, all pushed to GitHub)

### 1. Memory Router (BrainContext.swift)
- **Before:** BrainContext.build(from: store) dumped ALL nodes (130+) into every chat message
- **After:** BrainContext.route(question: store) detects intent, picks anchor (today/project/person/date/task/note), retrieves ~20 nearest nodes, compresses into small context pack
- Matches PRODUCT_CONTEXT.md rule: "The AI should not remember everything. It should know how to fetch the right things."

### 2. Today View — missing sections added (TodayView.swift)
- Added PEOPLE section (connected to active project, or top people by relevance)
- Added UPCOMING EVENTS section (next 7 days)
- Added NEEDS ATTENTION section (low-confidence items, orange styling)
- Now shows all 6 sections from DESIGN_SPEC.md: hero + tasks + people + events + recent + clarification

### 3. Project Detail — workspace improvements (ProjectDetailView.swift)
- Full-width progress bar with X/Y count and percentage
- Stats row: linked items, connections, relative update time
- Inline task completion toggle (tap circle to complete/uncomplete)
- Strikethrough on completed tasks

## Also done earlier this session (before reading the 4 docs)
- SF Symbols migration (all views from emoji to Image(systemName:))
- 8 AI brain tools (delete, list, find_connections, get_node_details)
- Streaming chat with stop button
- Swipe-to-delete in lists and inspector
- FTS5 full-text search with Porter stemming
- Keyboard shortcuts (Cmd+1-8, Cmd+N, Cmd+I)
- Inbox promote workflow

## Current repo state
- GitHub: https://github.com/YmiaDKA/MindPalantir
- Branch: main (all pushed)
- Builds clean, no warnings
- 28 Swift source files

## What's still missing (from PRODUCT_CONTEXT.md)
1. **Project view is not a real workspace yet** — next priority. Needs card dashboard redesign.
2. No Hermes integration (ingestion, classification, routines)
3. No preference/taste memory
4. Relevance engine is formulaic, not adaptive
5. No source import dedupe pipeline

## Next highest-value task
**Redesign ProjectDetailView as a card dashboard.**

The project view should feel like a living workspace for a project (e.g., MindPalantir or MinLønn), not a flat list.

Plan:
- Overview card: title, description, status, progress bar, stats
- Tasks card: open tasks with inline completion, compact rows
- Activity card: recent notes/changes for this project (auto-updates)
- People card: who's connected
- Sources card: files, links, repos

Each card is a self-contained panel following native macOS patterns (cards, panels, drill-down).

Research done: NotebookLM (sources → synthesis), Pickle (present-day awareness), Apple HIG (cards, progressive disclosure, typography hierarchy), swiftui-patterns (native macOS components).

Direction confirmed: card dashboard (not whiteboard, not flat list). Contract says "desktop/dashboard over canvas."

## Files to read first in new session
1. `PRODUCT_CONTEXT.md` — what the app IS
2. `AGENTS.md` — how to work with the codebase
3. `HERMES_OPERATING_CONTRACT.md` — operating loop, invariant, build priority
4. `HERMES_RUNTIME_RULES.md` — runtime behavior, checkpoint rules, Telegram escalation

## Build command
```bash
cd ~/SecondBrain && swift build && open .build/debug/MindPalantir
```
