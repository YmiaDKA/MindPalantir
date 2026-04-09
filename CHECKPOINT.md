# Checkpoint — April 9, 2026 ~17:30 CEST

## Session summary
Autonomous loop: 8 iterations. UX consistency pass + living workspace features.

## What changed (8 commits, all pushed)

### 1. Multi-signal relevance engine (RelevanceEngine.swift)
- Replaced disconnected formula with 7 weighted signals: recency (0.25), open state (0.20), connections (0.15), project activity (0.15), event proximity (0.10), access frequency (0.10), pin boost (0.05)
- Completed/archived get steep penalties (0.05/0.02 floor)
- Exponential decay half-lives: recency 7 days, access 3 days

### 2. Project card dashboard (ProjectDetailView.swift)
- Complete redesign: flat list → card dashboard with AdaptiveCardGrid (2-column)
- 6 cards: Tasks, Activity, People, Events, Sources, Quick Add
- DashboardCard reusable component, Overview card with progress/stats

### 3. Auto-discovered related content
- Project finds nodes mentioning its title even without explicit links
- One-click link button to connect discovered content

### 4. Watched folder (Karpathy wiki insight)
- Point project at directory via NSOpenPanel
- Scans for new files, one-click import or batch import all
- FileIngestor.scan() accepts custom paths

### 5. Auto-link from ingestion
- WatcherService auto-links imported files to projects they mention
- Closes the loop: file lands → ingested → linked → shows in project

### 6. Full UX consistency pass
- ALL views now use Theme.Fonts, Theme.Spacing, Theme.Radius, Theme.Colors
- NodeListView, TimelineView, ChatView, InboxView, ClarificationView, QuickAddBar
- Removed hardcoded .purple → Theme.Colors.accent everywhere
- Removed raw spacing numbers (8, 10, 14) → Theme.Spacing.sm/md/lg
- Removed raw corner radii (6, 8, 10, 12) → Theme.Radius.chip/card
- Node type icons now colored via Theme.Colors.typeColor

### 7. Navigation fix
- Clicking project in Today/sidebar → navigates to ProjectDetailView (was: opens inspector)
- Back button to return from project dashboard
- onOpenProject callback pattern, clean architecture
- Screen change clears project navigation

### 8. Sidebar improvements
- Screen items show node counts (e.g., "Tasks 12")
- Active screen icon highlights with Theme.Colors.accent
- Project sidebar shows open task count
- Removed dead GraphOverlay.swift (hardcoded white, never wired up)

### 9. Today view: all projects strip
- Horizontal card strip showing all active projects (not just focus one)
- Mini progress bars, task counts
- Tapping navigates to project dashboard

## Current repo state
- GitHub: https://github.com/YmiaDKA/MindPalantir
- Branch: main (all pushed)
- Builds clean, no errors (pre-existing warnings in DataSeeder, ICloudScanner)
- 28 Swift source files

## What's still missing
1. No Hermes integration (ingestion, classification, routines)
2. No preference/taste memory
3. Relevance engine is better but could use ML signals
4. No source import dedupe pipeline (same file imported twice)
5. Chat view needs richer context from project workspaces

## Next high-value tasks
- **Chat context from project workspace** — when chatting about a project, the AI should see that project's full context (tasks, notes, files)
- **Dedupe pipeline** — prevent re-importing same files
- **Hermes auto-classification** — file watcher should classify new files as task/note/source instead of always creating source nodes
- **Project activity timeline** — chronological changes within a project

## Build command
```bash
cd ~/SecondBrain && swift build && open .build/debug/MindPalantir
```
