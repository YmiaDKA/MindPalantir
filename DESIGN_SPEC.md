# MindPalantir — Design & Architecture Spec
*Compiled from Apple HIG, PKM research, and real-world workflows*
*April 9, 2026*

---

## 1. Design Principles (Non-Negotiable)

### Typography IS the design
- Don't use color, borders, or icons to create hierarchy — use **font size and weight**
- macOS built-in text styles:
  - `Large Title` (26pt, Regular) — for the focused item (hero project name)
  - `Title 2` (17pt, Regular) — section headers within content
  - `Headline` (13pt, Bold) — card titles, list row titles
  - `Body` (13pt, Regular) — descriptions, content
  - `Caption 1` (10pt, Regular) — metadata, timestamps, badges
  - `Footnote` (10pt, Regular) — secondary info
- Use **one typeface**: SF Pro (system default)
- **Bold** for emphasis, never italic or underline
- **Tracking**: Use system defaults, don't adjust manually

### Color IS accent, not decoration
- **One accent color** for the entire app (purple)
- Type colors are **only for meaning**: red = overdue/danger, green = completed, orange = warning
- Use **system dynamic colors** for backgrounds (`NSColor.controlBackgroundColor`, `NSColor.windowBackgroundColor`)
- Text colors: `labelColor` (primary), `secondaryLabelColor` (secondary), `tertiaryLabelColor` (metadata)
- **Never** use color as the only indicator of state — always pair with text or symbol

### Progressive disclosure
- Show the **minimum viable information** at each level
- Today: 1 hero item + task list + recent strip
- Project: title + progress + open tasks
- Inspector: full details when you click
- **Never** show more than 7±2 items in a list without scrolling

### Spacing creates structure
- Card padding: 16pt (lg)
- Between cards: 12pt (md)
- Between sections: 24pt (xl)
- Internal element spacing: 8pt (sm)
- No borders between elements — use **negative space** as separator

### SF Symbols — don't use emoji
- Sidebar: `square.grid.2x2` (Today), `brain.head.profile` (Chat), `folder` (Projects)
- Type indicators: `folder.fill`, `checkmark.circle`, `doc.text`, `person.fill`, `calendar`, `link`
- Use **hierarchical rendering** for multi-tone symbols
- Use **outline variant** in sidebars and toolbars, **fill** in tab bars

---

## 2. Information Architecture

### What the user sees (hierarchy)

```
Window
├── Sidebar (leading, ~200pt)
│   ├── HOME
│   │   ├── Today
│   │   └── Chat (AI)
│   ├── ORGANIZE
│   │   ├── Projects
│   │   ├── Notes
│   │   └── Tasks
│   └── BROWSE
│       ├── Timeline
│       ├── People
│       └── Sources
│   └── ─── (separator)
│       └── [Active Projects inline — max 5]
│
├── Content (flexible width)
│   └── Varies by selected screen
│
└── Inspector (trailing, ~300pt, collapsible)
    └── Shows details of selected node
```

### Screen designs

#### Today (primary screen — this is where users live)
```
┌──────────────────────────────────────────┐
│  [Quick Add]          128 nodes · 3 tasks │  ← toolbar
├──────────────────────────────────────────┤
│                                          │
│  FOCUS                                   │  ← section label (tiny, uppercase, tracked)
│  ┌────────────────────────────────────┐  │
│  │ 📁 MindPalantir                   │  │  ← hero card, large title
│  │ The second brain app — native      │  │
│  │ macOS SwiftUI with SQLite...       │  │
│  │                                    │  │
│  │ ████████░░ 7/12 tasks  ·  77 links │  │  ← stats row
│  └────────────────────────────────────┘  │
│                                          │
│  TASKS                                   │
│  ┌────────────────────────────────────┐  │
│  │ ○ Build Hermes ingestion        ●  │  │  ← compact rows, relevance dot
│  │ ○ File watcher for inbox        ●  │  │
│  │ ○ Weekly review                 ○  │  │
│  └────────────────────────────────────┘  │
│                                          │
│  RECENT                                  │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐   │
│  │📝    │ │📁    │ │🔗    │ │📅    │   │  ← horizontal scroll chips
│  │Arch..│ │TIE.. │ │Git.. │ │Meet..│   │
│  └──────┘ └──────┘ └──────┘ └──────┘   │
└──────────────────────────────────────────┘
```

