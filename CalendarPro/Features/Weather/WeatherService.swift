import Foundation

struct WeatherDescriptor: Equatable, Sendable {
    let locationName: String
    let temperatureText: String
    let apparentTemperature: Double?
    let forecastDate: Date?
    let weatherCode: Int
    let isDaytime: Bool
    let isCurrentConditions: Bool
    let humidity: Int?
    let precipitation: Double?
    let precipitationProbability: Int?
    let windSpeed: Double?
    let windDirection: Double?
    let windGusts: Double?
    let airQualityIndex: Int?
    let pm25: Double?
    let uvIndex: Double?

    init(
        locationName: String,
        temperatureText: String,
        apparentTemperature: Double?,
        forecastDate: Date?,
        weatherCode: Int,
        isDaytime: Bool,
        isCurrentConditions: Bool,
        humidity: Int? = nil,
        precipitation: Double? = nil,
        precipitationProbability: Int? = nil,
        windSpeed: Double? = nil,
        windDirection: Double? = nil,
        windGusts: Double? = nil,
        airQualityIndex: Int? = nil,
        pm25: Double? = nil,
        uvIndex: Double? = nil
    ) {
        self.locationName = locationName
        self.temperatureText = temperatureText
        self.apparentTemperature = apparentTemperature
        self.forecastDate = forecastDate
        self.weatherCode = weatherCode
        self.isDaytime = isDaytime
        self.isCurrentConditions = isCurrentConditions
        self.humidity = humidity
        self.precipitation = precipitation
        self.precipitationProbability = precipitationProbability
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.windGusts = windGusts
        self.airQualityIndex = airQualityIndex
        self.pm25 = pm25
        self.uvIndex = uvIndex
    }

    var hasContent: Bool {
        weatherCode >= 0 && !temperatureText.isEmpty
    }

    var iconSystemName: String {
        WMOWeatherCode.iconSystemName(for: weatherCode, isDaytime: isDaytime)
    }

    var description: String {
        WMOWeatherCode.description(for: weatherCode)
    }

    static let empty = WeatherDescriptor(
        locationName: "",
        temperatureText: "",
        apparentTemperature: nil,
        forecastDate: nil,
        weatherCode: -1,
        isDaytime: true,
        isCurrentConditions: true
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
    let manualLocation: WeatherLocation?

    private let cachedLocation = LockedValue<LocationMetadata?>(nil)
    private let cachedSnapshot = LockedValue<WeatherSnapshot?>(nil)

    init(
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = Date.init,
        refreshInterval: TimeInterval = 30 * 60,
        manualLocation: WeatherLocation? = nil
    ) {
        self.session = session
        self.now = now
        self.refreshInterval = refreshInterval
        self.manualLocation = manualLocation
    }

    func fetchCurrentWeather() async -> WeatherDescriptor {
        await describe(date: now())
    }

    func describe(date: Date, calendar: Calendar = .autoupdatingCurrent) async -> WeatherDescriptor {
        guard let snapshot = await fetchSnapshot() else {
            return .empty
        }

        if calendar.isDate(date, inSameDayAs: now()) {
            return makeCurrentDescriptor(from: snapshot)
        }

        guard let forecast = snapshot.dailyForecasts.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) else {
            return .empty
        }

        return makeForecastDescriptor(from: snapshot, forecast: forecast, calendar: calendar)
    }

    private func fetchSnapshot() async -> WeatherSnapshot? {
        if let cachedSnapshot = cachedSnapshot.value,
           now().timeIntervalSince(cachedSnapshot.fetchedAt) < refreshInterval {
            return cachedSnapshot
        }

        let location: LocationMetadata?
        if let manual = manualLocation {
            location = LocationMetadata(
                latitude: manual.latitude,
                longitude: manual.longitude,
                displayName: manual.name
            )
        } else if let cachedLocation = cachedLocation.value {
            location = cachedLocation
        } else {
            location = await resolveLocation()
            if let location {
                cachedLocation.value = location
            }
        }

        guard let location,
              let url = openMeteoURL(latitude: location.latitude, longitude: location.longitude) else {
            return nil
        }

        guard let result = await fetchForecast(from: url) else {
            return nil
        }

        let airQuality = await fetchAirQuality(latitude: location.latitude, longitude: location.longitude)
        let snapshot = WeatherSnapshot(
            locationName: location.displayName,
            current: result.current.toSnapshot(),
            dailyForecasts: result.daily.forecasts,
            airQuality: airQuality,
            fetchedAt: now()
        )
        cachedSnapshot.value = snapshot
        return snapshot
    }

