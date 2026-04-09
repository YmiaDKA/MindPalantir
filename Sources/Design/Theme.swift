import SwiftUI

/// Design system — Apple HIG compliant.
/// Typography creates hierarchy. Color is accent only. Spacing creates structure.
/// See DESIGN_SPEC.md for full rationale.
enum Theme {
    
    // MARK: - Typography (macOS built-in text styles)
    // Source: Apple HIG Typography — use SF Pro, system weights, no custom fonts
    
    enum Fonts {
        /// Large Title (26pt, Regular) — hero items, focused project name
        static let largeTitle = SwiftUI.Font.system(size: 26, weight: .bold, design: .default)
        
        /// Title 2 (17pt, Regular) — section headers within content
        static let sectionTitle = SwiftUI.Font.system(size: 17, weight: .semibold, design: .default)
        
        /// Headline (13pt, Bold) — card titles, list row titles
        static let headline = SwiftUI.Font.headline
        
        /// Body (13pt, Regular) — descriptions, content
        static let body = SwiftUI.Font.body
        
        /// Caption 1 (10pt, Regular) — metadata, timestamps, badges
        static let caption = SwiftUI.Font.caption
        
        /// Tiny (10pt, Medium) — uppercase section labels, tracking
        static let tiny = SwiftUI.Font.system(size: 10, weight: .medium, design: .rounded)
    }
    
    // MARK: - Spacing (8pt grid)
    // Source: Apple HIG Layout — consistent spacing creates visual structure
    
    enum Spacing {
        static let xs: CGFloat = 4    // between tight elements
        static let sm: CGFloat = 8    // between related items
        static let md: CGFloat = 12   // between cards
        static let lg: CGFloat = 16   // card padding
        static let xl: CGFloat = 24   // between sections
        static let xxl: CGFloat = 32  // major section breaks
    }
    
    // MARK: - Corner Radius
    // Source: Apple HIG — consistent radii feel native
    
    enum Radius {
        static let card: CGFloat = 10    // main cards
        static let chip: CGFloat = 6     // small chips, pills
        static let button: CGFloat = 8   // buttons
    }
    
    // MARK: - Colors (system dynamic colors + one accent)
    // Source: Apple HIG Color — use system colors for auto light/dark adaptation
    
    enum Colors {
        /// ONE accent for entire app — used for selections, primary actions, links
        static let accent = SwiftUI.Color.purple
        
        /// Type indicator colors — subtle, only for meaning
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
        
        /// Relevance indicator — green/orange/gray
        static func relevance(_ value: Double) -> SwiftUI.Color {
            switch value {
            case 0.7...: .green
            case 0.4..<0.7: .orange
            default: .secondary
            }
        }
        
        /// Confidence indicator
        static func confidence(_ value: Double) -> SwiftUI.Color {
            switch value {
            case 0.8...: .green
            case 0.5..<0.8: .orange
            default: .red
            }
        }
        
        /// System backgrounds (auto-adapt to light/dark)
        static let cardBackground = SwiftUI.Color(NSColor.controlBackgroundColor)
        static let windowBackground = SwiftUI.Color(NSColor.windowBackgroundColor)
    }
    
    // MARK: - Layout Constants
    
    enum Layout {
        static let sidebarWidth: CGFloat = 200
        static let inspectorWidth: CGFloat = 300
        static let focusCardMaxWidth: CGFloat = 600
        static let quickAddMaxWidth: CGFloat = 400
        static let recentChipWidth: CGFloat = 120
        static let recentChipHeight: CGFloat = 60
    }
}
