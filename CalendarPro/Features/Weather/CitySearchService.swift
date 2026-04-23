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

struct CitySearchService: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async -> [CitySearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        guard var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search") else {
            return []
        }

        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: AppLocalization.languageCode),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
            return decoded.results ?? []
        } catch {
            return []
        }
    }
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