    private func makeCurrentDescriptor(from snapshot: WeatherSnapshot) -> WeatherDescriptor {
        let airQuality = snapshot.airQuality?.current

        return WeatherDescriptor(
            locationName: snapshot.locationName,
            temperatureText: Self.formattedTemperature(snapshot.current.temperature),
            apparentTemperature: snapshot.current.apparentTemperature,
            forecastDate: nil,
            weatherCode: snapshot.current.weatherCode,
            isDaytime: snapshot.current.isDaytime,
            isCurrentConditions: true,
            humidity: snapshot.current.humidity,
            precipitation: snapshot.current.precipitation,
            windSpeed: snapshot.current.windSpeed,
            windDirection: snapshot.current.windDirection,
            windGusts: snapshot.current.windGusts,
            airQualityIndex: airQuality?.usAQI,
            pm25: airQuality?.pm25
        )
    }

    private func makeForecastDescriptor(
        from snapshot: WeatherSnapshot,
        forecast: DailyWeatherForecast,
        calendar: Calendar
    ) -> WeatherDescriptor {
        let airQuality = airQualitySummary(for: forecast.date, in: snapshot, calendar: calendar)

        return WeatherDescriptor(
            locationName: snapshot.locationName,
            temperatureText: "\(Self.formattedTemperature(forecast.maxTemperature)) / \(Self.formattedTemperature(forecast.minTemperature))",
            apparentTemperature: nil,
            forecastDate: forecast.date,
            weatherCode: forecast.weatherCode,
            isDaytime: true,
            isCurrentConditions: false,
            precipitation: forecast.precipitationSum,
            precipitationProbability: forecast.precipitationProbabilityMax,
            windSpeed: forecast.windSpeedMax,
            windDirection: forecast.windDirectionDominant,
            windGusts: forecast.windGustsMax,
            airQualityIndex: airQuality?.usAQI,
            pm25: airQuality?.pm25,
            uvIndex: forecast.uvIndexMax
        )
    }

    private static func formattedTemperature(_ value: Double) -> String {
        "\(Int(round(value)))°"
    }

    private func fetchForecast(from url: URL) async -> OpenMeteoResponse? {
        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            return try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func fetchAirQuality(latitude: Double, longitude: Double) async -> AirQualitySnapshot? {
        guard let url = openMeteoAirQualityURL(latitude: latitude, longitude: longitude) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let result = try JSONDecoder().decode(OpenMeteoAirQualityResponse.self, from: data)
            return result.toSnapshot()
        } catch {
            return nil
        }
    }

    private func airQualitySummary(
        for date: Date,
        in snapshot: WeatherSnapshot,
        calendar: Calendar
    ) -> AirQualitySummary? {
        guard let airQuality = snapshot.airQuality else {
            return nil
        }

        let forecasts = airQuality.hourlyForecasts.filter { forecast in
            calendar.isDate(forecast.date, inSameDayAs: date)
        }
        guard !forecasts.isEmpty else {
            return nil
        }

        let aqiValues = forecasts.compactMap(\.usAQI)
        let pm25Values = forecasts.compactMap(\.pm25)
        let averagePM25: Double?
        if pm25Values.isEmpty {
            averagePM25 = nil
        } else {
            averagePM25 = pm25Values.reduce(0, +) / Double(pm25Values.count)
        }

        guard !aqiValues.isEmpty || averagePM25 != nil else {
            return nil
        }

        return AirQualitySummary(
            usAQI: aqiValues.max(),
            pm25: averagePM25
        )
    }

