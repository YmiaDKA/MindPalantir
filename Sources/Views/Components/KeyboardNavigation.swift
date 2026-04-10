import SwiftUI

// MARK: - Keyboard Navigation Engine
// Full keyboard navigation for MindPalantir — the power-user foundation.
//
// Design principles:
//   - Arrow keys move between items within a section
//   - Tab / Shift-Tab cycles between sections
//   - Vim-style J/K for down/up (and H/L for left/right in grids)
//   - Enter selects/activates, Escape goes back
//   - Auto-scroll to keep focused items visible
//   - Visual focus ring: accent-colored, subtle pulse
//
// Inspired by: Linear, Raycast, Notion, Obsidian — keyboard-first workflows.

// MARK: - Navigable Item Protocol

/// A lightweight representation of a focusable item in a view.
struct NavigableItem: Identifiable, Equatable {
    let id: String
    let section: String
    
    static func == (lhs: NavigableItem, rhs: NavigableItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Section-Aware Navigation

/// A navigable section — groups items for Tab cycling.
struct NavigableSection: Identifiable, Equatable {
    let id: String
    let items: [NavigableItem]
    
    static func == (lhs: NavigableSection, rhs: NavigableSection) -> Bool {
        lhs.id == rhs.id
    }
}

/// Navigation manager — tracks focus state across sections.
/// Use as @State in views that need keyboard navigation.
@Observable
@MainActor
final class NavigationState {
    var focusedItemID: String? = nil
    var focusedSectionID: String? = nil
    var scrollTargetID: String? = nil
    
    init() {}
    
    /// Move focus within the current section, or across all items if no sections.
    func moveFocus(direction: Int, in items: [NavigableItem]) {
        guard !items.isEmpty else { return }
        
        if let currentID = focusedItemID,
           let currentIndex = items.firstIndex(where: { $0.id == currentID }) {
            let newIndex = max(0, min(items.count - 1, currentIndex + direction))
            focusedItemID = items[newIndex].id
        } else {
            focusedItemID = direction > 0 ? items.first?.id : items.last?.id
        }
        
        scrollTargetID = focusedItemID
    }
    
    /// Move focus to the next/previous section.
    func cycleSection(direction: Int, sections: [NavigableSection]) {
        guard !sections.isEmpty else { return }
        
        let currentSectionIndex: Int
        if let sectionID = focusedSectionID,
           let idx = sections.firstIndex(where: { $0.id == sectionID }) {
            currentSectionIndex = idx
        } else {
            currentSectionIndex = direction > 0 ? 0 : sections.count - 1
        }
        
        let nextIndex = (currentSectionIndex + direction + sections.count) % sections.count
        let nextSection = sections[nextIndex]
        
        focusedSectionID = nextSection.id
        if direction > 0 {
            focusedItemID = nextSection.items.first?.id
        } else {
            focusedItemID = nextSection.items.last?.id
        }
        scrollTargetID = focusedItemID
    }
    
    /// Move focus left/right in a grid layout (wraps to next/previous row).
    func moveFocusHorizontal(direction: Int, in items: [NavigableItem], columns: Int) {
        guard !items.isEmpty, columns > 0 else { return }
        
        if let currentID = focusedItemID,
           let currentIndex = items.firstIndex(where: { $0.id == currentID }) {
            let newIndex = max(0, min(items.count - 1, currentIndex + direction))
            focusedItemID = items[newIndex].id
        } else {
            focusedItemID = direction > 0 ? items.first?.id : items.last?.id
        }
        scrollTargetID = focusedItemID
    }
    
    /// Clear all focus.
    func clearFocus() {
        focusedItemID = nil
        focusedSectionID = nil
        scrollTargetID = nil
    }
    
    /// Set focus to a specific item.
    func focus(_ itemID: String, section: String? = nil) {
        focusedItemID = itemID
        if let section { focusedSectionID = section }
        scrollTargetID = itemID
    }
    
    /// Check if a specific item is focused.
    func isFocused(_ itemID: String) -> Bool {
        focusedItemID == itemID
    }
}

// MARK: - Focus Ring Modifier

/// Adds a subtle focus ring to a card when it's the currently focused keyboard item.
/// Uses the accent color with low opacity — visible but not distracting.
/// Includes a gentle scale effect for spatial depth.
struct FocusRing: ViewModifier {
    let isFocused: Bool
    var style: FocusRingStyle = .default
    
    enum FocusRingStyle {
        case `default`
        case subtle  // for dense lists
        case strong  // for hero cards
    }
    
    private var lineWidth: CGFloat {
        switch style {
        case .default: 2
        case .subtle: 1.5
        case .strong: 2.5
        }
    }
    
    private var opacity: Double {
        switch style {
        case .default: 0.5
        case .subtle: 0.3
        case .strong: 0.6
        }
    }
    
    private var scale: CGFloat {
        switch style {
        case .default: 1.005
        case .subtle: 1.0
        case .strong: 1.01
        }
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        isFocused ? Theme.Colors.accent.opacity(opacity) : Color.clear,
                        lineWidth: lineWidth
                    )
            )
            .scaleEffect(isFocused ? scale : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

extension View {
    func focusRing(isFocused: Bool, style: FocusRing.FocusRingStyle = .default) -> some View {
        modifier(FocusRing(isFocused: isFocused, style: style))
    }
}

// MARK: - Keyboard Shortcut Labels (hints)

/// Small keyboard shortcut badge — shown near focused items to hint available actions.
struct KeyboardHint: View {
    let key: String
    let label: String
    
    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(Theme.Fonts.tiny)
                .foregroundStyle(.tertiary)
        }
    }
}

/// A row of keyboard hints — displayed in a section header when that section is focused.
struct KeyboardHintsBar: View {
    let hints: [(key: String, label: String)]
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(hints, id: \.key) { hint in
                KeyboardHint(key: hint.key, label: hint.label)
            }
        }
    }
}
