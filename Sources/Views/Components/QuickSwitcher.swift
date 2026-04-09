import SwiftUI

/// Spotlight-like quick switcher — Cmd+K to search and navigate to any node.
/// Inspired by Raycast, Alfred, Obsidian Quick Switcher.
struct QuickSwitcher: View {
    @Environment(NodeStore.self) private var store
    @Binding var selectedNode: MindNode?
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var results: [MindNode] {
        guard !query.isEmpty else {
            // Show recent + pinned when empty
            let pinned = store.nodes.values.filter { $0.pinned }.sorted { $0.updatedAt > $1.updatedAt }
            let recent = store.recentNodes(days: 7, limit: 5)
            return Array((pinned + recent).uniqued().prefix(8))
        }
        return store.search(query, limit: 10)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                TextField("Search your brain...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = results.first {
                            select(first)
                        }
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                Text("ESC")
                    .font(Theme.Fonts.tiny)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            // Results
            if results.isEmpty && !query.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(query)\"")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, node in
                            switcherRow(node, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private func switcherRow(_ node: MindNode, index: Int) -> some View {
        Button {
            select(node)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: node.type.sfIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.typeColor(node.type))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(node.title)
                        .font(Theme.Fonts.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text(node.type.rawValue.capitalized)
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(Theme.Colors.typeColor(node.type))

                        if node.pinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                        }

                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text(node.updatedAt, style: .relative)
                            .font(Theme.Fonts.tiny)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Circle()
                    .fill(Theme.Colors.relevance(node.relevance))
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(index < 9 ? Color.accentColor.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
    }

    private func select(_ node: MindNode) {
        selectedNode = node
        isPresented = false
    }
}

// MARK: - Array Dedup Extension

private extension Array where Element: Identifiable {
    func uniqued() -> [Element] {
        var seen: Set<Element.ID> = []
        return filter { seen.insert($0.id).inserted }
    }
}
