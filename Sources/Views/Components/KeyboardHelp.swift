import SwiftUI

/// Keyboard shortcuts help overlay — Cmd+/ to show.
/// Grouped by category: Global, Navigation, Actions.
struct KeyboardHelp: View {
    @Binding var isPresented: Bool

    private struct Shortcut: Identifiable {
        let id = UUID()
        let key: String
        let modifiers: String
        let description: String
    }

    private struct ShortcutGroup: Identifiable {
        let id = UUID()
        let title: String
        let shortcuts: [Shortcut]
    }

    private let groups: [ShortcutGroup] = [
        ShortcutGroup(title: "Global", shortcuts: [
            Shortcut(key: "K", modifiers: "⌘", description: "Quick Switch"),
            Shortcut(key: "N", modifiers: "⌘", description: "Quick Add"),
            Shortcut(key: "N", modifiers: "⌘⇧", description: "New note from template"),
            Shortcut(key: "I", modifiers: "⌘", description: "Toggle Inspector"),
            Shortcut(key: "D", modifiers: "⌘", description: "Duplicate selected"),
            Shortcut(key: "E", modifiers: "⌘", description: "Edit body"),
            Shortcut(key: "P", modifiers: "⌘", description: "Pin/unpin selected"),
            Shortcut(key: "T", modifiers: "⌘", description: "Quick Task"),
            Shortcut(key: "P", modifiers: "⌘⇧", description: "Command Palette"),
            Shortcut(key: ".", modifiers: "⌘", description: "Focus Mode"),
            Shortcut(key: "/", modifiers: "⌘", description: "This help"),
        ]),
            ShortcutGroup(title: "Navigation", shortcuts: [
                Shortcut(key: "1–9", modifiers: "⌘", description: "Switch screens"),
                Shortcut(key: "↑↓", modifiers: "", description: "Navigate items"),
                Shortcut(key: "J / K", modifiers: "", description: "Navigate (Vim)"),
                Shortcut(key: "←→", modifiers: "", description: "Navigate horizontal"),
                Shortcut(key: "H / L", modifiers: "", description: "Navigate horizontal (Vim)"),
                Shortcut(key: "Tab", modifiers: "", description: "Cycle sections"),
            ]),
        ShortcutGroup(title: "Actions", shortcuts: [
            Shortcut(key: "↵", modifiers: "", description: "Open focused item"),
            Shortcut(key: "Space", modifiers: "", description: "Toggle task done"),
            Shortcut(key: "Esc", modifiers: "", description: "Clear focus / go back"),
        ]),
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

            // Shortcuts list — grouped by category
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(group.title)
                                .font(Theme.Fonts.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.accent)
                                .padding(.horizontal, Theme.Spacing.lg)
                            
                            ForEach(group.shortcuts) { shortcut in
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
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .frame(width: 380)
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
