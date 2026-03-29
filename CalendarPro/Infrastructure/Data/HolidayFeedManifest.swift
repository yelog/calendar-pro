import Foundation

struct HolidayFeedManifest: Codable, Equatable {
    struct Payload: Codable, Equatable, Identifiable {
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
