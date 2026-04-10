import SwiftUI

/// Keyboard shortcuts help overlay — Cmd+/ to show.
struct KeyboardHelp: View {
    @Binding var isPresented: Bool

    private struct Shortcut: Identifiable {
        let id = UUID()
        let key: String
        let modifiers: String
        let description: String
    }

    private let shortcuts: [Shortcut] = [
        Shortcut(key: "K", modifiers: "⌘", description: "Quick Switch — search anything"),
        Shortcut(key: "N", modifiers: "⌘", description: "Quick Add — capture a thought"),
        Shortcut(key: "I", modifiers: "⌘", description: "Toggle Inspector"),
        Shortcut(key: "D", modifiers: "⌘", description: "Duplicate selected node"),
        Shortcut(key: "1", modifiers: "⌘", description: "Today view"),
        Shortcut(key: "2", modifiers: "⌘", description: "Chat"),
        Shortcut(key: "3", modifiers: "⌘", description: "Projects"),
        Shortcut(key: "4", modifiers: "⌘", description: "Graph"),
        Shortcut(key: "5", modifiers: "⌘", description: "Notes"),
        Shortcut(key: "6", modifiers: "⌘", description: "Tasks"),
        Shortcut(key: "7", modifiers: "⌘", description: "Timeline"),
        Shortcut(key: "8", modifiers: "⌘", description: "People"),
        Shortcut(key: "9", modifiers: "⌘", description: "Sources"),
        Shortcut(key: "F", modifiers: "⌘", description: "Search"),
        Shortcut(key: ".", modifiers: "⌘", description: "Focus Mode — hide sidebar & inspector"),
        Shortcut(key: "/", modifiers: "⌘", description: "Keyboard shortcuts"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(Theme.Fonts.sectionTitle)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.lg)

            Divider()

            // Shortcuts list
            ScrollView {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(shortcuts) { shortcut in
                        HStack {
                            Text(shortcut.description)
                                .font(Theme.Fonts.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            HStack(spacing: 2) {
                                if !shortcut.modifiers.isEmpty {
                                    Text(shortcut.modifiers)
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(shortcut.key)
                                    .font(Theme.Fonts.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .frame(width: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }
}
