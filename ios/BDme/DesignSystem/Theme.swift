import SwiftUI

/// Portage des tokens de design de client/src/styles/global.css.
enum BDTheme {
    // MARK: Couleurs
    static let bg      = Color(hex: 0x0f0f11)
    static let bg2     = Color(hex: 0x17171a)
    static let bg3     = Color(hex: 0x1e1e22)
    static let bg4     = Color(hex: 0x26262c)
    static let border  = Color.white.opacity(0.07)
    static let border2 = Color.white.opacity(0.12)
    static let accent  = Color(hex: 0xe8c97a)
    static let accent2 = Color(hex: 0xc9a84c)
    static let accentBg = Color(hex: 0xe8c97a).opacity(0.08)
    static let text    = Color(hex: 0xf0ede6)
    static let text2   = Color(hex: 0xa09a8e)
    static let text3   = Color(hex: 0x5e5a54)
    static let red     = Color(hex: 0xe05c5c)
    static let green   = Color(hex: 0x5cba8a)
    static let blue    = Color(hex: 0x5c9fe0)

    // MARK: Rayons
    static let radiusSm: CGFloat = 6
    static let radius: CGFloat = 10
    static let radiusLg: CGFloat = 16

    // MARK: Polices
    static func serif(_ size: CGFloat) -> Font {
        .custom("DMSerifDisplay-Regular", size: size)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .medium ? "DMSans-Medium" : "DMSans-Regular", size: size)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

/// Pastille de statut de lecture — équivalent .status-read/.status-reading/.status-unread
struct StatusDot: View {
    let status: ReadStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }

    private var color: Color {
        switch status {
        case .read: return BDTheme.green
        case .reading: return BDTheme.accent
        case .unread: return BDTheme.text3
        }
    }
}

/// Badge collection/wishlist — équivalent .badge-collection/.badge-wishlist
struct BDBadge: View {
    enum Kind { case collection, wishlist }
    let kind: Kind
    let text: String

    var body: some View {
        Text(text)
            .font(BDTheme.sans(11))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(kind == .collection ? BDTheme.green.opacity(0.15) : BDTheme.accentBg)
            .foregroundColor(kind == .collection ? BDTheme.green : BDTheme.accent)
            .clipShape(Capsule())
    }
}

/// Bouton primaire doré — équivalent .btn-primary
struct BDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BDTheme.sans(14))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? BDTheme.accent2 : BDTheme.accent)
            .foregroundColor(BDTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: BDTheme.radiusSm, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Bouton ghost — équivalent .btn-ghost
struct BDGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BDTheme.sans(14))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? BDTheme.bg3 : Color.clear)
            .foregroundColor(BDTheme.text2)
            .overlay(
                RoundedRectangle(cornerRadius: BDTheme.radiusSm, style: .continuous)
                    .stroke(BDTheme.border2, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BDTheme.radiusSm, style: .continuous))
    }
}

extension ButtonStyle where Self == BDPrimaryButtonStyle {
    static var bdPrimary: BDPrimaryButtonStyle { BDPrimaryButtonStyle() }
}
extension ButtonStyle where Self == BDGhostButtonStyle {
    static var bdGhost: BDGhostButtonStyle { BDGhostButtonStyle() }
}
