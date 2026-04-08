import SwiftUI

/// Quick add / chat-like input. The main capture mechanism.
struct QuickAddBar: View {
    @Environment(NodeStore.self) private var store
    @State private var text = ""
    @State private var showTypePicker = false
    @State private var selectedType: NodeType = .note

    var body: some View {
        HStack(spacing: 8) {
            // Type selector
            Menu {
                ForEach(NodeType.allCases, id: \.self) { type in
                    Button { selectedType = type } label: {
                        Label(type.rawValue.capitalized, systemImage: type.icon)
                    }
                }
            } label: {
                Text(selectedType.icon)
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)

            // Text field
            TextField("Quick add...", text: $text)
                .textFieldStyle(.plain)
                .onSubmit { addNode() }

            if !text.isEmpty {
                Button("Add", systemImage: "return") { addNode() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func addNode() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let node = MindNode(
            type: selectedType,
            title: text.trimmingCharacters(in: .whitespaces),
            sourceOrigin: "quick_add"
        )
        try? store.insertNode(node)
        text = ""
    }
}
