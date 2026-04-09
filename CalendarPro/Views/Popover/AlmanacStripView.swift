import SwiftUI

import tyme

struct AlmanacStripView: View {
    let almanac: AlmanacDescriptor
    @Environment(\.colorScheme) private var colorScheme

    private var maxVisibleRecommends: Int {
        almanac.recommends.count > 3 ? 3 : almanac.recommends.count
    }

    private var maxVisibleAvoids: Int {
        almanac.avoids.count > 2 ? 2 : almanac.avoids.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(String(localized: "Recommended"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)

                Text(almanac.recommendsText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.green.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !almanac.avoids.isEmpty {
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                Text(String(localized: "Avoid"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)

                Text(avoidsText)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.red.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.15), lineWidth: 0.5)
        }
    }

    private var avoidsText: String {
        almanac.avoids.joined(separator: "·")
    }
}
