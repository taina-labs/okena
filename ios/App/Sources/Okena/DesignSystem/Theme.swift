import SwiftUI

/// The design tokens, ported from `design/tokens.css` (the exact mirror of
/// Penpot). Two levels, same names: primitives (raw palette and scale) and
/// semantic (what components consume). Views never touch `Primitive` and
/// never write a raw value; every semantic constant carries its CSS token
/// name in the comment, in the file's order, so a drift check against
/// `tokens.css` is a name-by-name comparison.
enum Theme {
    /// The three families of the design, by name. The OFL files are not
    /// bundled yet, so `Font.custom` falls back to the system face; the
    /// names are already the final ones.
    enum Fonts {
        static let display = "Bricolage Grotesque"  // --font-family-display
        static let body = "Schibsted Grotesk"       // --font-family-body
        static let mono = "JetBrains Mono"          // --font-family-mono
    }

    /// Raw palette. Not for views.
    enum Primitive {
        static let night950 = Color(hex: 0x060a14)  // --color-night-950
        static let night900 = Color(hex: 0x0a101f)  // --color-night-900
        static let night800 = Color(hex: 0x0f1729)  // --color-night-800
        static let night700 = Color(hex: 0x15203a)  // --color-night-700
        static let night600 = Color(hex: 0x1d2c4e)  // --color-night-600
        static let night500 = Color(hex: 0x28395f)  // --color-night-500
        static let night400 = Color(hex: 0x3a4d7a)  // --color-night-400
        static let night300 = Color(hex: 0x56689b)  // --color-night-300
        static let night200 = Color(hex: 0x8c9ac0)  // --color-night-200
        static let night100 = Color(hex: 0xbfc8df)  // --color-night-100
        static let night50 = Color(hex: 0xeef1f8)   // --color-night-50

        static let dawn300 = Color(hex: 0xffd9a3)  // --color-dawn-300
        static let dawn400 = Color(hex: 0xfcbe74)  // --color-dawn-400
        static let dawn500 = Color(hex: 0xf2a65a)  // --color-dawn-500
        static let dawn600 = Color(hex: 0xdd8a3e)  // --color-dawn-600
        static let dawn700 = Color(hex: 0xb96d2c)  // --color-dawn-700

        static let ember400 = Color(hex: 0xf08a6c)  // --color-ember-400
        static let ember500 = Color(hex: 0xe2674a)  // --color-ember-500
        static let ember600 = Color(hex: 0xc44e33)  // --color-ember-600

        static let star50 = Color(hex: 0xfaf7f0)    // --color-star-50
        static let star100 = Color(hex: 0xf1ecdf)   // --color-star-100
        static let star200 = Color(hex: 0xe4dcc8)   // --color-star-200

        static let forest300 = Color(hex: 0x82cba4)  // --color-forest-300
        static let forest400 = Color(hex: 0x5fb88a)  // --color-forest-400
        static let forest500 = Color(hex: 0x3fa171)  // --color-forest-500
        static let forest600 = Color(hex: 0x2f8159)  // --color-forest-600
        static let forest700 = Color(hex: 0x246244)  // --color-forest-700
        static let forest900 = Color(hex: 0x122e22)  // --color-forest-900

        static let moon300 = Color(hex: 0xf4dfa6)  // --color-moon-300
        static let moon400 = Color(hex: 0xeccd80)  // --color-moon-400
        static let moon500 = Color(hex: 0xe3bc66)  // --color-moon-500
        static let moon600 = Color(hex: 0xc49a48)  // --color-moon-600
        static let moon700 = Color(hex: 0x9c7836)  // --color-moon-700
        static let moon900 = Color(hex: 0x46350f)  // --color-moon-900

        static let guara500 = Color(hex: 0xde5b3f)  // --color-guara-500
        static let guara600 = Color(hex: 0xbe4327)  // --color-guara-600

