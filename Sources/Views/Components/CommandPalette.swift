import SwiftUI

/// Command palette — Cmd+Shift+P for actions without leaving current view.
/// Inspired by VS Code, Raycast, Linear command palette.
struct CommandPalette: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private struct Command: Identifiable {
        let id = UUID()
        let icon: String
        let name: String
        let shortcut: String?
        let category: String
        let action: () -> Void
    }

    private struct CommandGroup {
        let category: String
        let commands: [Command]
    }

    private var groupedCommands: [CommandGroup] {
        let cmds = commands
        let categories = Dictionary(grouping: cmds) { $0.category }
        return ["Create", "Actions", "System"]
            .compactMap { name in
                guard let items = categories[name], !items.isEmpty else { return nil }
                return CommandGroup(category: name, commands: items)
            }
    }

    private var commands: [Command] {
        let all = [
            // Node creation
            Command(icon: "folder.badge.plus", name: "New Project", shortcut: nil, category: "Create") {
                let node = MindNode(type: .project, title: "New Project", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
            },
            Command(icon: "checkmark.circle.badge.plus", name: "New Task", shortcut: nil, category: "Create") {
                let node = MindNode(type: .task, title: "New Task", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
            },
            Command(icon: "note.text.badge.plus", name: "New Note", shortcut: nil, category: "Create") {
                let node = MindNode(type: .note, title: "New Note", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
            },
            Command(icon: "person.badge.plus", name: "New Person", shortcut: nil, category: "Create") {
                let node = MindNode(type: .person, title: "New Person", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
            },
            Command(icon: "calendar.badge.plus", name: "New Event", shortcut: nil, category: "Create") {
                let node = MindNode(type: .event, title: "New Event", sourceOrigin: "command_palette")
                try? store.insertNode(node)
                selectedNode = node
            },
            // Actions
            Command(icon: "pin", name: "Toggle Pin on Selected", shortcut: nil, category: "Actions") {
                guard var node = selectedNode else { return }
                node.pinned.toggle()
                node.updatedAt = .now
                try? store.insertNode(node)
                selectedNode = node
            },
            Command(icon: "checkmark.circle", name: "Complete Selected Task", shortcut: nil, category: "Actions") {
                guard var node = selectedNode, node.type == .task else { return }
                node.status = node.status == .completed ? .active : .completed
                node.updatedAt = .now
                try? store.insertNode(node)
                selectedNode = node
            },
            Command(icon: "trash", name: "Delete Selected", shortcut: "⌘⌫", category: "Actions") {
                guard let node = selectedNode else { return }
                try? store.deleteNode(id: node.id)
                selectedNode = nil
            },
            // System
            Command(icon: "arrow.clockwise", name: "Rebuild Search Index", shortcut: nil, category: "System") {
                store.rebuildSearchIndex()
            },
            Command(icon: "arrow.clockwise", name: "Decay Relevance Scores", shortcut: nil, category: "System") {
                store.decayRelevance()
            },
            Command(icon: "square.and.arrow.up", name: "Export All Nodes as JSON", shortcut: nil, category: "System") {
                exportNodes()
            },
        ]

        guard !query.isEmpty else { return all }

        let lower = query.lowercased()
        return all.filter {
            $0.name.lowercased().contains(lower) ||
            $0.category.lowercased().contains(lower)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "command")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                TextField("Type a command...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = commands.first {
                            first.action()
                            isPresented = false
                        }
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            // Commands list
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(Array(groupedCommands.enumerated()), id: \.offset) { _, group in
                        Text(group.category.uppercased())
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.sm)
                            .padding(.bottom, 2)

                        ForEach(group.commands) { cmd in
                            Button {
                                cmd.action()
                                isPresented = false
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Image(systemName: cmd.icon)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.Colors.accent)
                                        .frame(width: 18)
                                    Text(cmd.name)
                                        .font(Theme.Fonts.body)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if let shortcut = cmd.shortcut {
                                        Text(shortcut)
                                            .font(Theme.Fonts.tiny)
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 440)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear { isSearchFocused = true }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private func exportNodes() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Array(store.nodes.values)) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "mindpalantir-export.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }
}
