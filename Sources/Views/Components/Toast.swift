import SwiftUI

/// Toast notification — non-intrusive feedback for actions.
/// Shows briefly at bottom of screen, auto-dismisses.
struct Toast: View {
    let message: String
    let icon: String
    let style: Style

    enum Style {
        case success, info, warning, error

        var color: Color {
            switch self {
            case .success: .green
            case .info: Theme.Colors.accent
            case .warning: .orange
            case .error: .red
            }
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.color)
            Text(message)
                .font(Theme.Fonts.caption)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

/// Toast manager — shows and auto-dismisses toasts.
@MainActor
class ToastManager: ObservableObject {
    @Published var currentToast: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, icon: String = "checkmark.circle.fill", style: Toast.Style = .success, duration: TimeInterval = 2.0) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentToast = Toast(message: message, icon: icon, style: style)
        }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            withAnimation(.easeOut(duration: 0.2)) {
                currentToast = nil
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = nil
        }
    }
}

/// Environment key for toast manager
private struct ToastManagerKey: EnvironmentKey {
    static let defaultValue: ToastManager? = nil
}

extension EnvironmentValues {
    var toastManager: ToastManager? {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

/// View extension for showing toasts
extension View {
    func toast(manager: ToastManager) -> some View {
        overlay(alignment: .bottom) {
            if let toast = manager.currentToast {
                toast
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
