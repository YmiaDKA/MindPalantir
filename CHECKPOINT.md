# Checkpoint — April 9, 2026 ~18:45 CEST

## Session summary
Second autonomous loop. 8 commits (total ~27 this session). Chat context, calendar sync, preference memory, project cards, Flowdeck integration.

## What changed (all pushed)

### Chat project context
- ChatView gets `focusedProject` param from RootView (navigateToProject)
- BrainContext.route() accepts focusedProject hint
- When anchor is .today and a project is focused, biases to that project
- Header shows focused project name with folder icon

### Calendar periodic sync
- CalendarImporter now syncs every 15 minutes (not just launch)
- Timer in AppDelegate, logs new events count

### Preference/taste memory
- New `accessCount` field on MindNode (Int, persisted to SQLite)
- RootView.onChange(of: selectedNode) tracks access: increments count, updates lastAccessedAt
- MindNode.touch() also increments accessCount
- RelevanceEngine.accessFrequencyScore: combines recency + log-scale count bonus
- DB migration: ALTER TABLE ADD COLUMN access_count DEFAULT 0
- readNode now restores timestamps from DB (was resetting to .now)

### Project card grid dashboard
- ProjectListView redesigned: Cards/List toggle (segmented picker)
- LazyVGrid with adaptive columns (min 280pt)
- ProjectCard: title, body preview, progress bar, stats row, pin indicator, relevance dot
- onOpenProject callback navigates to project dashboard
- RelevanceDot component extracted

### Flowdeck CLI integration
- Installed v1.13.3, license activated (61637459-478B-44AB-81D9-304F3ECD276D)
- `flowdeck ui mac screen/click/type/key` — structured JSON accessibility tree
- Replaces peekaboo for all visual testing
- Skill saved: flowdeck-macos-testing

## Current repo state
- GitHub: https://github.com/YmiaDKA/MindPalantir
- Branch: main (all pushed)
- 29 Swift files, builds clean
- Flowdeck: `flowdeck ui mac screen --app MindPalantir --json`

## Build + test command
```bash
cd ~/SecondBrain && swift build && \
cp .build/debug/MindPalantir .build/debug/MindPalantir.app/Contents/MacOS/ && \
killall MindPalantir 2>/dev/null; sleep 0.5 && \
open .build/debug/MindPalantir.app && sleep 3 && \
flowdeck ui mac screen --app MindPalantir --json
```

## What's still missing
1. No global workspace view (multi-project overview)
2. Chat tool execution doesn't modify store (BrainTools exist but need verification)
3. No undo/history
4. No mobile/sync
5. Inspector could show access count
6. Keyboard shortcuts for navigation

## Architecture notes
- accessCount flows: RootView.onChange → insertNode → SQLite
- RelevanceEngine reads accessCount via MindNode property
- Calendar sync: separate timer, not coupled to RelevanceEngine
- Chat focusedProject is a snapshot (MindNode?), not @Binding — cleared on screen change
