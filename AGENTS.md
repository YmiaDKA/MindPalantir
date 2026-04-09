# AGENTS.md

Read `PRODUCT_CONTEXT.md` first. It is the source of truth for product direction.

## Build priority
1. Make the **Today/Desktop** screen genuinely useful
2. Make **Project view** a real project workspace, not just a list
3. Strengthen **relevance** and **confidence** before adding flashy features
4. Add **Hermes ingestion + organization** only where it supports the core loop

## Core loop
Capture -> organize -> surface -> refine

If a change does not improve that loop, deprioritize it.

## Hard rules
- One thing exists once. Views are queries, not copies.
- Do not turn the app into a giant infinite canvas.
- Do not make graph/map the main interaction.
- Do not add many new node types unless clearly necessary.
- Do not add complex integrations before the local workflow feels useful.
- Do not optimize for decorative UI over product clarity.

## Preferred direction
- Native SwiftUI feel
- Calm, app-like layout
- Cards, panels, inspector, drill-down
- Simple local-first architecture
- Honest uncertainty via clarification/confidence

## Avoid drift
Do not build:
- full social clone / personality imitation
- giant life-OS scope before Today works
- collaboration/sync/mobile before the desktop product is validated
- overcomplicated abstractions copied from AFFiNE/BlockSuite frontend

## When uncertain
Choose the option that makes MindPalantir feel more like a **context desktop** and less like a **whiteboard tool**.
