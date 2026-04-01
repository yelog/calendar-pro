import SwiftUI

struct SelectableDetailText: View {
    let text: String
    var font: Font = .system(size: 12)
    var foregroundColor: Color = .primary
    var lineLimit: Int? = nil
    var underline = false
    var strikethrough = false

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foregroundColor)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .underline(underline)
            .strikethrough(strikethrough)
            .textSelection(.enabled)
    }
}

struct OpenURLActionButton: View {
    let title: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Label(title, systemImage: "arrow.up.forward.square")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .help(url.absoluteString)
    }
}
