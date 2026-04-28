import SwiftUI

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum PitstopColor {
    static let background       = Color(hex: 0xF2F3F5)
    static let cardSurface      = Color.white
    static let textPrimary      = Color(hex: 0x111418)
    static let textSecondary    = Color(hex: 0x6B7280)
    static let accentBlue       = Color(hex: 0x1E90FF)
    static let ctaOlive         = Color(hex: 0x7A8A2E)
    static let ctaCharge        = Color(hex: 0x1E90FF)
    static let ctaOliveOverlay  = Color.black.opacity(0.35)
    static let badgeBg          = Color(hex: 0xE6F4FF)
    static let badgeText        = Color(hex: 0x0A84FF)
    static let fuelGradeBg      = Color(hex: 0xFFF4C2)
}

enum PitstopRadius {
    static let card: CGFloat = 32
    static let pill: CGFloat = 999
    static let chip: CGFloat = 8
}

enum PitstopSpacing {
    static let pageHorizontal: CGFloat = 20
    static let cardInner: CGFloat = 16
    static let stack: CGFloat = 12
}

enum ViewID {
    static let topBar = "home.topbar"
    static let settingsButton = "home.topbar.settings"
    static let heroCarousel = "home.hero.carousel"
    static func heroCard(_ id: UUID) -> String { "home.hero.card.\(id)" }
    static let refuelCTA = "home.hero.cta.refuel"
    static let chargeCTA = "home.hero.cta.charge"
    static let pageDots = "home.hero.dots"
    static let breakdownsSection = "home.breakdowns"
    static let statsLink = "home.breakdowns.stats"
    static func monthCard(_ month: String) -> String { "home.breakdowns.month.\(month)" }
    static func transactionRow(_ id: UUID) -> String { "home.breakdowns.tx.\(id)" }
    static let emptyState = "home.empty"
}
