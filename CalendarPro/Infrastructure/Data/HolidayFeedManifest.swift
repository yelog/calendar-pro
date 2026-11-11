import Foundation

enum HolidayFeedManifestError: Error, Equatable {
    case emptyVersion
    case emptyPayloads
    case invalidRegionID(String)
    case invalidYear(Int)
    case unsafePath(String)
    case duplicatePayload(String)
}

struct HolidayFeedManifest: Codable, Equatable, Sendable {
    struct Payload: Codable, Equatable, Identifiable, Sendable {
        let regionID: String
        let year: Int
        let path: String

        var id: String {
            "\(regionID)-\(year)"
        }

        func resolvedURL(relativeTo manifestURL: URL) -> URL? {
            if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
                return absoluteURL
            }

            let baseURL = manifestURL.deletingLastPathComponent()
            return URL(string: path, relativeTo: baseURL)?.absoluteURL
        }
    }

    let version: String
    let generatedAt: Date
    let payloads: [Payload]

    func validate() throws {
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HolidayFeedManifestError.emptyVersion
        }
        guard !payloads.isEmpty else {
            throw HolidayFeedManifestError.emptyPayloads
        }

        var seenIDs: Set<String> = []
        for payload in payloads {
            guard Self.isValidRegionID(payload.regionID) else {
                throw HolidayFeedManifestError.invalidRegionID(payload.regionID)
            }
            guard (1900...2199).contains(payload.year) else {
                throw HolidayFeedManifestError.invalidYear(payload.year)
            }
            guard Self.isSafePayloadPath(payload.path) else {
                throw HolidayFeedManifestError.unsafePath(payload.path)
            }
            guard seenIDs.insert(payload.id).inserted else {
                throw HolidayFeedManifestError.duplicatePayload(payload.id)
            }
        }
    }

    private static func isValidRegionID(_ value: String) -> Bool {
        value.range(
            of: #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isSafePayloadPath(_ value: String) -> Bool {
        guard
            !value.isEmpty,
            !value.hasPrefix("/"),
            !value.contains("\\"),
            !value.contains("..")
        else {
            return false
        }

        if let url = URL(string: value), let scheme = url.scheme {
            return ["http", "https"].contains(scheme.lowercased()) && url.host != nil
        }

        return !value.split(separator: "/", omittingEmptySubsequences: false).contains("")
    }
}

extension HolidayFeedManifest {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