    private func resolveLocation() async -> LocationMetadata? {
        if let location = await resolveLocation(from: ipWhoURL, parser: { (response: IPWhoLocationResponse) in
            guard response.success != false,
                  let latitude = response.latitude,
                  let longitude = response.longitude else {
                return nil
            }

            return LocationMetadata(
                latitude: latitude,
                longitude: longitude,
                displayName: Self.locationDisplayName(
                    city: response.city,
                    region: response.region,
                    country: response.country
                )
            )
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

            return LocationMetadata(
                latitude: latitude,
                longitude: longitude,
                displayName: Self.locationDisplayName(
                    city: response.city,
                    region: response.region,
                    country: response.country
                )
            )
        }) {
            return location
        }

        return await resolveLocation(from: ipAPIURL, parser: { (response: IPAPILocationResponse) in
            guard let latitude = response.latitude,
                  let longitude = response.longitude else {
                return nil
            }

            return LocationMetadata(
                latitude: latitude,
                longitude: longitude,
                displayName: Self.locationDisplayName(
                    city: response.city,
                    region: response.region,
                    country: response.countryName
                )
            )
        })
    }

    private func resolveLocation<Response: Decodable>(
        from url: URL?,
        parser: (Response) -> LocationMetadata?
    ) async -> LocationMetadata? {
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

    private static func locationDisplayName(city: String?, region: String?, country: String?) -> String {
        let trimmedCity = city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = region?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCountry = country?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedCity, !trimmedCity.isEmpty {
            return trimmedCity
        }

        let regionCountry = [trimmedRegion, trimmedCountry]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        if !regionCountry.isEmpty {
            return regionCountry.joined(separator: ", ")
        }

        return trimmedCountry ?? ""
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
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant,wind_gusts_10m_max,uv_index_max"),
            URLQueryItem(name: "past_days", value: "31"),
            URLQueryItem(name: "forecast_days", value: "16"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }

    private func openMeteoAirQualityURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "us_aqi,pm2_5"),
            URLQueryItem(name: "hourly", value: "us_aqi,pm2_5"),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }
}

private struct LocationMetadata: Sendable {
    let latitude: Double
    let longitude: Double
    let displayName: String
}

private struct WeatherSnapshot: Sendable {
    let locationName: String
    let current: CurrentWeatherSnapshot
    let dailyForecasts: [DailyWeatherForecast]
    let airQuality: AirQualitySnapshot?
    let fetchedAt: Date
}

private struct CurrentWeatherSnapshot: Sendable {
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let isDaytime: Bool
    let humidity: Int?
    let precipitation: Double?
    let windSpeed: Double?
    let windDirection: Double?
    let windGusts: Double?
}

private struct DailyWeatherForecast: Sendable {
    let date: Date
    let weatherCode: Int
    let maxTemperature: Double
    let minTemperature: Double
    let precipitationSum: Double?
    let precipitationProbabilityMax: Int?
    let windSpeedMax: Double?
    let windDirectionDominant: Double?
    let windGustsMax: Double?
    let uvIndexMax: Double?
}

private struct AirQualitySnapshot: Sendable {
    let current: CurrentAirQualitySnapshot?
    let hourlyForecasts: [HourlyAirQualityForecast]
}

private struct CurrentAirQualitySnapshot: Sendable {
    let usAQI: Int?
    let pm25: Double?
}

private struct HourlyAirQualityForecast: Sendable {
    let date: Date
    let usAQI: Int?
    let pm25: Double?
}

private struct AirQualitySummary: Sendable {
    let usAQI: Int?
    let pm25: Double?
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
    let city: String?
    let region: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

private struct IPInfoLocationResponse: Decodable, Sendable {
    let city: String?
    let region: String?
    let country: String?
    let loc: String?
}

private struct IPAPILocationResponse: Decodable, Sendable {
    let city: String?
    let region: String?
    let countryName: String?
    let latitude: Double?
    let longitude: Double?

    private enum CodingKeys: String, CodingKey {
        case city
        case region
        case countryName = "country_name"
        case latitude
        case longitude
    }
}

private struct OpenMeteoResponse: Decodable, Sendable {
    let current: CurrentWeather
    let daily: DailyWeather

    struct CurrentWeather: Decodable, Sendable {
        let temperature2m: Double
        let apparentTemperature: Double
        let relativeHumidity2m: Int?
        let precipitation: Double?
        let weatherCode: Int
        let windSpeed10m: Double?
        let windDirection10m: Double?
        let windGusts10m: Double?
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2m = "relative_humidity_2m"
            case precipitation
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case windGusts10m = "wind_gusts_10m"
            case isDay = "is_day"
        }

