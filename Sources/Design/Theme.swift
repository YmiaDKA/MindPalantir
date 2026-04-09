import SwiftUI

/// Design system — Apple HIG + spatial canvas feel.
/// Inspired by Muse, Heptabase, Freeform: cards with depth, organic spacing.
enum Theme {
    
    // MARK: - Typography
    
    enum Fonts {
        /// Hero titles — big, bold, spatial
        static let largeTitle = SwiftUI.Font.system(size: 28, weight: .bold, design: .default)
        
        /// Section headers
        static let sectionTitle = SwiftUI.Font.system(size: 17, weight: .semibold, design: .default)
        
        /// Card titles
        static let headline = SwiftUI.Font.headline
        
        /// Content
        static let body = SwiftUI.Font.body
        
        /// Metadata
        static let caption = SwiftUI.Font.caption
        
        /// Tiny labels
        static let tiny = SwiftUI.Font.system(size: 10, weight: .medium, design: .rounded)
    }
    
    // MARK: - Spacing (spatial apps use generous spacing)
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let canvas: CGFloat = 40  // between major card groups
    }
    
    // MARK: - Corner Radius (Muse-like: 12px cards)
    
    enum Radius {
        static let card: CGFloat = 12       // main cards (research: 8-12px)
        static let cardLarge: CGFloat = 16  // hero/focus cards
        static let chip: CGFloat = 8        // small chips
        static let button: CGFloat = 8
    }
    
    // MARK: - Shadows (depth = spatial feel)
    
    enum Shadow {
        /// Subtle card shadow — lifts card off canvas
        static let card = ShadowStyle(
            color: .black.opacity(0.06),
            radius: 8,
            y: 2
        )
        
        /// Hovering card — more depth when focused/dragged
        static let elevated = ShadowStyle(
            color: .black.opacity(0.10),
            radius: 16,
            y: 4
        )
        
        /// Hero card — the main focus
        static let hero = ShadowStyle(
            color: .black.opacity(0.08),
            radius: 12,
            y: 3
        )
        
        struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let y: CGFloat
        }
    }
    
    // MARK: - Colors
    
    enum Colors {
        static let accent = SwiftUI.Color.purple
        
        static func typeColor(_ type: NodeType) -> SwiftUI.Color {
            switch type {
            case .project: .blue
            case .task: .green
            case .note: .cyan
            case .person: .purple
            case .event: .red
            case .source: .orange
            }
        }
        
        static func relevance(_ value: Double) -> SwiftUI.Color {
            switch value {
            case 0.7...: .green
            case 0.4..<0.7: .orange
            default: .secondary
            }
        }
        
        static func confidence(_ value: Double) -> SwiftUI.Color {
            switch value {
            case 0.8...: .green
            case 0.5..<0.8: .orange
            default: .red
            }
        }
        
        /// Card background — slightly warm, not pure white
        static let cardBackground = SwiftUI.Color(NSColor.controlBackgroundColor)
        
        /// Canvas background — the "desk" surface
        static let windowBackground = SwiftUI.Color(NSColor.windowBackgroundColor)
        
        /// Card border — very subtle
        static let cardBorder = SwiftUI.Color.primary.opacity(0.06)
    }
    
    // MARK: - Layout
    
    enum Layout {
        static let sidebarWidth: CGFloat = 200
        static let inspectorWidth: CGFloat = 300
        static let sidePanelWidth: CGFloat = 280
        static let focusCardMaxWidth: CGFloat = 640
    }
}

// MARK: - Card View Modifier (spatial style)

struct SpatialCard: ViewModifier {
    var shadow: Theme.Shadow.ShadowStyle = Theme.Shadow.card
    var radius: CGFloat = Theme.Radius.card
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Theme.Colors.cardBackground)
            )
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.Colors.cardBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func spatialCard(
        shadow: Theme.Shadow.ShadowStyle = Theme.Shadow.card,
        radius: CGFloat = Theme.Radius.card
    ) -> some View {
        modifier(SpatialCard(shadow: shadow, radius: radius))
    }
}