        static let sky300 = Color(hex: 0x92c3f8)  // --color-sky-300
        static let sky500 = Color(hex: 0x5ba3f5)  // --color-sky-500
        static let sky600 = Color(hex: 0x3f84d6)  // --color-sky-600
        static let sky700 = Color(hex: 0x2f66ac)  // --color-sky-700

        static let red500 = Color(hex: 0xe5484d)   // --color-red-500
        static let red600 = Color(hex: 0xc03538)   // --color-red-600
        static let amber500 = Color(hex: 0xefb54a)  // --color-amber-500
    }

    enum Radius {
        static let sm: CGFloat = 8      // --radius-sm
        static let md: CGFloat = 12     // --radius-md
        static let lg: CGFloat = 16     // --radius-lg
        static let xl: CGFloat = 24     // --radius-xl
        static let pill: CGFloat = 999  // --radius-pill
    }

    enum Space {
        static let space1: CGFloat = 4    // --space-1
        static let space2: CGFloat = 8    // --space-2
        static let space3: CGFloat = 12   // --space-3
        static let space4: CGFloat = 16   // --space-4
        static let space5: CGFloat = 20   // --space-5
        static let space6: CGFloat = 24   // --space-6
        static let space8: CGFloat = 32   // --space-8
        static let space10: CGFloat = 40  // --space-10
        static let space12: CGFloat = 48  // --space-12
        static let space16: CGFloat = 64  // --space-16
    }

    enum Size {
        static let touch: CGFloat = 44          // --size-touch
        static let controlSm: CGFloat = 36      // --size-control-sm
        static let controlMd: CGFloat = 48      // --size-control-md
        static let controlLg: CGFloat = 56      // --size-control-lg
        static let navMobile: CGFloat = 72      // --size-nav-mobile
        static let appbar: CGFloat = 64         // --size-appbar
        static let navDot: CGFloat = 6          // --size-nav-dot

        static let hairline: CGFloat = 1        // --border-hairline
        static let thick: CGFloat = 2           // --border-thick

        // Semantic component sizes.
        // The --measure-* group (sm, md, measure, wide, card, shell,
        // shell-wide) is left out on purpose: they are web container
        // widths, and iOS lays out with the system, not with fixed widths.
        static let sidebar: CGFloat = 248   // --size-sidebar
        static let menuMin: CGFloat = 180   // --size-menu-min
        static let qr: CGFloat = 200        // --size-qr
        static let gapPhoto: CGFloat = 2    // --gap-photo
        static let badge: CGFloat = 24      // --size-badge
        static let progress: CGFloat = 6    // --size-progress
    }

    enum Opacity {
        static let disabled: Double = 0.4   // --opacity-disabled
        static let muted: Double = 0.72     // --opacity-muted
        static let scrim: Double = 0.64     // --opacity-scrim
    }

    enum Elevation {
        struct Shadow {
            let y: CGFloat
            let radius: CGFloat
            let color: Color
        }

        // CSS blur is twice the SwiftUI radius, so 16px of blur is radius
        // 8. The CSS spread (-4px on lifted) has no SwiftUI counterpart.
        static let soft = Shadow(
            y: 4, radius: 8,
            color: Color(hex: 0x060a14, alpha: 0.5)  // --elevation-soft: 0 4px 16px rgb(6 10 20 / 0.5)
        )
        static let lifted = Shadow(
            y: 12, radius: 16,
            color: Color(hex: 0x060a14, alpha: 0.65)  // --elevation-lifted: 0 12px 32px -4px rgb(6 10 20 / 0.65)
        )
    }

    /// The semantic layer. The only colors a component consumes.
    enum Palette {
        static let bgApp = Primitive.night900   // --bg-app
        static let bgDeep = Primitive.night950  // --bg-deep
        static let bgQr = Primitive.star50      // --bg-qr

