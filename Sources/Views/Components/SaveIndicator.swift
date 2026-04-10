import SwiftUI

/// Subtle animated badge that confirms changes are persisted.
/// Appears briefly at the bottom of the screen, then fades out.
/// Inspired by VS Code's save indicator — quiet confidence that your work is safe.
struct SaveIndicator: View {
    let phase: Phase
    
    enum Phase: Equatable {
        case idle
        case saving
        case saved
    }
    
    var body: some View {
        Group {
            if phase != .idle {
                HStack(spacing: 5) {
                    if phase == .saving {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Saving…")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.green)
                        Text("Saved")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs + 1)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: phase)
    }
}

/// Manages the save indicator lifecycle — watches for changes, shows saving → saved → fade.
@MainActor
@Observable
final class SaveIndicatorState {
    var phase: SaveIndicator.Phase = .idle
    private var saveTask: Task<Void, Never>?
    private var lastObservedCount: Int = 0
    
    /// Call when the store's changeCount updates.
    /// Debounces rapid changes and manages the saving → saved → idle lifecycle.
    func handleChange(newCount: Int) {
        guard newCount != lastObservedCount else { return }
        lastObservedCount = newCount
        
        saveTask?.cancel()
        phase = .saving
        
        saveTask = Task { @MainActor in
            // Wait for changes to settle (debounce)
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 0.15)) {
                phase = .saved
            }
            
            // Hold "Saved" briefly, then fade out
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .idle
            }
        }
    }
}