        func toSnapshot() -> CurrentWeatherSnapshot {
            CurrentWeatherSnapshot(
                temperature: temperature2m,
                apparentTemperature: apparentTemperature,
                weatherCode: weatherCode,
                isDaytime: isDay == 1,
                humidity: relativeHumidity2m,
                precipitation: precipitation,
                windSpeed: windSpeed10m,
                windDirection: windDirection10m,
                windGusts: windGusts10m
            )
        }
    }

    struct DailyWeather: Decodable, Sendable {
        let time: [String]
        let weatherCode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let precipitationSum: [Double?]?
        let precipitationProbabilityMax: [Int?]?
        let windSpeed10mMax: [Double?]?
        let windDirection10mDominant: [Double?]?
        let windGusts10mMax: [Double?]?
        let uvIndexMax: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case windSpeed10mMax = "wind_speed_10m_max"
            case windDirection10mDominant = "wind_direction_10m_dominant"
            case windGusts10mMax = "wind_gusts_10m_max"
            case uvIndexMax = "uv_index_max"
        }

        var forecasts: [DailyWeatherForecast] {
            let count = Swift.min(
                time.count,
                Swift.min(weatherCode.count, Swift.min(temperature2mMax.count, temperature2mMin.count))
            )
            guard count > 0 else { return [] }

            return (0..<count).compactMap { index in
                guard let date = Self.dateFormatter.date(from: time[index]) else {
                    return nil
                }

                return DailyWeatherForecast(
                    date: date,
                    weatherCode: weatherCode[index],
                    maxTemperature: temperature2mMax[index],
                    minTemperature: temperature2mMin[index],
                    precipitationSum: Self.optionalValue(from: precipitationSum, at: index),
                    precipitationProbabilityMax: Self.optionalValue(from: precipitationProbabilityMax, at: index),
                    windSpeedMax: Self.optionalValue(from: windSpeed10mMax, at: index),
                    windDirectionDominant: Self.optionalValue(from: windDirection10mDominant, at: index),
                    windGustsMax: Self.optionalValue(from: windGusts10mMax, at: index),
                    uvIndexMax: Self.optionalValue(from: uvIndexMax, at: index)
                )
            }
        }

        private static func optionalValue<Value>(from values: [Value?]?, at index: Int) -> Value? {
            guard let values, values.indices.contains(index) else {
                return nil
            }

            return values[index]
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .autoupdatingCurrent
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
    }
}

private struct OpenMeteoAirQualityResponse: Decodable, Sendable {
    let current: CurrentAirQuality?
    let hourly: HourlyAirQuality?

    func toSnapshot() -> AirQualitySnapshot {
        AirQualitySnapshot(
            current: current?.toSnapshot(),
            hourlyForecasts: hourly?.forecasts ?? []
        )
    }

    struct CurrentAirQuality: Decodable, Sendable {
        let usAQI: Int?
        let pm25: Double?

        enum CodingKeys: String, CodingKey {
            case usAQI = "us_aqi"
            case pm25 = "pm2_5"
        }

        func toSnapshot() -> CurrentAirQualitySnapshot {
            CurrentAirQualitySnapshot(
                usAQI: usAQI,
                pm25: pm25
            )
        }
    }

    struct HourlyAirQuality: Decodable, Sendable {
        let time: [String]
        let usAQI: [Int?]?
        let pm25: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case usAQI = "us_aqi"
            case pm25 = "pm2_5"
        }

        var forecasts: [HourlyAirQualityForecast] {
            time.indices.compactMap { index in
                guard let date = Self.dateFormatter.date(from: time[index]) else {
                    return nil
                }

                return HourlyAirQualityForecast(
                    date: date,
                    usAQI: Self.optionalValue(from: usAQI, at: index),
                    pm25: Self.optionalValue(from: pm25, at: index)
                )
            }
        }

        private static func optionalValue<Value>(from values: [Value?]?, at index: Int) -> Value? {
            guard let values, values.indices.contains(index) else {
                return nil
            }

            return values[index]
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .autoupdatingCurrent
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            return formatter
        }()
    }
}