        static let surfaceDefault = Primitive.night800                   // --surface-default
        static let surfaceRaised = Primitive.night700                    // --surface-raised
        static let surfaceHigh = Primitive.night600                      // --surface-high
        static let surfaceOverlay = Primitive.night900.opacity(0.88)     // --surface-overlay
        static let surfaceDim = Primitive.night500                       // --surface-dim
        static let surfaceScrim = Primitive.night950.opacity(0.64)       // --surface-scrim
        static let surfaceScrimStrong = Primitive.night950.opacity(0.5)  // --surface-scrim-strong
        static let surfaceTintBrand = Primitive.dawn500.opacity(0.08)    // --surface-tint-brand

        static let borderSubtle = Primitive.night700  // --border-subtle
        static let borderDefault = Primitive.night600  // --border-default
        static let borderStrong = Primitive.night500   // --border-strong

        static let textPrimary = Primitive.star50     // --text-primary
        static let textSecondary = Primitive.night100  // --text-secondary
        static let textMuted = Primitive.night200      // --text-muted
        static let textFaint = Primitive.night300      // --text-faint
        static let textOnBrand = Primitive.night950    // --text-on-brand

        static let brandPrimary = Primitive.dawn500          // --brand-primary
        static let brandPrimaryHover = Primitive.dawn400     // --brand-primary-hover
        static let brandPrimaryPressed = Primitive.dawn600   // --brand-primary-pressed
        static let brandEmber = Primitive.ember500           // --brand-ember

        static let serviceYbira = Primitive.forest500       // --service-ybira
        static let serviceYbiraSoft = Primitive.forest900   // --service-ybira-soft
        static let serviceYbiraHover = Primitive.forest400  // --service-ybira-hover
        static let serviceYbiraTint = Primitive.forest300   // --service-ybira-tint
        static let serviceJaci = Primitive.moon500          // --service-jaci
        static let serviceJaciSoft = Primitive.moon900      // --service-jaci-soft
        static let serviceJaciTint = Primitive.moon400      // --service-jaci-tint
        static let serviceNhaman = Primitive.sky500         // --service-nhaman
        static let serviceVideo = Primitive.sky300          // --service-video
        static let serviceGuara = Primitive.guara500        // --service-guara

        static let feedbackSuccess = Primitive.forest400  // --feedback-success
        static let feedbackWarning = Primitive.amber500   // --feedback-warning
        static let feedbackError = Primitive.red500       // --feedback-error
        static let feedbackInfo = Primitive.sky500        // --feedback-info

        // Translucent tints for the deterministic avatar colors (hash -> 0..3).
        static let avatarTint0 = Primitive.dawn500.opacity(0.16)    // --avatar-tint-0
        static let avatarTint1 = Primitive.forest500.opacity(0.16)  // --avatar-tint-1
        static let avatarTint2 = Primitive.moon500.opacity(0.16)    // --avatar-tint-2
        static let avatarTint3 = Primitive.sky500.opacity(0.16)     // --avatar-tint-3

        static let fieldBg = Primitive.night800.opacity(0.6)  // --field-bg
    }

    /// The type-* styles, with the weight, tracking and line-height from
    /// `assets/css/base.css`. The weights are the named SwiftUI weights:
    /// regular 400, medium 500, semibold 600, bold 700, extrabold 800
    /// (the --font-weight-* primitives).
    enum Text {
        struct Style {
            let font: Font
            let tracking: CGFloat
            let lineSpacing: CGFloat
            let uppercase: Bool
        }

        // Primitives - font size, rem at 16px, and tracking.
        static let fontSizeXs: CGFloat = 12          // --font-size-xs
        static let fontSizeSm: CGFloat = 14          // --font-size-sm
        static let fontSizeMd: CGFloat = 16          // --font-size-md
        static let fontSizeLg: CGFloat = 18          // --font-size-lg
        static let fontSizeXl: CGFloat = 22          // --font-size-xl
        static let fontSize2xl: CGFloat = 28         // --font-size-2xl
        static let fontSize3xl: CGFloat = 36         // --font-size-3xl
        static let fontSizeDisplay: CGFloat = 44     // --font-size-display
        static let fontSizeMonoSm: CGFloat = 13      // --font-size-mono-sm

