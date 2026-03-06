import Cocoa

// MARK: - Refined Chart Theme System
// Design: Desaturated scholarly palette, off-black text, tinted shadows
// Typography: SF Pro (system) with precise weight hierarchy
// Spacing: 4px rhythm (4, 8, 12, 16, 20, 24, 32, 40, 48)
enum ChartTheme: String, CaseIterable {
    case academic = "academic"
    case nature = "nature"
    case warm = "warm"
    case mono = "mono"
    case auto = "auto"

    var displayName: String {
        switch self {
        case .academic: return "Academic"
        case .nature: return "Botanical"
        case .warm: return "Amber"
        case .mono: return "Graphite"
        case .auto: return "System"
        }
    }

    var colors: ChartColorPalette {
        switch self {
        case .academic:
            return ChartColorPalette(
                // Deep slate blue — desaturated, not neon
                primary: NSColor(hex: "#3B6B9A"),
                secondary: NSColor(hex: "#6B9DC2"),
                accent: NSColor(hex: "#C47D2E"),
                success: NSColor(hex: "#3D8B5E"),
                warning: NSColor(hex: "#C47D2E"),
                error: NSColor(hex: "#B84A3C"),
                // Off-white background, never pure white
                background: NSColor(hex: "#F5F5F3"),
                surface: NSColor(hex: "#FAFAF8"),
                onPrimary: NSColor(hex: "#FAFAF8"),
                onSurface: NSColor(hex: "#1A1A1A"),
                // Warm gray grid, not cold
                gridLines: NSColor(hex: "#E5E3DF"),
                // Off-black text, never pure black
                textPrimary: NSColor(hex: "#1C1C1E"),
                textSecondary: NSColor(hex: "#6E6E73"),
                // Tinted border for depth
                border: NSColor(hex: "#D8D6D0"),
                // Card background slightly elevated from surface
                cardBackground: NSColor(hex: "#FFFFFF"),
                // Subtle tinted shadow color
                shadowColor: NSColor(hex: "#3B6B9A")
            )
        case .nature:
            return ChartColorPalette(
                primary: NSColor(hex: "#3D7A5E"),
                secondary: NSColor(hex: "#6BA88A"),
                accent: NSColor(hex: "#B8963E"),
                success: NSColor(hex: "#3D8B5E"),
                warning: NSColor(hex: "#C47D2E"),
                error: NSColor(hex: "#B84A3C"),
                background: NSColor(hex: "#F4F6F3"),
                surface: NSColor(hex: "#F9FAF8"),
                onPrimary: NSColor(hex: "#FAFAF8"),
                onSurface: NSColor(hex: "#1A1A1A"),
                gridLines: NSColor(hex: "#DFE5DD"),
                textPrimary: NSColor(hex: "#1C1C1E"),
                textSecondary: NSColor(hex: "#5D6E5D"),
                border: NSColor(hex: "#D0D8CE"),
                cardBackground: NSColor(hex: "#FFFFFF"),
                shadowColor: NSColor(hex: "#3D7A5E")
            )
        case .warm:
            return ChartColorPalette(
                primary: NSColor(hex: "#B86830"),
                secondary: NSColor(hex: "#D4956A"),
                accent: NSColor(hex: "#6B4D8A"),
                success: NSColor(hex: "#3D8B5E"),
                warning: NSColor(hex: "#C47D2E"),
                error: NSColor(hex: "#9E3A2E"),
                background: NSColor(hex: "#F7F4F0"),
                surface: NSColor(hex: "#FAFAF8"),
                onPrimary: NSColor(hex: "#FAFAF8"),
                onSurface: NSColor(hex: "#1A1A1A"),
                gridLines: NSColor(hex: "#E8E2DA"),
                textPrimary: NSColor(hex: "#2C1810"),
                textSecondary: NSColor(hex: "#7A6458"),
                border: NSColor(hex: "#DDD6CC"),
                cardBackground: NSColor(hex: "#FFFFFF"),
                shadowColor: NSColor(hex: "#B86830")
            )
        case .mono:
            return ChartColorPalette(
                primary: NSColor(hex: "#3A3A3C"),
                secondary: NSColor(hex: "#8E8E93"),
                accent: NSColor(hex: "#3B6B9A"),
                success: NSColor(hex: "#3D8B5E"),
                warning: NSColor(hex: "#C47D2E"),
                error: NSColor(hex: "#B84A3C"),
                background: NSColor(hex: "#F5F5F5"),
                surface: NSColor(hex: "#FAFAFA"),
                onPrimary: NSColor(hex: "#FAFAFA"),
                onSurface: NSColor(hex: "#1C1C1E"),
                gridLines: NSColor(hex: "#E5E5E5"),
                textPrimary: NSColor(hex: "#1C1C1E"),
                textSecondary: NSColor(hex: "#6E6E73"),
                border: NSColor(hex: "#D1D1D6"),
                cardBackground: NSColor(hex: "#FFFFFF"),
                shadowColor: NSColor(hex: "#3A3A3C")
            )
        case .auto:
            if NSApp.effectiveAppearance.name == .darkAqua {
                return darkTheme
            } else {
                return lightTheme
            }
        }
    }

