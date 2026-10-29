import SwiftUI

/// App skins. Sunshine is free and the default; Retro Analog is a one-time $1 purchase.
enum Skin: String, CaseIterable, Identifiable, Sendable {
    case sunshine, retroAnalog

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sunshine: "Sunshine"
        case .retroAnalog: "Retro Analog"
        }
    }

    var isFree: Bool { self == .sunshine }

    /// App Store product ID. Must match App Store Connect and Skins.storekit.
    var productID: String? {
        switch self {
        case .sunshine: nil
        case .retroAnalog: "com.rokpremuz.ScreenshotSorter.skin.retro"
        }
    }

    static func forProductID(_ id: String) -> Skin? {
        allCases.first { $0.productID == id }
    }

    /// Both skins are designed on light surfaces.
    var colorScheme: ColorScheme? { .light }

    var theme: Theme {
        switch self {
        case .sunshine: .sunshine
        case .retroAnalog: .retroAnalog
        }
    }
}

/// Everything a skin changes. Screens read it from the environment.
struct Theme: Sendable {
    var background: Color
    /// Dot grid behind Home; nil hides it.
    var dotColor: Color?
    var ink: Color
    /// Faded second line of the big Home header.
    var fadedInk: Color
    var accent: Color
    var cardOutline: Color?
    var cardFill: @Sendable (ItemCategory) -> Color
    var cardInk: @Sendable (ItemCategory) -> Color

    // Type
    var fontDesign: Font.Design = .default
    /// A bundled font for display type; nil uses the system font.
    var fontName: String? = nil
    var weight: Font.Weight = .heavy
    /// Multiplies every display size.
    var typeScale: CGFloat = 1
    /// Letter spacing as a share of the font size: negative for tight grotesk, positive for LCD-style type.
    var trackingFactor: CGFloat = -0.03
    var uppercase = false
    /// Space between stacked display lines; LCD fonts need more room than the system font.
    var lineGap: CGFloat = -4
    /// Wide button colours; nil uses the accent with white text.
    var buttonFill: Color? = nil
    var buttonInk: Color? = nil

    func font(_ size: CGFloat) -> Font {
        if let fontName { return .custom(fontName, size: size * typeScale) }
        return .system(size: size * typeScale, weight: weight, design: fontDesign)
    }

    func tracking(_ size: CGFloat) -> CGFloat {
        size * typeScale * trackingFactor
    }

    /// Extra space between wrapped lines of display type; LCD fonts touch without it.
    var wrapSpacing: CGFloat { max(lineGap, 0) }

    func text(_ string: String) -> String {
        uppercase ? string.uppercased() : string
    }

    /// Three colours shown as a swatch in Settings.
    var swatch: [Color] {
        [cardFill(.jobs), cardFill(.posts), cardInk(.posts)]
    }
}

extension Theme {
    /// Yellow surface, flat saturated cards with black outlines, heavy grotesk type.
    static let sunshine = Theme(
        background: Color(hex: 0xFFD21F),
        dotColor: nil,
        ink: Color(hex: 0x0A0A0A),
        fadedInk: Color(hex: 0x0A0A0A).opacity(0.28),
        accent: Color(hex: 0x0A0A0A),
        cardOutline: Color(hex: 0x0A0A0A),
        cardFill: { $0 == .jobs ? Color(hex: 0xFFFFFF) : Palette.bright($0) },
        cardInk: { _ in Color(hex: 0x0A0A0A) }
    )

    /// Plain sage surface with black LCD panels and green monospaced type, like an old radio display.
    static let retroAnalog = Theme(
        background: Color(hex: 0x98AB86),
        dotColor: nil,
        ink: Color(hex: 0x141711),
        fadedInk: Color(hex: 0x141711).opacity(0.32),
        accent: Color(hex: 0x141711),
        cardOutline: nil,
        cardFill: { _ in Color(hex: 0x2C3624) },  // a deep shade of the sage background
        cardInk: { _ in Color(hex: 0xA9D38C) },
        fontDesign: .monospaced,
        // DSEG14 Classic: 14-segment LCD lettering, like a radio display.
        fontName: "DSEG14Classic-Regular",
        weight: .medium,
        typeScale: 0.85,
        trackingFactor: 0,
        uppercase: true,
        lineGap: 10,
        buttonFill: Color(hex: 0xFFFFFF),
        buttonInk: Color(hex: 0x0E100C)
    )
}

/// Category colours, picked from the reference designs.
enum Palette {
    static func bright(_ category: ItemCategory) -> Color {
        switch category {
        case .jobs: Color(hex: 0xFFD60A)
        case .posts: Color(hex: 0xFF8A1F)
        case .people: Color(hex: 0xC9B8FF)
        case .inspiration: Color(hex: 0xF25C3C)
        case .shopping: Color(hex: 0x1DB35E)
        case .receipts: Color(hex: 0xA3AE93)
        case .conversations: Color(hex: 0x7CC8FF)
        case .other: Color(hex: 0xF7F7F4)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension EnvironmentValues {
    @Entry var theme: Theme = .sunshine
}

extension Color {
    /// The wide Delete buttons, in every skin.
    static let deleteRed = Color(hex: 0xC03745)
}
