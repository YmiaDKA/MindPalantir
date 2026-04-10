import SwiftUI

// MARK: - Keyboard Navigation Support
// Adds arrow-key navigation to card-based views (Today, ProjectDetail).
// Tracks focused items and provides visual focus indicators.
//
// Design: Inspired by Linear, Obsidian, Notion — keyboard-first workflows.
// Arrow keys move focus, Enter opens, Escape clears focus.

// MARK: - Navigable Item Protocol

/// A lightweight representation of a focusable item in a view.
struct NavigableItem: Identifiable, Equatable {
    let id: String
    let section: String
    
    static func == (lhs: NavigableItem, rhs: NavigableItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Focus Ring Modifier

/// Adds a subtle focus ring to a card when it's the currently focused keyboard item.
/// Uses the accent color with low opacity — visible but not distracting.
struct FocusRing: ViewModifier {
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        isFocused ? Theme.Colors.accent.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isFocused ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

extension View {
    func focusRing(isFocused: Bool) -> some View {
        modifier(FocusRing(isFocused: isFocused))
    }
}