#### Chat
```
┌──────────────────────────────────────────┐
│  🧠 Brain Assistant              [Clear] │
├──────────────────────────────────────────┤
│                                          │
│  (empty state with suggestion chips)     │
│                                          │
│  "What projects am I working on?"        │
│  "What's most important right now?"      │
│  "Find connections I'm missing"          │
│                                          │
├──────────────────────────────────────────┤
│  [Type a message...]              [Send] │
└──────────────────────────────────────────┘
```

#### Projects List
```
┌──────────────────────────────────────────┐
│  Projects                                │
├──────────────────────────────────────────┤
│  📁 MindPalantir                    📌  │
│     ████████░░ 7/12 · 77 items          │
│                                          │
│  📁 TIE — Clothing Brand                │
│     ██░░░░░░░░ 1/5 · 23 items           │
│                                          │
│  📁 RYDDE — Poster Design               │
│     ░░░░░░░░░░ 0/0 · 12 items           │
│                                          │
│  📁 OsloMet — Design & Dev              │
│     ██████░░░░ 3/6 · 18 items           │
└──────────────────────────────────────────┘
```

#### Inspector (right panel)
```
┌────────────────────────────┐
│  📁                        │
│  PROJECT                   │
│  #A1B2C3                   │
│                            │
│  MindPalantir         [📌] │  ← title, editable
│  ────────────────────────  │
│  The second brain app...   │  ← body, editable
│                            │
│  STATUS                    │
│  [Active] [Done] [Draft]   │
│                            │
│  SCORES                    │
│  Relevance  ████████░░ 80% │
│  Confidence ██████████ 95% │
│                            │
│  CONNECTIONS (12)          │
│  📝 Architecture: SQLite   │
│  ✅ Build project view     │
│  👤 Ibrahim                │
│  🔗 Hermes Agent v0.8      │
│                            │
│  INFO                      │
│  🕐 Apr 8, 2026 4:34 AM   │
│  ↳ auto_seed               │
│                            │
│  [Save Changes]        ✓   │
└────────────────────────────┘
```

---

## 3. Color System

### Dark mode first (default on macOS)
```swift
// Backgrounds (use system colors)
Color(NSColor.windowBackgroundColor)       // main bg
Color(NSColor.controlBackgroundColor)      // card bg
Color(.ultraThinMaterial)                  // floating elements

// Text
Color(.primary)     // main text (white in dark)
Color(.secondary)   // secondary text
Color(.tertiary)    // metadata, timestamps

// Accent (single color for entire app)
Color.purple        // links, selections, primary actions

// Semantic
Color.green         // completed, success
Color.red           // overdue, error
Color.orange        // warning, low confidence
Color.blue          // info, links
```

### Why this works
- System colors auto-adapt to light/dark mode
- Single accent color = no visual noise
- Semantic colors are universally understood

---

## 4. Card Design Patterns

### Focus Card (hero — used for the primary project)
- **Size**: Full width, auto height (~160pt)
- **Background**: `NSColor.controlBackgroundColor` with `cornerRadius: 10`
- **Border**: `accentColor.opacity(0.15)` — barely visible
- **Title**: `.largeTitle()` — 26pt bold
- **Description**: `.body()` — 13pt, secondary color, max 3 lines
- **Stats row**: Progress bar + link count + relevance bar
- **Tap**: Opens in inspector

### Task Row (compact — used in Today and list views)
- **Height**: ~32pt
- **Background**: Transparent (grouped with siblings in a card)
- **Checkbox**: SF Symbol `circle` / `checkmark.circle.fill`
- **Title**: `.body()`, strikethrough if completed
- **Relevance dot**: 5pt circle, color = relevance
- **Tap**: Selects (opens inspector)

### Recent Chip (horizontal scroll)
- **Size**: 120×60pt
- **Background**: `controlBackgroundColor.opacity(0.6)`, `cornerRadius: 6`
- **Content**: Type icon + relative time + title (2 lines)
- **Tap**: Selects (opens inspector)

### Source Chip (inline pills)
- **Height**: ~24pt
- **Shape**: Capsule
- **Background**: `.quaternary.opacity(0.5)`
- **Content**: Type emoji + title (1 line)

