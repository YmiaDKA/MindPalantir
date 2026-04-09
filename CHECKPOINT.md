# Checkpoint — April 9, 2026 ~18:00 CEST

## Session summary
Autonomous loop: 10 more iterations (total 19 this session). Living workspace + ingestion + UX polish.

## What changed (10 commits, all pushed)

### Dedup pipeline
- FileIngestor.importToStore checks existing paths before importing
- Watched folder importFile has guard against duplicate paths

### Richer chat context
- BrainContext project pack now includes sources, recent activity, better dedup
- Compressor shows body text for short items, task status in Nearby
- Stats include notes count, sources count

### File type auto-classification
- WatcherService classifies: .md→note, todo files→task, .vcf→person, .ics→event
- Confidence varies: source (0.9), classified types (0.7)

### Auto-link on node creation
- NodeStore.insertNode calls autoLinkMentions — text mentions of existing nodes create relatedTo links
- Bridges manual linking and Hermes classification

### Inspector auto-save
- Replaced manual Save button with debounced 0.5s auto-save on any field change
- onChange handlers for title, body, relevance, confidence, pinned, status
- Subtle "Saved" indicator that fades

### File preview on import
- WatcherService reads first 500 chars of text files (.md, .txt, .swift, etc.) for node body
- Imported nodes show content, not just path

### Project dashboard: Notes card + inline quick add
- Notes card: shows project notes with body preview, timestamps, inline add
- Tasks card: inline "Add task..." text field (Enter to create)
- Both auto-link new items to project
- Fixed bug: insertLink(note) → insertLink(link)

### Sidebar Recent section
- 5 most recently updated nodes in sidebar with colored type icons
- Quick access to last-touched items (Karpathy log.md concept)

### Recent chips: type colors + parent project
- RecentChip shows type icon with Theme.Colors.typeColor
- Shows parent project name in accent purple

### Weekly resurfacing
- New RESURFACING section on Today view
- Items untouched 7-30 days with relevance >= 0.15
- "forgotten but still relevant" — second chance for fading knowledge
- Completes P1 "weekly resurfacing / review" from PRODUCT_CONTEXT.md

## Current repo state
- GitHub: https://github.com/YmiaDKA/MindPalantir
- Branch: main (all pushed)
- Builds clean, 28 Swift files

## Today view sections (complete)
1. Quick Add bar
2. FOCUS — hero project card (navigates to dashboard)
3. PROJECTS — horizontal strip of all active projects
4. TASKS — compact list with inline completion
5. PEOPLE — who matters now
6. UPCOMING — next 7 days events
7. RECENT — horizontal activity strip with type colors + parent project
8. NEEDS ATTENTION — low confidence items (orange)
9. RESURFACING — forgotten-but-relevant items (orange)

## Project dashboard cards
1. Overview (title, progress, stats)
2. Tasks (inline add)
3. Notes (inline add)
4. Activity (recent 14 days)
5. People
6. Events
7. Sources
8. Related (auto-discovered)
9. Watched Folder
10. Quick Add

## What's still missing
1. No preference/taste memory
2. Calendar/event-driven relevance (calendar import exists but not wired to relevance)
3. No multi-project workspace view
4. Chat doesn't know which project user is viewing
5. No mobile/sync

## Build command
```bash
cd ~/SecondBrain && swift build && open .build/debug/MindPalantir
```
