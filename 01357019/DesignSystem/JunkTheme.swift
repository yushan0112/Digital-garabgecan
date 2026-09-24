import SwiftUI
import UIKit

// MARK: - Color tokens

extension UIColor {
    /// Builds a UIColor from a 0xRRGGBB literal so the palette can live in one place.
    fileprivate convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// One token, two appearances. Every color in the app goes through here so light
    /// and dark mode can never drift apart.
    fileprivate static func yardToken(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // Surfaces
    static let yardCanvas = yardToken(light: 0xF7F6F3, dark: 0x121311)
    static let yardSurface = yardToken(light: 0xFFFFFF, dark: 0x1D1F1C)
    static let yardSurfaceAlt = yardToken(light: 0xEFEDE7, dark: 0x262925)

    // Text
    static let yardInk = yardToken(light: 0x1C1B19, dark: 0xF2F1ED)
    static let yardInkMuted = yardToken(light: 0x6E6A64, dark: 0x9C9890)

    // Accents
    static let yardRecycle = yardToken(light: 0x3E8E6E, dark: 0x5FBE96)
    static let yardTerracotta = yardToken(light: 0xD2734A, dark: 0xE8895C)
    static let yardAmber = yardToken(light: 0xE0A93C, dark: 0xF0C05A)
    static let yardDanger = yardToken(light: 0xC4553F, dark: 0xE2705A)

    /// Hairline borders replace shadows in dark mode, where shadows read as mud.
    static let yardHairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.08)
    })
}

// MARK: - Typography

extension Font {
    /// Gauge readouts and result hero numbers.
    static let yardDisplay = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Page and card titles.
    static let yardTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let yardHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let yardBody = Font.system(.body)
    static let yardCallout = Font.system(.callout)
    /// Field names in fact lists.
    static let yardLabel = Font.system(.caption, weight: .medium)
    /// Pile labels and level badges — always paired with `.yardTagCase()`.
    static let yardTag = Font.system(.caption2, weight: .semibold)
}

// MARK: - Layout scale

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32

    /// Every screen uses the same horizontal gutter.
    static let gutter: CGFloat = 20
}

enum Radius {
    static let chip: CGFloat = 10
    static let tile: CGFloat = 16
    static let card: CGFloat = 20
    static let hero: CGFloat = 28
}

// MARK: - Shared modifiers

extension View {
    /// The standard card: surface fill, hairline edge, and a shadow that only
    /// exists in light mode.
    func junkCard(padding: CGFloat = Space.l, radius: CGFloat = Radius.card) -> some View {
        modifier(JunkCardModifier(padding: padding, radius: radius))
    }

    /// Industrial stencil treatment for small labels.
    func yardTagCase() -> some View {
        font(.yardTag)
            .textCase(.uppercase)
            .kerning(1.2)
    }
}

private struct JunkCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let padding: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.yardSurface, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color.yardHairline, lineWidth: 1)
            }
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                radius: 12,
                y: 4
            )
    }
}

// MARK: - Formatting helpers

enum YardFormat {
    /// Byte counts always render with the same style so numbers stay comparable.
    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "未提供" }
        // ByteCountFormatter renders 0 as "Zero KB", which reads like a bug on screen.
        guard value > 0 else { return "0 MB" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    /// The UI is written in Traditional Chinese, so dates are formatted for zh-Hant
    /// rather than following the device locale and turning into "May 24, 2025".
    static let uiLocale = Locale(identifier: "zh_Hant_TW")

    static func date(_ value: Date?) -> String {
        guard let value else { return "未提供" }
        return value.formatted(Date.FormatStyle(date: .long).locale(uiLocale))
    }

    static func dateTime(_ value: Date) -> String {
        value.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(uiLocale))
    }

    static func relativeDays(_ value: Date?) -> String {
        guard let value else { return "未提供" }
        let days = Calendar.current.dateComponents([.day], from: value, to: .now).day ?? 0
        if days < 1 { return "今天" }
        if days < 30 { return "\(days) 天前" }
        if days < 365 { return "\(days / 30) 個月前" }
        return "\(days / 365) 年前"
    }
}
