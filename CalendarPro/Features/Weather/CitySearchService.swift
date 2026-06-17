import Foundation

struct CitySearchResult: Identifiable, Sendable {
    let id: Int
    let name: String
    let country: String?
    let admin1: String?
    let latitude: Double
    let longitude: Double

    var displayName: String {
        let parts = [name, admin1, country].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    var toWeatherLocation: WeatherLocation {
        WeatherLocation(
            latitude: latitude,
            longitude: longitude,
            name: name,
            country: country,
            admin1: admin1
        )
    }
}

struct CitySearchOutcome: Equatable, Sendable {
    enum Issue: Equatable, Sendable {
        case noResults
        case failed
    }

    let results: [CitySearchResult]
    let issue: Issue?

    static let empty = CitySearchOutcome(results: [], issue: nil)
}

struct CitySearchService: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async -> [CitySearchResult] {
        await searchDetailed(query: query).results
    }

    func searchDetailed(query: String) async -> CitySearchOutcome {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return .empty
        }

        let candidates = searchCandidates(for: trimmedQuery)
        var sawFailure = false

        for candidate in candidates {
            do {
                let results = try await fetchSearchResults(for: candidate)
                if !results.isEmpty {
                    return CitySearchOutcome(results: results, issue: nil)
                }
            } catch {
                sawFailure = true
                break
            }
        }

        return CitySearchOutcome(results: [], issue: sawFailure ? .failed : .noResults)
    }

    private func fetchSearchResults(for candidate: SearchCandidate) async throws -> [CitySearchResult] {
        guard var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search") else {
            throw URLError(.badURL)
        }

        var queryItems = [
            URLQueryItem(name: "name", value: candidate.query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: AppLocalization.languageCode),
            URLQueryItem(name: "format", value: "json")
        ]
        if let countryCode = candidate.countryCode {
            queryItems.append(URLQueryItem(name: "countryCode", value: countryCode))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return decoded.results ?? []
    }

    private func searchCandidates(for query: String) -> [SearchCandidate] {
        var candidates: [SearchCandidate] = []

        func append(_ candidate: SearchCandidate) {
            guard !candidates.contains(candidate) else { return }
            candidates.append(candidate)
        }

        let containsChinese = query.containsChineseCharacter
        append(SearchCandidate(query: query, countryCode: containsChinese ? "CN" : nil))

        if containsChinese {
            if query.chineseCharacterCount == 2 && !query.hasSuffix("市") {
                append(SearchCandidate(query: "\(query)市", countryCode: "CN"))
            }

            if let pinyin = query.pinyinSearchKey, !pinyin.isEmpty, pinyin.caseInsensitiveCompare(query) != .orderedSame {
                append(SearchCandidate(query: pinyin, countryCode: "CN"))
            }

            append(SearchCandidate(query: query, countryCode: nil))
        }

        return candidates
    }
}

private struct SearchCandidate: Equatable {
    let query: String
    let countryCode: String?
}

private struct GeocodingResponse: Decodable, Sendable {
    let results: [CitySearchResult]?
}

extension CitySearchResult: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        admin1 = try container.decodeIfPresent(String.self, forKey: .admin1)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case country
        case admin1
        case latitude
        case longitude
    }
}

extension CitySearchResult: Equatable {}

private extension String {
    var containsChineseCharacter: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    var chineseCharacterCount: Int {
        unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }.count
    }

    var pinyinSearchKey: String? {
        let mutable = NSMutableString(string: self)
        guard CFStringTransform(mutable, nil, kCFStringTransformToLatin, false),
              CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false) else {
            return nil
        }

        let normalized = (mutable as String)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