---

## 5. Data Model — What Goes In

### Node types (6 only — no more)
| Type | Icon | Purpose |
|------|------|---------|
| `project` | 📁 | A thing you're working on |
| `task` | ✅ | A specific action item |
| `note` | 📝 | A thought, idea, or piece of info |
| `person` | 👤 | Someone in your life |
| `event` | 📅 | A calendar event or meeting |
| `source` | 🔗 | A file, URL, or reference material |

### Link types (5 only)
| Type | Direction | Example |
|------|-----------|---------|
| `belongsTo` | task → project | "Build view" belongs_to MindPalantir |
| `relatedTo` | any ↔ any | Project A related_to Project B |
| `mentions` | any → person | Project mentions Ibrahim |
| `scheduledFor` | event → date | Meeting scheduled_for April 10 |
| `fromSource` | any → source | Note from_source Safari bookmark |

### Node properties
```swift
struct MindNode {
    id: UUID              // immutable
    type: NodeType        // enum
    title: String         // primary text
    body: String          // rich text / description
    createdAt: Date       // immutable
    updatedAt: Date       // changes on edit
    lastAccessedAt: Date  // changes on view
    relevance: Double     // 0-1, auto-calculated
    confidence: Double    // 0-1, how sure we are
    status: NodeStatus    // active/completed/archived/draft/waiting
    pinned: Bool          // manual priority boost
    sourceOrigin: String? // "quick_add", "import", "calendar", etc.
    metadata: [String: String]  // flexible key/value
    dueDate: Date?        // for tasks/events
}
```

---

## 6. Relevance Scoring — How Importance Works

### Formula
```
relevance = typeWeight + recencyScore * 0.3 + connectionScore * 0.2 + pinnedBoost - statusPenalty
```

| Factor | Weight | Calculation |
|--------|--------|-------------|
| Type base | 0.1–0.3 | project=0.3, task=0.25, event=0.25, person=0.2, note=0.15, source=0.1 |
| Recency | 0–1.0 | `max(0, 1.0 - daysSinceUpdate / 30)` |
| Connections | 0–1.0 | `min(1.0, linkCount / 5.0)` |
| Pinned boost | +0.2 | if pinned |
| Completed penalty | -0.3 | if status=completed |
| Archived penalty | -0.5 | if status=archived |

### Decay
- Every 5 minutes, relevance decays: `relevance *= exp(-daysSinceAccess / 30)`
- Pinned items skip decay
- A project untouched for 30 days drops to ~37% of its relevance

### What drives relevance UP
- User opens/views the item (+0.03 per view)
- New links are created to/from the item
- User pins it (+0.2 boost)
- Calendar event approaches (within 3 days = boost)

---

## 7. AI / Chat — Brain Context Architecture

### How the AI sees your data (RAG)
1. **System prompt** includes full brain dump:
   - All active projects (title, relevance, task counts)
   - All open tasks (title, due date, relevance)
   - All people (name, description)
   - Recent notes (last 7 days)
   - Top connected items
   - Low-confidence items needing clarification
2. **User message** is the question
3. **AI response** streams back in real-time

### System prompt template
```
You are the AI assistant for MindPalantir, a personal second brain.
You have full access to the user's brain data below.
Your job: help organize, find connections, ask clarifying questions, and surface relevant info.
Be concise. Be specific to THEIR data. Ask questions when uncertain.

## Active Projects
📁 MindPalantir — relevance: 95% (7 open tasks)
📁 TIE — Clothing Brand — relevance: 60%
...

## Open Tasks
- Build Hermes ingestion [relevance: 70%]
- File watcher for inbox [relevance: 70%]
...

## People
- Ibrahim: Lead developer. Building MindPalantir...

## Recent Notes (last 7 days)
- Architecture: SQLite + SwiftUI: Single SQLite database...

## Most Connected Items
📁 MindPalantir: 77 connections
👤 Ibrahim: 12 connections
...
```

### Model selection
- Default: `google/gemma-4-26b-a4b-it:free` (free, good quality)
- Fallback chain: Gemma 4 → Gemma 3 27B → Llama 3.3 70B → Hermes 3
- All via OpenRouter, free tier

