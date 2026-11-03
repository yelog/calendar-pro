import Combine
import Foundation
import SwiftUI

enum AppTimeZoneCatalog {
    static let identifiers = Set(TimeZone.knownTimeZoneIdentifiers + ["UTC"]).sorted()

    static func localizedName(for identifier: String, locale: Locale) -> String {
        TimeZone(identifier: identifier)?.localizedName(for: .generic, locale: locale) ?? identifier
    }

    static func utcOffsetText(for timeZone: TimeZone, at date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        return String(format: "UTC%@%d:%02d", sign, magnitude / 3600, (magnitude % 3600) / 60)
    }

    static func matchingIdentifiers(query: String, locale: Locale, at date: Date = Date()) -> [String] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return identifiers }

        return identifiers.filter { identifier in
            let offset = TimeZone(identifier: identifier).map { utcOffsetText(for: $0, at: date) } ?? ""
            let searchableText = [
                identifier,
                identifier.replacingOccurrences(of: "_", with: " "),
                localizedName(for: identifier, locale: locale),
                offset
            ].joined(separator: " ")
            return searchableText.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: locale
            ) != nil
        }
    }
}

@MainActor
private struct AppTimeContextModifier: ViewModifier {
    @ObservedObject var store: SettingsStore
    @State private var systemTimeZone = TimeZone.current

    func body(content: Content) -> some View {
        let timeZone = store.timeZoneIdentifier == nil ? systemTimeZone : store.effectiveTimeZone
        var calendar = store.displayCalendar
        calendar.timeZone = timeZone

        return content
            .environment(\.calendar, calendar)
            .environment(\.timeZone, timeZone)
            .onAppear {
                systemTimeZone = .current
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: RunLoop.main)) { _ in
                systemTimeZone = .current
            }
            .onChange(of: store.timeZoneIdentifier) { _, identifier in
                if identifier == nil {
                    systemTimeZone = .current
                }
            }
    }
}

extension View {
    @MainActor
    func appTimeContext(_ store: SettingsStore) -> some View {
        modifier(AppTimeContextModifier(store: store))
    }
}
