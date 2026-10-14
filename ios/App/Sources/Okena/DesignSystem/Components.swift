import OkenaCore
import SwiftUI
import UIKit

// The words on the screen are the words on the wire.

extension Zona {
    var label: String {
        self == .casa ? "Casa" : "Praça"
    }
}

extension Papel {
    var label: String {
        self == .zelador ? "Zelador" : "Morador"
    }
}

// MARK: buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    struct Content: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .typeStyle(Theme.Text.label)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.controlMd)
                .background(Theme.Palette.brandPrimary, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .foregroundStyle(Theme.Palette.textOnBrand)
                .opacity(enabled ? (configuration.isPressed ? Theme.Opacity.muted : 1) : Theme.Opacity.disabled)
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var textColor: Color = Theme.Palette.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, textColor: textColor)
    }

    struct Content: View {
        let configuration: Configuration
        let textColor: Color
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .typeStyle(Theme.Text.label)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.controlMd)
                .background(Theme.Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(Theme.Palette.borderDefault, lineWidth: Theme.Size.hairline)
                )
                .opacity(enabled ? (configuration.isPressed ? Theme.Opacity.muted : 1) : Theme.Opacity.disabled)
        }
    }
}

struct PrimaryButton: View {
    var title: String
    var loading = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.space2) {
                if loading {
                    ProgressView()
                        .tint(Theme.Palette.textOnBrand)
                }
                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(loading)
    }
}

struct SecondaryButton: View {
    var title: String
    var textColor: Color = Theme.Palette.textPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(SecondaryButtonStyle(textColor: textColor))
    }
}

// MARK: field

/// The labeled form field: `field-bg` fill, `border-default` stroke, the
/// focus ring in `brand-primary`, and the error messages of the field in
/// `feedback-error`.
struct TainaField: View {
    let label: String
    @Binding var text: String
    var secure = false
    var errorMessages: [String] = []
    var autocapitalization: TextInputAutocapitalization = .never
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.space1) {
            Text(label)
                .typeStyle(Theme.Text.label)
                .foregroundStyle(Theme.Palette.textSecondary)
            field
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textPrimary)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .focused($focused)
                .padding(.horizontal, Theme.Space.space3)
                .frame(minHeight: Theme.Size.controlMd)
                .background(Theme.Palette.fieldBg, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(stroke, lineWidth: focused ? Theme.Size.thick : Theme.Size.hairline)
                )
            ForEach(errorMessages, id: \.self) { message in
                Text(message)
                    .typeStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Palette.feedbackError)
            }
        }
    }

    private var field: some View {
        Group {
            if secure {
                SecureField("", text: $text)
            } else {
                TextField("", text: $text)
            }
        }
    }

    private var stroke: Color {
        if !errorMessages.isEmpty {
            return Theme.Palette.feedbackError
        }
        return focused ? Theme.Palette.brandPrimary : Theme.Palette.borderDefault
    }
}

// MARK: surfaces

/// A list row surface: `surface-default` fill, `border-subtle` stroke,
/// `radius-lg`.
struct RowCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(Theme.Space.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surfaceDefault, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .strokeBorder(Theme.Palette.borderSubtle, lineWidth: Theme.Size.hairline)
            )
    }
}

/// The casa / praça mark, wherever a file or folder appears: the product's
/// core promise, in `service-ybira` for casa and `service-jaci` for praca.
struct ZonaBadge: View {
    let zona: Zona

    var body: some View {
        HStack(spacing: Theme.Space.space1) {
            Image(systemName: zona == .casa ? "lock" : "person.2")
            Text(zona.label)
        }
        .typeStyle(Theme.Text.caption)
        .foregroundStyle(color)
        .padding(.horizontal, Theme.Space.space2)
        .padding(.vertical, Theme.Space.space1)
        .background(soft, in: Capsule())
    }

    private var color: Color {
        zona == .casa ? Theme.Palette.serviceYbira : Theme.Palette.serviceJaci
    }

    private var soft: Color {
        zona == .casa ? Theme.Palette.serviceYbiraSoft : Theme.Palette.serviceJaciSoft
    }
}

// MARK: states

struct EmptyStateAction {
    let title: String
    let action: () -> Void
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var action: EmptyStateAction?

    var body: some View {
        VStack(spacing: Theme.Space.space4) {
            Image(systemName: systemImage)
                .typeStyle(Theme.Text.display)
                .foregroundStyle(Theme.Palette.textFaint)
            VStack(spacing: Theme.Space.space2) {
                Text(title)
                    .typeStyle(Theme.Text.h3)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .typeStyle(Theme.Text.bodySm)
                    .foregroundStyle(Theme.Palette.textMuted)
                    .multilineTextAlignment(.center)
            }
            if let action {
                SecondaryButton(title: action.title, action: action.action)
            }
        }
        .padding(Theme.Space.space8)
        .frame(maxWidth: .infinity)
    }
}

/// The failure, with a way out: for `.api` the server's own pt-BR message,
/// for the local cases the error's pt-BR description.
struct ErrorView: View {
    let error: TainaError
    var retry: (() async -> Void)?

    var body: some View {
        VStack(spacing: Theme.Space.space4) {
            Image(systemName: "exclamationmark.triangle")
                .typeStyle(Theme.Text.h2)
                .foregroundStyle(Theme.Palette.feedbackWarning)
            Text(error.errorDescription ?? "Algo deu errado. Tente de novo.")
                .typeStyle(Theme.Text.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                SecondaryButton(title: "Tentar de novo") {
                    Task { await retry() }
                }
            }
        }
        .padding(Theme.Space.space5)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: Theme.Space.space3) {
            ProgressView()
                .tint(Theme.Palette.textMuted)
            Text("Carregando...")
                .typeStyle(Theme.Text.bodySm)
                .foregroundStyle(Theme.Palette.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
