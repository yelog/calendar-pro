import Foundation

struct WeatherDescriptor: Equatable, Sendable {
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let isDaytime: Bool

    var hasContent: Bool {
        weatherCode >= 0
    }

    var iconSystemName: String {
        WMOWeatherCode.iconSystemName(for: weatherCode, isDaytime: isDaytime)
    }

    var description: String {
        WMOWeatherCode.description(for: weatherCode)
    }

    var temperatureText: String {
        "\(Int(round(temperature)))°"
    }

    var apparentTemperatureText: String {
        L("Feels like") + " \(Int(round(apparentTemperature)))°"
    }

    static let empty = WeatherDescriptor(
        temperature: 0,
        apparentTemperature: 0,
        weatherCode: -1,
        isDaytime: true
    )
}

private enum WMOWeatherCode {
    static func iconSystemName(for code: Int, isDaytime: Bool) -> String {
        switch code {
        case 0:
            return isDaytime ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDaytime ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67:
            return "cloud.rain.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0:
            return L("Clear sky")
        case 1:
            return L("Mainly clear")
        case 2:
            return L("Partly cloudy")
        case 3:
            return L("Overcast")
        case 45:
            return L("Fog")
        case 48:
            return L("Depositing rime fog")
        case 51:
            return L("Light drizzle")
        case 53:
            return L("Moderate drizzle")
        case 55:
            return L("Dense drizzle")
        case 56:
            return L("Light freezing drizzle")
        case 57:
            return L("Dense freezing drizzle")
        case 61:
            return L("Slight rain")
        case 63:
            return L("Moderate rain")
        case 65:
            return L("Heavy rain")
        case 66:
            return L("Light freezing rain")
        case 67:
            return L("Heavy freezing rain")
        case 71:
            return L("Slight snowfall")
        case 73:
            return L("Moderate snowfall")
        case 75:
            return L("Heavy snowfall")
        case 77:
            return L("Snow grains")
        case 80:
            return L("Slight rain showers")
        case 81:
            return L("Moderate rain showers")
        case 82:
            return L("Violent rain showers")
        case 85:
            return L("Slight snow showers")
        case 86:
            return L("Heavy snow showers")
        case 95:
            return L("Thunderstorm")
        case 96:
            return L("Thunderstorm with slight hail")
        case 99:
            return L("Thunderstorm with heavy hail")
        default:
            return L("Unknown")
        }
    }
}

struct WeatherService: Sendable {
    let session: URLSession
    let now: @Sendable () -> Date
    let refreshInterval: TimeInterval

    private let cachedLocation = LockedValue<LocationCoordinate?>(nil)
    private let cachedWeather = LockedValue<CachedWeather?>(nil)

    init(
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = Date.init,
        refreshInterval: TimeInterval = 30 * 60
    ) {
        self.session = session
        self.now = now
        self.refreshInterval = refreshInterval
    }

    func fetchCurrentWeather() async -> WeatherDescriptor {
        if let cachedWeather = cachedWeather.value,
           now().timeIntervalSince(cachedWeather.fetchedAt) < refreshInterval {
            return cachedWeather.descriptor
        }

        let location: LocationCoordinate?
        if let cached = cachedLocation.value {
            location = cached
        } else {
            location = await resolveLocation()
            if let location {
                cachedLocation.value = location
            }
        }

        guard let location else {
            return .empty
        }

        guard let url = openMeteoURL(latitude: location.latitude, longitude: location.longitude) else {
            return .empty
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .empty
            }

            let result = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let descriptor = result.current.toDescriptor()
            if descriptor.hasContent {
                cachedWeather.value = CachedWeather(descriptor: descriptor, fetchedAt: now())
            }
            return descriptor
        } catch {
            return .empty
        }
    }

    private func resolveLocation() async -> LocationCoordinate? {
        if let location = await resolveLocation(from: ipWhoURL, parser: { (response: IPWhoLocationResponse) in
            guard response.success != false,
                  let latitude = response.latitude,
                  let longitude = response.longitude else {
                return nil
            }
            return LocationCoordinate(latitude: latitude, longitude: longitude)
        }) {
            return location
        }

        if let location = await resolveLocation(from: ipInfoURL, parser: { (response: IPInfoLocationResponse) in
            guard let loc = response.loc else {
                return nil
            }

            let parts = loc.split(separator: ",", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let latitude = Double(parts[0]),
                  let longitude = Double(parts[1]) else {
                return nil
            }

            return LocationCoordinate(latitude: latitude, longitude: longitude)
        }) {
            return location
        }

        return await resolveLocation(from: ipAPIURL, parser: { (response: IPAPILocationResponse) in
            guard let latitude = response.latitude,
                  let longitude = response.longitude else {
                return nil
            }
            return LocationCoordinate(latitude: latitude, longitude: longitude)
        })
    }

    private func resolveLocation<Response: Decodable>(
        from url: URL?,
        parser: (Response) -> LocationCoordinate?
    ) async -> LocationCoordinate? {
        guard let url else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return parser(decoded)
        } catch {
            return nil
        }
    }

    private var ipWhoURL: URL? {
        URL(string: "https://ipwho.is/")
    }

    private var ipInfoURL: URL? {
        URL(string: "https://ipinfo.io/json")
    }

    private var ipAPIURL: URL? {
        URL(string: "https://ipapi.co/json/")
    }

    private func openMeteoURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }
}

private struct LocationCoordinate: Sendable {
    let latitude: Double
    let longitude: Double
}

private struct CachedWeather: Sendable {
    let descriptor: WeatherDescriptor
    let fetchedAt: Date
}

private final class LockedValue<T: Sendable>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()

    init(_ value: T) {
        _value = value
    }

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

private struct IPWhoLocationResponse: Decodable, Sendable {
    let success: Bool?
    let latitude: Double?
    let longitude: Double?
}

private struct IPInfoLocationResponse: Decodable, Sendable {
    let loc: String?
}

private struct IPAPILocationResponse: Decodable, Sendable {
    let latitude: Double?
    let longitude: Double?
}

private struct OpenMeteoResponse: Decodable, Sendable {
    let current: CurrentWeather

    struct CurrentWeather: Decodable, Sendable {
        let temperature2m: Double
        let apparentTemperature: Double
        let weatherCode: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }

        func toDescriptor() -> WeatherDescriptor {
            WeatherDescriptor(
                temperature: temperature2m,
                apparentTemperature: apparentTemperature,
                weatherCode: weatherCode,
                isDaytime: isDay == 1
            )
        }
    }
}