    private var lightTheme: ChartColorPalette {
        return ChartColorPalette(
            primary: NSColor(hex: "#3B6B9A"),
            secondary: NSColor(hex: "#6B9DC2"),
            accent: NSColor(hex: "#C47D2E"),
            success: NSColor(hex: "#3D8B5E"),
            warning: NSColor(hex: "#C47D2E"),
            error: NSColor(hex: "#B84A3C"),
            background: NSColor(hex: "#F5F5F3"),
            surface: NSColor(hex: "#FAFAF8"),
            onPrimary: NSColor(hex: "#FAFAF8"),
            onSurface: NSColor(hex: "#1C1C1E"),
            gridLines: NSColor(hex: "#E5E3DF"),
            textPrimary: NSColor(hex: "#1C1C1E"),
            textSecondary: NSColor(hex: "#6E6E73"),
            border: NSColor(hex: "#D8D6D0"),
            cardBackground: NSColor(hex: "#FFFFFF"),
            shadowColor: NSColor(hex: "#3B6B9A")
        )
    }

    private var darkTheme: ChartColorPalette {
        return ChartColorPalette(
            primary: NSColor(hex: "#6B9DC2"),
            secondary: NSColor(hex: "#3B6B9A"),
            accent: NSColor(hex: "#D4956A"),
            success: NSColor(hex: "#5AAF7A"),
            warning: NSColor(hex: "#D4956A"),
            error: NSColor(hex: "#D46B5E"),
            background: NSColor(hex: "#1C1C1E"),
            surface: NSColor(hex: "#2C2C2E"),
            onPrimary: NSColor(hex: "#1C1C1E"),
            onSurface: NSColor(hex: "#F5F5F3"),
            gridLines: NSColor(hex: "#3A3A3C"),
            textPrimary: NSColor(hex: "#F5F5F3"),
            textSecondary: NSColor(hex: "#8E8E93"),
            border: NSColor(hex: "#3A3A3C"),
            cardBackground: NSColor(hex: "#2C2C2E"),
            shadowColor: NSColor(hex: "#000000")
        )
    }
}

// MARK: - Color Palette Structure
struct ChartColorPalette {
    let primary: NSColor
    let secondary: NSColor
    let accent: NSColor
    let success: NSColor
    let warning: NSColor
    let error: NSColor
    let background: NSColor
    let surface: NSColor
    let onPrimary: NSColor
    let onSurface: NSColor
    let gridLines: NSColor
    let textPrimary: NSColor
    let textSecondary: NSColor
    let border: NSColor
    let cardBackground: NSColor
    let shadowColor: NSColor

    // Chart-specific gradients
    var primaryGradient: [NSColor] {
        return [primary, primary.withAlphaComponent(0.6)]
    }

    var chartDataColors: [NSColor] {
        return [primary, secondary, accent, success, warning]
    }
}

// MARK: - NSColor Hex Extension
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - Chart Style Configuration
struct ChartStyleConfig {
    let theme: ChartTheme
    let animationDuration: TimeInterval
    let cornerRadius: CGFloat
    let shadowOpacity: Float
    let fontSizes: FontSizes

    static let `default` = ChartStyleConfig(
        theme: .academic,
        animationDuration: 0.25,
        cornerRadius: 10.0,
        shadowOpacity: 0.06,
        fontSizes: FontSizes()
    )
}

// MARK: - Typography Scale (4px rhythm)
// Display: 28pt semibold — section headers
// Title:   18pt semibold — card titles
// Body:    13pt regular — primary content
// Caption: 11pt regular — secondary labels
// Mono:    11pt monospaced — numeric data
struct FontSizes {
    let display: CGFloat = 28
    let title: CGFloat = 18
    let subtitle: CGFloat = 14
    let body: CGFloat = 13
    let caption: CGFloat = 11
    let chartLabel: CGFloat = 10
}

// MARK: - Spacing Constants (4px rhythm)
struct DesignSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    static let section: CGFloat = 48

    // Card-specific
    static let cardPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 10
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowOpacity: Float = 0.06

    // Toolbar
    static let toolbarHeight: CGFloat = 52
    static let toolbarPadding: CGFloat = 16
}