        static let trackingTight: CGFloat = -0.5     // --tracking-tight
        static let trackingNormal: CGFloat = 0       // --tracking-normal
        static let trackingWide: CGFloat = 1.5       // --tracking-wide

        // type-display: bold, tight, line-height 1.05
        static let display = Style(
            font: .custom(Fonts.display, size: fontSizeDisplay, relativeTo: .largeTitle).weight(.bold),
            tracking: trackingTight,
            lineSpacing: 2.2,  // (1.05 - 1) x 44
            uppercase: false
        )

        // type-h1: bold, tight, line-height 1.1
        static let h1 = Style(
            font: .custom(Fonts.display, size: fontSize3xl, relativeTo: .largeTitle).weight(.bold),
            tracking: trackingTight,
            lineSpacing: 3.6,  // (1.1 - 1) x 36
            uppercase: false
        )

        // type-h2: semibold, line-height 1.15
        static let h2 = Style(
            font: .custom(Fonts.display, size: fontSize2xl, relativeTo: .title).weight(.semibold),
            tracking: trackingNormal,
            lineSpacing: 4.2,  // (1.15 - 1) x 28
            uppercase: false
        )

        // type-h3: semibold, line-height 1.25
        static let h3 = Style(
            font: .custom(Fonts.display, size: fontSizeLg, relativeTo: .title3).weight(.semibold),
            tracking: trackingNormal,
            lineSpacing: 4.5,  // (1.25 - 1) x 18
            uppercase: false
        )

        // type-body: regular, line-height 1.5
        static let body = Style(
            font: .custom(Fonts.body, size: fontSizeMd, relativeTo: .body),
            tracking: trackingNormal,
            lineSpacing: 8,  // (1.5 - 1) x 16
            uppercase: false
        )

        // type-body-sm: regular, line-height 1.45
        static let bodySm = Style(
            font: .custom(Fonts.body, size: fontSizeSm, relativeTo: .subheadline),
            tracking: trackingNormal,
            lineSpacing: 6.3,  // (1.45 - 1) x 14
            uppercase: false
        )

        // type-label: semibold, line-height 1.2
        static let label = Style(
            font: .custom(Fonts.body, size: fontSizeSm, relativeTo: .subheadline).weight(.semibold),
            tracking: trackingNormal,
            lineSpacing: 2.8,  // (1.2 - 1) x 14
            uppercase: false
        )

        // type-caption: medium, line-height 1.3
        static let caption = Style(
            font: .custom(Fonts.body, size: fontSizeXs, relativeTo: .caption).weight(.medium),
            tracking: trackingNormal,
            lineSpacing: 3.6,  // (1.3 - 1) x 12
            uppercase: false
        )

        // type-overline: semibold, wide, uppercase, line-height 1.2
        static let overline = Style(
            font: .custom(Fonts.body, size: fontSizeXs, relativeTo: .caption).weight(.semibold),
            tracking: trackingWide,
            lineSpacing: 2.4,  // (1.2 - 1) x 12
            uppercase: true
        )

        // type-mono-sm: regular, line-height 1.4, tabular figures so
        // quotas and counts line up in a column.
        static let monoSm = Style(
            font: .custom(Fonts.mono, size: fontSizeMonoSm, relativeTo: .footnote).monospacedDigit(),
            tracking: trackingNormal,
            lineSpacing: 5.2,  // (1.4 - 1) x 13
            uppercase: false
        )
    }
}

extension View {
    /// Applies one type-* style: the font (Dynamic Type through
    /// `relativeTo`), the tracking, the line spacing (CSS line-height minus
    /// 1, times the size) and the text case.
    func typeStyle(_ style: Theme.Text.Style) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

private extension Color {
    init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            .sRGB,
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
