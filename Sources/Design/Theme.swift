import SwiftUI

/// Design system — consistent typography, spacing, colors.
/// Inspired by Things 3, Linear, Apple HIG.
enum Theme {
    
    // MARK: - Typography
    
    enum Font {
        /// Large title for focused items (project names, primary content)
        static func largeTitle() -> SwiftUI.Font { .system(size: 28, weight: .bold, design: .default) }
        
        /// Section headers
        static func sectionHeader() -> SwiftUI.Font { .system(size: 13, weight: .semibold, design: .rounded) }
        
        /// Card title
        static func cardTitle() -> SwiftUI.Font { .system(size: 15, weight: .semibold) }
        
        /// Body text
        static func body() -> SwiftUI.Font { .system(size: 13, weight: .regular) }
        
        /// Caption / metadata
        static func caption() -> SwiftUI.Font { .system(size: 11, weight: .medium) }
        
        /// Tiny labels
        static func tiny() -> SwiftUI.Font { .system(size: 10, weight: .medium) }
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }
    
    // MARK: - Colors (single accent system)
    
    enum Colors {
        /// One accent color for the entire app
        static let accent = SwiftUI.Color.purple
        
        /// Type indicator colors — subtle, not dominant
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
        
        /// Relevance bar color
        static func relevance(_ value: Double) -> SwiftUI.Color {
            switch value {
            case 0.7...: .green
            case 0.4..<0.7: .orange
            default: .secondary
            }
        }
    }
    
    // MARK: - Corners
    
    enum Radius {
        static let card: CGFloat = 10
        static let chip: CGFloat = 6
        static let button: CGFloat = 8
    }
}