---

## 8. Ingestion Sources (Priority Order)

### Phase 1 (built)
1. ✅ **Quick Add** — manual text entry with type detection
2. ✅ **File Scanner** — scans Documents, Desktop, Downloads
3. ✅ **Safari Importer** — bookmarks, reading list, history
4. ✅ **iCloud Scanner** — project folders, files
5. ✅ **Watcher** — auto-imports new files in watched directories

### Phase 2 (partially built)
6. 🔄 **Calendar** — EventKit, temporal anchors
7. 🔄 **AI Chat** — creates nodes from conversation

### Phase 3 (planned)
8. ⏳ **Photos** — PHPhotoLibrary, metadata only (dates, locations)
9. ⏳ **iMessages** — Full Disk Access required
10. ⏳ **Apple Notes** — via memo CLI
11. ⏳ **Gmail** — IMAP integration
12. ⏳ **Google Calendar** — API

### Ingestion rules
- **Never duplicate**: Check by title + source_origin before inserting
- **Auto-classify**: Detect type from file extension, URL pattern, content
- **Auto-link**: Same-day items get `relatedTo` links
- **Confidence**: Manual adds = 0.95, imports = 0.7-0.9, AI-classified = 0.6-0.8

---

## 9. Voice Interface (Planned)

### Flow
```
User speaks → [Whisper API / on-device] → Text
→ BrainContext.search(text) → Relevant nodes
→ LLM(messages + brain context) → Response text
→ [System TTS / ElevenLabs] → Audio
```

### Implementation options
1. **On-device**: Apple Speech framework (free, limited accuracy)
2. **API**: OpenAI Whisper API (accurate, costs ~$0.006/min)
3. **Hybrid**: On-device for short commands, API for longer speech

### Voice-specific features
- "What should I focus on today?" → AI reads top 3 items
- "Add a task: finish the design spec" → Creates task node
- "What did I do last Tuesday?" → Timeline query
- "Who is working on MindPalantir?" → People query

---

## 10. Performance Targets

| Metric | Target | Method |
|--------|--------|--------|
| App launch | <1s | SQLite + in-memory cache |
| Node insert | <5ms | Prepared statements |
| Search 10K nodes | <50ms | SQLite FTS5 |
| Today view render | <16ms (60fps) | SwiftUI + lazy loading |
| AI first token | <2s | OpenRouter streaming |
| Relevance recalc | <100ms | Batched, every 5 min |

---

## 11. What to NOT Build

- ❌ Infinite canvas / whiteboard (doesn't scale, confuses users)
- ❌ Folder hierarchy (links are the hierarchy)
- ❌ Markdown editor (use plain text for now)
- ❌ Collaboration (local-first, single user)
- ❌ Mobile app (macOS only for now)
- ❌ Custom themes (one clean dark theme)
- ❌ Tags (metadata serves this purpose)
- ❌ File attachments (link to files instead)
- ❌ Undo/redo (SQLite snapshots later)

---

## 12. Search (Apple HIG)

### Placement
- Search field at trailing edge of toolbar (macOS convention)
- `.searchable()` modifier with prompt "Search your brain..."
- Search as you type — immediate results

### Scope
- Default: search ALL node types
- Scope control: segmented picker for Projects/Notes/Tasks/People/Events/Sources
- Results sorted by relevance, then recency

### Implementation
```swift
.searchable(text: $searchText, prompt: "Search your brain...")
```
- Search across title + body + metadata
- SQLite FTS5 for fast full-text search at scale
- Results appear inline replacing current view

## 13. Key Design Decisions (and Why)

| Decision | Why |
|----------|-----|
| SQLite over Core Data | Full control, no abstraction leak, FTS5 |
| 6 node types (not more) | More types = more decision fatigue for users |
| Purple accent | Distinct from system blue (Finder), visible in dark mode |
| Sidebar over Tab bar | macOS convention for hierarchical navigation |
| Single-column Today view | Focuses attention, Things 3 pattern |
| Inspector (not modal) | macOS convention, non-blocking, always available |
| OpenRouter over local LLM | Free models > slow 0.8B local models on 8GB |
| No UNIQUE constraint on links | SQLite WAL mode silently rejects with constraints |
