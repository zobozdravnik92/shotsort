import SwiftUI

/// App skins. Sunshine is free and the default; the others are one-time $1 purchases, and all come with Superboost.
enum Skin: String, CaseIterable, Identifiable, Sendable {
    case sunshine, retroAnalog, graphite

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sunshine: "Sunshine"
        case .retroAnalog: "Retro Analog"
        case .graphite: "Graphite"
        }
    }

    /// One line under the name in Settings.
    var tagline: String {
        switch self {
        case .sunshine: "Bright and bold"
        case .retroAnalog: "Radio-dial greens and LCD type"
        case .graphite: "Dark, quiet and precise"
        }
    }

    var isFree: Bool { self == .sunshine }

    /// App Store product ID. Must match App Store Connect and Skins.storekit.
    var productID: String? {
        switch self {
        case .sunshine: nil
        case .retroAnalog: "com.rokpremuz.ScreenshotSorter.skin.retro"
        case .graphite: "com.rokpremuz.ScreenshotSorter.skin.graphite"
        }
    }

    static func forProductID(_ id: String) -> Skin? {
        allCases.first { $0.productID == id }
    }

    /// Sunshine and Retro Analog are light; Graphite is dark, so sheets and system controls go dark with it.
    var colorScheme: ColorScheme? { self == .graphite ? .dark : .light }

    var theme: Theme {
        switch self {
        case .sunshine: .sunshine
        case .retroAnalog: .retroAnalog
        case .graphite: .graphite
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

    // Surfaces
    /// Card outline thickness: thick for the poster skins, a hairline for Graphite.
    var outlineWidth: CGFloat = 3
    /// Multiplies every card's corner radius.
    var cornerScale: CGFloat = 1
    /// A tight shadow under cards and buttons, so they sit just above the page.
    var cardShadow = false
    /// When set, small tags are tinted (coloured text on a faint fill) instead of solid ink.
    var newTagTint: Color? = nil
    var actionTagTint: Color? = nil
    /// Settings swatch colours; nil uses the card colours.
    var swatchColors: [Color]? = nil

    func font(_ size: CGFloat) -> Font {
        if let fontName { return .custom(fontName, size: size * typeScale) }
        return .system(size: size * typeScale, weight: weight, design: fontDesign)
    }

    func tracking(_ size: CGFloat) -> CGFloat {
        size * typeScale * trackingFactor
    }

    func radius(_ base: CGFloat) -> CGFloat { base * cornerScale }

    /// Extra space between wrapped lines of display type; LCD fonts touch without it.
    var wrapSpacing: CGFloat { max(lineGap, 0) }

    func text(_ string: String) -> String {
        uppercase ? string.uppercased() : string
    }

    /// Three colours shown as a swatch in Settings.
    var swatch: [Color] {
        swatchColors ?? [cardFill(.jobs), cardFill(.posts), cardInk(.posts)]
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

extension Theme {
    /// Charcoal surfaces with hairline borders, small rounded corners, soft shadows and tinted tags,
    /// like a modern dark dashboard. Monochrome cards; colour only in tags and buttons.
    static let graphite = Theme(
        background: Color(hex: 0x131313),
        dotColor: nil,
        ink: Color(hex: 0xEDEDED),
        fadedInk: Color(hex: 0xEDEDED).opacity(0.36),
        // Light grey, like the reference's icons and links; colour is kept for tags.
        accent: Color(hex: 0xD6D6D6),
        cardOutline: Color(hex: 0x2B2B2B),
        cardFill: { _ in Color(hex: 0x1C1C1C) },
        cardInk: { _ in Color(hex: 0xEDEDED) },
        weight: .semibold,
        typeScale: 0.92,
        trackingFactor: -0.02,
        lineGap: -2,
        buttonFill: Color(hex: 0xF4F4F4),
        buttonInk: Color(hex: 0x111111),
        outlineWidth: 1,
        cornerScale: 0.5,
        cardShadow: true,
        newTagTint: Color(hex: 0xA593F8),
        actionTagTint: Color(hex: 0x3DD68C),
        swatchColors: [Color(hex: 0x2B2B2B), Color(hex: 0xA593F8), Color(hex: 0x3DD68C)]
    )
}

extension View {
    /// The skin's card shadow, if it has one: tight and dark, just enough to lift a card off the page.
    func themedShadow(_ theme: Theme) -> some View {
        shadow(color: .black.opacity(theme.cardShadow ? 0.45 : 0), radius: theme.cardShadow ? 1.5 : 0, y: theme.cardShadow ? 1 : 0)
    }
}

/// A small tag: solid ink on poster skins, or a tinted pill on skins that set a tint.
struct ThemedTag: View {
    let text: String
    let tint: Color?
    /// Used when there's no tint: ink fill with the card colour as text, or an outline.
    let ink: Color
    let fill: Color
    var outlined = false
    var systemImage: String? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(theme.text(text))
                .font(.system(size: 12, weight: .bold, design: theme.fontDesign))
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tint ?? (outlined ? ink : fill))
        .background {
            if let tint {
                Capsule().fill(tint.opacity(0.14))
                Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 1)
            } else if outlined {
                Capsule().strokeBorder(ink, lineWidth: 1.5)
            } else {
                Capsule().fill(ink)
            }
        }
        .fixedSize()
    }
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
