import CoreLocation
import Foundation

struct ResolvedWeatherLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let displayName: String
}

protocol WeatherLocationResolving: Sendable {
    func resolveCurrentLocation() async -> ResolvedWeatherLocation?
}

enum WeatherProviderConfiguration: Equatable, Sendable {
    case openMeteo
    case qWeather(apiHost: String, apiKey: String)
    case wttrIn
    case sevenTimer

    var weatherProvider: WeatherProvider {
        switch self {
        case .openMeteo:
            return .openMeteo
        case .qWeather:
            return .qWeather
        case .wttrIn:
            return .wttrIn
        case .sevenTimer:
            return .sevenTimer
        }
    }

    var isUsable: Bool {
        switch self {
        case .openMeteo, .wttrIn, .sevenTimer:
            return true
        case .qWeather(let apiHost, let apiKey):
            return !apiHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

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
    let cloudCover: Int?
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
        cloudCover: Int? = nil,
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
        self.cloudCover = cloudCover
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

struct WeatherForecastOverview: Equatable, Sendable {
    let current: WeatherDescriptor
    let dailyForecasts: [WeatherDescriptor]

    var hasContent: Bool {
        current.hasContent || dailyForecasts.contains(where: \.hasContent)
    }

    static let empty = WeatherForecastOverview(
        current: .empty,
        dailyForecasts: []
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
    let providerConfiguration: WeatherProviderConfiguration

    private let cachedLocation = LockedValue<LocationMetadata?>(nil)
    private let cachedSnapshot = LockedValue<WeatherSnapshot?>(nil)
    private let inFlightSnapshotRequest = LockedValue<WeatherSnapshotRequest?>(nil)
    private let locationResolver: (any WeatherLocationResolving)?

    init(
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = Date.init,
        refreshInterval: TimeInterval = 30 * 60,
        manualLocation: WeatherLocation? = nil,
        providerConfiguration: WeatherProviderConfiguration = .openMeteo,
        locationResolver: (any WeatherLocationResolving)? = nil
    ) {
        self.session = session
        self.now = now
        self.refreshInterval = refreshInterval
        self.manualLocation = manualLocation
        self.providerConfiguration = providerConfiguration
        self.locationResolver = locationResolver
    }

    func fetchCurrentWeather() async -> WeatherDescriptor {
        await describe(date: now())
    }

    func forecastOverview(days: Int = 10, calendar: Calendar = .autoupdatingCurrent) async -> WeatherForecastOverview {
        guard days > 0, let snapshot = await fetchSnapshot() else {
            return .empty
        }

        let startOfToday = calendar.startOfDay(for: now())
        let forecasts = snapshot.dailyForecasts
            .filter { forecast in
                calendar.startOfDay(for: forecast.date) >= startOfToday
            }
            .prefix(days)
            .map { forecast in
                if calendar.isDate(forecast.date, inSameDayAs: now()) {
                    return makeTodayForecastDescriptor(from: snapshot, forecast: forecast, calendar: calendar)
                }

                return makeForecastDescriptor(from: snapshot, forecast: forecast, calendar: calendar)
            }

        return WeatherForecastOverview(
            current: makeCurrentDescriptor(from: snapshot),
            dailyForecasts: Array(forecasts)
        )
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

    func cancelInFlightSnapshot() {
        let request = inFlightSnapshotRequest.withValue { inFlight -> WeatherSnapshotRequest? in
            let request = inFlight
            inFlight = nil
            return request
        }
        request?.task.cancel()
    }

    private func fetchSnapshot() async -> WeatherSnapshot? {
        if let cachedSnapshot = cachedSnapshot.value,
           now().timeIntervalSince(cachedSnapshot.fetchedAt) < refreshInterval {
            return cachedSnapshot
        }

        let request = inFlightSnapshotRequest.withValue { inFlight in
            if let inFlight {
                return inFlight
            }

            let newRequest = WeatherSnapshotRequest(
                id: UUID(),
                task: Task { await fetchSnapshotFromNetwork() }
            )
            inFlight = newRequest
            return newRequest
        }

        let snapshot = await request.task.value
        inFlightSnapshotRequest.withValue { inFlight in
            guard inFlight?.id == request.id else { return }
            inFlight = nil
        }
        return snapshot
    }

    private func fetchSnapshotFromNetwork() async -> WeatherSnapshot? {
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
            location = await resolveLocationFromPreferredSources()
            if let location {
                cachedLocation.value = location
            }
        }

        guard let location, providerConfiguration.isUsable else {
            return nil
        }

        switch providerConfiguration {
        case .openMeteo:
            return await fetchOpenMeteoSnapshot(for: location)
        case .qWeather(let apiHost, let apiKey):
            return await fetchQWeatherSnapshot(for: location, apiHost: apiHost, apiKey: apiKey)
        case .wttrIn:
            return await fetchWttrSnapshot(for: location)
        case .sevenTimer:
            return await fetchSevenTimerSnapshot(for: location)
        }
    }

    private func resolveLocationFromPreferredSources() async -> LocationMetadata? {
        if let systemLocation = await locationResolver?.resolveCurrentLocation() {
            return LocationMetadata(
                latitude: systemLocation.latitude,
                longitude: systemLocation.longitude,
                displayName: systemLocation.displayName
            )
        }

        return await resolveIPLocation()
    }

    private func fetchOpenMeteoSnapshot(for location: LocationMetadata) async -> WeatherSnapshot? {
        guard let url = openMeteoURL(latitude: location.latitude, longitude: location.longitude) else {
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
            hourlyForecasts: result.hourly?.forecasts ?? [],
            airQuality: airQuality,
            fetchedAt: now()
        )
        cachedSnapshot.value = snapshot
        return snapshot
    }

    private func fetchQWeatherSnapshot(for location: LocationMetadata, apiHost: String, apiKey: String) async -> WeatherSnapshot? {
        guard let nowURL = qWeatherURL(apiHost: apiHost, path: "/v7/weather/now", queryItems: [
            URLQueryItem(name: "location", value: qWeatherLocationValue(latitude: location.latitude, longitude: location.longitude)),
            URLQueryItem(name: "lang", value: AppLocalization.languageCode == "zh" ? "zh" : "en"),
            URLQueryItem(name: "unit", value: "m")
        ]),
            let dailyURL = qWeatherURL(apiHost: apiHost, path: "/v7/weather/15d", queryItems: [
                URLQueryItem(name: "location", value: qWeatherLocationValue(latitude: location.latitude, longitude: location.longitude)),
                URLQueryItem(name: "lang", value: AppLocalization.languageCode == "zh" ? "zh" : "en"),
                URLQueryItem(name: "unit", value: "m")
            ]) else {
            return nil
        }

        guard let nowResponse: QWeatherNowResponse = await fetchQWeather(from: nowURL, apiKey: apiKey),
              let dailyResponse: QWeatherDailyResponse = await fetchQWeather(from: dailyURL, apiKey: apiKey),
              nowResponse.code == "200",
              dailyResponse.code == "200",
              let current = nowResponse.now.toSnapshot() else {
            return nil
        }

        let airQuality = await fetchQWeatherAirQuality(
            latitude: location.latitude,
            longitude: location.longitude,
            apiHost: apiHost,
            apiKey: apiKey
        )
        let snapshot = WeatherSnapshot(
            locationName: location.displayName,
            current: current,
            dailyForecasts: dailyResponse.daily.compactMap(\.forecast),
            hourlyForecasts: [],
            airQuality: airQuality,
            fetchedAt: now()
        )
        cachedSnapshot.value = snapshot
        return snapshot
    }

    private func fetchWttrSnapshot(for location: LocationMetadata) async -> WeatherSnapshot? {
        guard let url = wttrURL(latitude: location.latitude, longitude: location.longitude) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let result = try JSONDecoder().decode(WttrResponse.self, from: data)
            guard let current = result.currentSnapshot else {
                return nil
            }

            let snapshot = WeatherSnapshot(
                locationName: location.displayName,
                current: current,
                dailyForecasts: result.dailyForecasts,
                hourlyForecasts: result.hourlyForecasts,
                airQuality: nil,
                fetchedAt: now()
            )
            cachedSnapshot.value = snapshot
            return snapshot
        } catch {
            return nil
        }
    }

    private func fetchSevenTimerSnapshot(for location: LocationMetadata) async -> WeatherSnapshot? {
        guard let url = sevenTimerURL(latitude: location.latitude, longitude: location.longitude) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let result = try JSONDecoder().decode(SevenTimerResponse.self, from: data)
            guard let current = result.currentSnapshot else {
                return nil
            }

            let snapshot = WeatherSnapshot(
                locationName: location.displayName,
                current: current,
                dailyForecasts: result.dailyForecasts,
                hourlyForecasts: [],
                airQuality: nil,
                fetchedAt: now()
            )
            cachedSnapshot.value = snapshot
            return snapshot
        } catch {
            return nil
        }
    }

    private func makeCurrentDescriptor(from snapshot: WeatherSnapshot) -> WeatherDescriptor {
        let airQuality = snapshot.airQuality?.current
        let weatherCode = supportedCurrentWeatherCode(from: snapshot)

        return WeatherDescriptor(
            locationName: snapshot.locationName,
            temperatureText: Self.formattedTemperature(snapshot.current.temperature),
            apparentTemperature: snapshot.current.apparentTemperature,
            forecastDate: nil,
            weatherCode: weatherCode,
            isDaytime: snapshot.current.isDaytime,
            isCurrentConditions: true,
            humidity: snapshot.current.humidity,
            precipitation: snapshot.current.precipitation,
            windSpeed: snapshot.current.windSpeed,
            windDirection: snapshot.current.windDirection,
            windGusts: snapshot.current.windGusts,
            cloudCover: snapshot.current.cloudCover,
            airQualityIndex: airQuality?.usAQI,
            pm25: airQuality?.pm25
        )
    }

    private func supportedCurrentWeatherCode(from snapshot: WeatherSnapshot) -> Int {
        guard Self.isThunderstormCode(snapshot.current.weatherCode), !snapshot.hourlyForecasts.isEmpty else {
            return snapshot.current.weatherCode
        }

        let currentTime = now()
        let windowEnd = currentTime.addingTimeInterval(3 * 60 * 60)
        let currentHourlyForecasts = snapshot.hourlyForecasts.filter { hourly in
            hourly.date >= currentTime && hourly.date <= windowEnd
        }
        let thunderstormHourlyForecasts = currentHourlyForecasts.filter { Self.isThunderstormCode($0.weatherCode) }
        let hasMeaningfulPrecipitation = Self.hasMeaningfulPrecipitation(
            hourlyForecasts: thunderstormHourlyForecasts,
            additionalAmounts: [snapshot.current.precipitation],
            additionalProbabilities: []
        )

        guard !hasMeaningfulPrecipitation else {
            return Self.normalizedSupportedThunderstormCode(snapshot.current.weatherCode)
        }

        return Self.fallbackNonThunderstormCode(
            from: currentHourlyForecasts,
            defaultCode: snapshot.current.weatherCode
        )
    }

    private func makeForecastDescriptor(
        from snapshot: WeatherSnapshot,
        forecast: DailyWeatherForecast,
        calendar: Calendar
    ) -> WeatherDescriptor {
        let weatherCode = supportedWeatherCode(from: snapshot, forecast: forecast, calendar: calendar)

        return makeForecastDescriptor(
            from: snapshot,
            forecast: forecast,
            calendar: calendar,
            weatherCode: weatherCode
        )
    }

    private func makeTodayForecastDescriptor(
        from snapshot: WeatherSnapshot,
        forecast: DailyWeatherForecast,
        calendar: Calendar
    ) -> WeatherDescriptor {
        let currentTime = now()
        let remainingHourlyForecasts = snapshot.hourlyForecasts.filter { hourly in
            hourly.date >= currentTime && calendar.isDate(hourly.date, inSameDayAs: forecast.date)
        }

        guard !remainingHourlyForecasts.isEmpty else {
            return makeForecastDescriptor(from: snapshot, forecast: forecast, calendar: calendar)
        }

        let thunderstormHourlyForecasts = remainingHourlyForecasts.filter { Self.isThunderstormCode($0.weatherCode) }
        let hasMeaningfulPrecipitation = Self.hasMeaningfulPrecipitation(
            hourlyForecasts: thunderstormHourlyForecasts,
            additionalAmounts: Self.isThunderstormCode(snapshot.current.weatherCode) ? [snapshot.current.precipitation] : [],
            additionalProbabilities: []
        )
        let weatherCode: Int
        if hasMeaningfulPrecipitation {
            let strongestThunderstormCode = thunderstormHourlyForecasts.max { lhs, rhs in
                Self.weatherSeverityRank(lhs.weatherCode) < Self.weatherSeverityRank(rhs.weatherCode)
            }?.weatherCode ?? forecast.weatherCode
            weatherCode = Self.normalizedSupportedThunderstormCode(strongestThunderstormCode)
        } else {
            weatherCode = Self.fallbackNonThunderstormCode(
                from: remainingHourlyForecasts,
                defaultCode: snapshot.current.weatherCode
            )
        }

        return makeForecastDescriptor(
            from: snapshot,
            forecast: forecast,
            calendar: calendar,
            weatherCode: weatherCode
        )
    }

    private func supportedWeatherCode(
        from snapshot: WeatherSnapshot,
        forecast: DailyWeatherForecast,
        calendar: Calendar
    ) -> Int {
        guard Self.isThunderstormCode(forecast.weatherCode), !snapshot.hourlyForecasts.isEmpty else {
            return forecast.weatherCode
        }

        let dayHourlyForecasts = snapshot.hourlyForecasts.filter { hourly in
            calendar.isDate(hourly.date, inSameDayAs: forecast.date)
        }
        let thunderstormHourlyForecasts = dayHourlyForecasts.filter { Self.isThunderstormCode($0.weatherCode) }
        let hasMeaningfulPrecipitation = Self.hasMeaningfulPrecipitation(
            hourlyForecasts: thunderstormHourlyForecasts,
            additionalAmounts: [],
            additionalProbabilities: []
        )

        guard !hasMeaningfulPrecipitation else {
            return Self.normalizedSupportedThunderstormCode(forecast.weatherCode)
        }

        return Self.fallbackNonThunderstormCode(from: dayHourlyForecasts, defaultCode: forecast.weatherCode)
    }

    private func makeForecastDescriptor(
        from snapshot: WeatherSnapshot,
        forecast: DailyWeatherForecast,
        calendar: Calendar,
        weatherCode: Int
    ) -> WeatherDescriptor {
        let airQuality = airQualitySummary(for: forecast.date, in: snapshot, calendar: calendar)

        return WeatherDescriptor(
            locationName: snapshot.locationName,
            temperatureText: "\(Self.formattedTemperature(forecast.maxTemperature)) / \(Self.formattedTemperature(forecast.minTemperature))",
            apparentTemperature: nil,
            forecastDate: forecast.date,
            weatherCode: weatherCode,
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

    private static func isThunderstormCode(_ code: Int) -> Bool {
        switch code {
        case 95, 96, 99:
            return true
        default:
            return false
        }
    }

    private static func hasMeaningfulPrecipitation(
        hourlyForecasts: [HourlyWeatherForecast],
        additionalAmounts: [Double?],
        additionalProbabilities: [Int?]
    ) -> Bool {
        let hourlyAmounts = hourlyForecasts.flatMap { hourly in
            [hourly.precipitation, hourly.rain, hourly.showers]
        }
        let hasAmount = (hourlyAmounts + additionalAmounts).contains { amount in
            (amount ?? 0) > 0.5
        }
        let maxProbability = (hourlyForecasts.map(\.precipitationProbability) + additionalProbabilities)
            .compactMap { $0 }
            .max() ?? 0

        return hasAmount || maxProbability >= 30
    }

    private static func fallbackNonThunderstormCode(
        from hourlyForecasts: [HourlyWeatherForecast],
        defaultCode: Int
    ) -> Int {
        if !isThunderstormCode(defaultCode) {
            return defaultCode
        }

        return hourlyForecasts
            .filter { !isThunderstormCode($0.weatherCode) }
            .max { lhs, rhs in
                weatherSeverityRank(lhs.weatherCode) < weatherSeverityRank(rhs.weatherCode)
            }?.weatherCode ?? 3
    }

    private static func normalizedSupportedThunderstormCode(_ code: Int) -> Int {
        isHailThunderstormCode(code) ? 95 : code
    }

    private static func isHailThunderstormCode(_ code: Int) -> Bool {
        code == 96 || code == 99
    }

    private static func weatherSeverityRank(_ code: Int) -> Int {
        switch code {
        case 95, 96, 99:
            return 9
        case 82:
            return 8
        case 65, 67, 81:
            return 7
        case 63, 80:
            return 6
        case 61, 66:
            return 5
        case 51, 53, 55, 56, 57:
            return 4
        case 71, 73, 75, 77, 85, 86:
            return 4
        case 45, 48:
            return 3
        case 3:
            return 2
        case 1, 2:
            return 1
        default:
            return 0
        }
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

    private func fetchQWeather<Response: Decodable>(from url: URL, apiKey: String) async -> Response? {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-QW-Api-Key")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            return nil
        }
    }

    private func fetchQWeatherAirQuality(
        latitude: Double,
        longitude: Double,
        apiHost: String,
        apiKey: String
    ) async -> AirQualitySnapshot? {
        let latitudeText = Self.formattedCoordinate(latitude)
        let longitudeText = Self.formattedCoordinate(longitude)
        guard let url = qWeatherURL(
            apiHost: apiHost,
            path: "/airquality/v1/current/\(latitudeText)/\(longitudeText)",
            queryItems: [URLQueryItem(name: "lang", value: AppLocalization.languageCode == "zh" ? "zh" : "en")]
        ) else {
            return nil
        }

        guard let response: QWeatherAirQualityResponse = await fetchQWeather(from: url, apiKey: apiKey) else {
            return nil
        }

        return response.toSnapshot()
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

    private func resolveIPLocation() async -> LocationMetadata? {
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

    private func qWeatherURL(apiHost: String, path: String, queryItems: [URLQueryItem]) -> URL? {
        let trimmedHost = apiHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/")
            .first
            .map(String.init) ?? ""
        guard !trimmedHost.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = trimmedHost
        components.path = path
        components.queryItems = queryItems
        return components.url
    }

    private func qWeatherLocationValue(latitude: Double, longitude: Double) -> String {
        "\(Self.formattedCoordinate(longitude)),\(Self.formattedCoordinate(latitude))"
    }

    private func wttrURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wttr.in"
        components.path = "/\(latitude),\(longitude)"
        components.queryItems = [
            URLQueryItem(name: "format", value: "j1"),
            URLQueryItem(name: "m", value: nil),
            URLQueryItem(name: "lang", value: AppLocalization.languageCode == "zh" ? "zh" : "en")
        ]
        return components.url
    }

    private func sevenTimerURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.7timer.info"
        components.path = "/bin/api.pl"
        components.queryItems = [
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "product", value: "civillight"),
            URLQueryItem(name: "output", value: "json")
        ]
        return components.url
    }

    private static func formattedCoordinate(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
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
            URLQueryItem(name: "hourly", value: "weather_code,precipitation,precipitation_probability,rain,showers"),
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
    let hourlyForecasts: [HourlyWeatherForecast]
    let airQuality: AirQualitySnapshot?
    let fetchedAt: Date
}

private struct WeatherSnapshotRequest: Sendable {
    let id: UUID
    let task: Task<WeatherSnapshot?, Never>
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
    let cloudCover: Int?
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

private struct HourlyWeatherForecast: Sendable {
    let date: Date
    let weatherCode: Int
    let precipitation: Double?
    let precipitationProbability: Int?
    let rain: Double?
    let showers: Double?
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

    func withValue<R>(_ update: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return update(&_value)
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
    let hourly: HourlyWeather?

    struct CurrentWeather: Decodable, Sendable {
        let temperature2m: Double
        let apparentTemperature: Double
        let relativeHumidity2m: Int?
        let precipitation: Double?
        let weatherCode: Int
        let windSpeed10m: Double?
        let windDirection10m: Double?
        let windGusts10m: Double?
        let cloudCover: Int?
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
            case cloudCover = "cloud_cover"
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
                windGusts: windGusts10m,
                cloudCover: cloudCover
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

    struct HourlyWeather: Decodable, Sendable {
        let time: [String]
        let weatherCode: [Int]
        let precipitation: [Double?]?
        let precipitationProbability: [Int?]?
        let rain: [Double?]?
        let showers: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case precipitation
            case precipitationProbability = "precipitation_probability"
            case rain
            case showers
        }

        var forecasts: [HourlyWeatherForecast] {
            let count = Swift.min(time.count, weatherCode.count)
            guard count > 0 else { return [] }

            return (0..<count).compactMap { index in
                guard let date = Self.dateFormatter.date(from: time[index]) else {
                    return nil
                }

                return HourlyWeatherForecast(
                    date: date,
                    weatherCode: weatherCode[index],
                    precipitation: Self.optionalValue(from: precipitation, at: index),
                    precipitationProbability: Self.optionalValue(from: precipitationProbability, at: index),
                    rain: Self.optionalValue(from: rain, at: index),
                    showers: Self.optionalValue(from: showers, at: index)
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

private struct WttrResponse: Decodable, Sendable {
    let currentCondition: [CurrentCondition]
    let weather: [WeatherDay]

    enum CodingKeys: String, CodingKey {
        case currentCondition = "current_condition"
        case weather
    }

    var currentSnapshot: CurrentWeatherSnapshot? {
        currentCondition.first?.snapshot
    }

    var dailyForecasts: [DailyWeatherForecast] {
        weather.compactMap(\.forecast)
    }

    var hourlyForecasts: [HourlyWeatherForecast] {
        weather.flatMap(\.hourlyForecasts)
    }

    struct CurrentCondition: Decodable, Sendable {
        let feelsLikeC: String
        let cloudCover: String?
        let humidity: String?
        let precipitationMM: String?
        let temperatureC: String
        let weatherCode: String
        let windDirectionDegree: String?
        let windSpeedKmph: String?

        enum CodingKeys: String, CodingKey {
            case feelsLikeC = "FeelsLikeC"
            case cloudCover = "cloudcover"
            case humidity
            case precipitationMM = "precipMM"
            case temperatureC = "temp_C"
            case weatherCode
            case windDirectionDegree = "winddirDegree"
            case windSpeedKmph = "windspeedKmph"
        }

        var snapshot: CurrentWeatherSnapshot? {
            guard let temperature = Double(temperatureC),
                  let apparentTemperature = Double(feelsLikeC) else {
                return nil
            }

            return CurrentWeatherSnapshot(
                temperature: temperature,
                apparentTemperature: apparentTemperature,
                weatherCode: WttrWeatherCodeMapper.weatherCode(for: weatherCode),
                isDaytime: true,
                humidity: humidity.flatMap(Int.init),
                precipitation: precipitationMM.flatMap(Double.init),
                windSpeed: windSpeedKmph.flatMap(Double.init),
                windDirection: windDirectionDegree.flatMap(Double.init),
                windGusts: nil,
                cloudCover: cloudCover.flatMap(Int.init)
            )
        }
    }

    struct WeatherDay: Decodable, Sendable {
        let date: String
        let maxTemperatureC: String
        let minTemperatureC: String
        let uvIndex: String?
        let hourly: [Hourly]

        enum CodingKeys: String, CodingKey {
            case date
            case maxTemperatureC = "maxtempC"
            case minTemperatureC = "mintempC"
            case uvIndex
            case hourly
        }

        var forecast: DailyWeatherForecast? {
            guard let date = Self.dateFormatter.date(from: date),
                  let maxTemperature = Double(maxTemperatureC),
                  let minTemperature = Double(minTemperatureC) else {
                return nil
            }

            let hourlyForecasts = hourly.compactMap { $0.forecast(on: date) }
            let weatherCode = hourlyForecasts.max { lhs, rhs in
                WttrWeatherCodeMapper.severityRank(lhs.weatherCode) < WttrWeatherCodeMapper.severityRank(rhs.weatherCode)
            }?.weatherCode ?? 3
            let precipitationValues = hourlyForecasts.compactMap(\.precipitation)
            let precipitationSum = precipitationValues.isEmpty ? nil : precipitationValues.reduce(0, +)
            let precipitationProbabilityMax = hourlyForecasts.compactMap(\.precipitationProbability).max()

            return DailyWeatherForecast(
                date: date,
                weatherCode: weatherCode,
                maxTemperature: maxTemperature,
                minTemperature: minTemperature,
                precipitationSum: precipitationSum,
                precipitationProbabilityMax: precipitationProbabilityMax,
                windSpeedMax: hourly.compactMap { $0.windSpeedKmph.flatMap(Double.init) }.max(),
                windDirectionDominant: hourly.first?.windDirectionDegree.flatMap(Double.init),
                windGustsMax: hourly.compactMap { $0.windGustKmph.flatMap(Double.init) }.max(),
                uvIndexMax: uvIndex.flatMap(Double.init)
            )
        }

        var hourlyForecasts: [HourlyWeatherForecast] {
            guard let date = Self.dateFormatter.date(from: date) else {
                return []
            }

            return hourly.compactMap { $0.forecast(on: date) }
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

    struct Hourly: Decodable, Sendable {
        let time: String
        let weatherCode: String
        let precipitationMM: String?
        let precipitationProbability: String?
        let windSpeedKmph: String?
        let windDirectionDegree: String?
        let windGustKmph: String?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode
            case precipitationMM = "precipMM"
            case precipitationProbability = "chanceofrain"
            case windSpeedKmph = "windspeedKmph"
            case windDirectionDegree = "winddirDegree"
            case windGustKmph = "WindGustKmph"
        }

        func forecast(on date: Date) -> HourlyWeatherForecast? {
            guard let rawTime = Int(time) else {
                return nil
            }

            let hour = rawTime / 100
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .autoupdatingCurrent
            guard let hourlyDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else {
                return nil
            }

            return HourlyWeatherForecast(
                date: hourlyDate,
                weatherCode: WttrWeatherCodeMapper.weatherCode(for: weatherCode),
                precipitation: precipitationMM.flatMap(Double.init),
                precipitationProbability: precipitationProbability.flatMap(Int.init),
                rain: nil,
                showers: nil
            )
        }
    }
}

private enum WttrWeatherCodeMapper {
    static func weatherCode(for code: String) -> Int {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "113":
            return 0
        case "116":
            return 2
        case "119", "122":
            return 3
        case "143", "248":
            return 45
        case "260":
            return 48
        case "176", "263", "266", "293", "296", "353":
            return 61
        case "299", "302", "305", "308", "356", "359":
            return 63
        case "281", "284":
            return 56
        case "311", "314", "317", "350", "362", "365":
            return 66
        case "179", "182", "185", "320", "323", "326", "368", "374", "377":
            return 71
        case "227", "230", "329", "332":
            return 73
        case "335", "338", "371":
            return 75
        case "200", "386", "389", "392", "395":
            return 95
        default:
            return 3
        }
    }

    static func severityRank(_ code: Int) -> Int {
        switch code {
        case 95, 96, 99:
            return 9
        case 82:
            return 8
        case 65, 67, 81:
            return 7
        case 63, 80:
            return 6
        case 61, 66:
            return 5
        case 51, 53, 55, 56, 57, 71, 73, 75, 77, 85, 86:
            return 4
        case 45, 48:
            return 3
        case 3:
            return 2
        case 1, 2:
            return 1
        default:
            return 0
        }
    }
}

private struct SevenTimerResponse: Decodable, Sendable {
    let product: String?
    let initTime: String?
    let dataseries: [DataPoint]

    enum CodingKeys: String, CodingKey {
        case product
        case initTime = "init"
        case dataseries
    }

    var currentSnapshot: CurrentWeatherSnapshot? {
        guard let today = dataseries.first else { return nil }
        return today.currentSnapshot
    }

    var dailyForecasts: [DailyWeatherForecast] {
        dataseries.compactMap(\.forecast)
    }

    struct DataPoint: Decodable, Sendable {
        let date: Int
        let weather: String
        let temperature2m: Temperature2m
        let wind10mMax: Int?

        enum CodingKeys: String, CodingKey {
            case date
            case weather
            case temperature2m = "temp2m"
            case wind10mMax = "wind10m_max"
        }

        var currentSnapshot: CurrentWeatherSnapshot? {
            CurrentWeatherSnapshot(
                temperature: Double(temperature2m.max),
                apparentTemperature: Double(temperature2m.max),
                weatherCode: SevenTimerWeatherCodeMapper.weatherCode(for: weather),
                isDaytime: true,
                humidity: nil,
                precipitation: nil,
                windSpeed: wind10mMax.map { Double($0) },
                windDirection: nil,
                windGusts: nil,
                cloudCover: nil
            )
        }

        var forecast: DailyWeatherForecast? {
            guard let date = Self.dateFormatter.date(from: String(date)) else {
                return nil
            }

            return DailyWeatherForecast(
                date: date,
                weatherCode: SevenTimerWeatherCodeMapper.weatherCode(for: weather),
                maxTemperature: Double(temperature2m.max),
                minTemperature: Double(temperature2m.min),
                precipitationSum: nil,
                precipitationProbabilityMax: SevenTimerWeatherCodeMapper.precipitationProbability(for: weather),
                windSpeedMax: wind10mMax.map { Double($0) },
                windDirectionDominant: nil,
                windGustsMax: nil,
                uvIndexMax: nil
            )
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .autoupdatingCurrent
            formatter.dateFormat = "yyyyMMdd"
            return formatter
        }()
    }

    struct Temperature2m: Decodable, Sendable {
        let max: Int
        let min: Int
    }
}

private enum SevenTimerWeatherCodeMapper {
    static func weatherCode(for weather: String) -> Int {
        switch normalized(weather) {
        case "clear":
            return 0
        case "pcloudy":
            return 2
        case "mcloudy", "cloudy", "humid":
            return 3
        case "fog":
            return 45
        case "lightrain", "oshower", "ishower":
            return 61
        case "rain":
            return 63
        case "lightsnow":
            return 71
        case "snow":
            return 73
        case "rainsnow":
            return 66
        case "ts", "tsrain":
            return 95
        default:
            return 3
        }
    }

    static func precipitationProbability(for weather: String) -> Int? {
        switch normalized(weather) {
        case "lightrain", "oshower", "ishower", "lightsnow", "rainsnow":
            return 50
        case "rain", "snow", "ts", "tsrain":
            return 80
        default:
            return nil
        }
    }

    private static func normalized(_ weather: String) -> String {
        weather.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

private struct QWeatherNowResponse: Decodable, Sendable {
    let code: String
    let now: Current

    struct Current: Decodable, Sendable {
        let temp: String
        let feelsLike: String?
        let icon: String
        let wind360: String?
        let windSpeed: String?
        let humidity: String?
        let precip: String?
        let cloud: String?

        func toSnapshot() -> CurrentWeatherSnapshot? {
            guard let temperature = Double(temp) else { return nil }

            return CurrentWeatherSnapshot(
                temperature: temperature,
                apparentTemperature: feelsLike.flatMap(Double.init) ?? temperature,
                weatherCode: QWeatherIconMapper.weatherCode(for: icon),
                isDaytime: QWeatherIconMapper.isDaytime(icon: icon),
                humidity: humidity.flatMap(Int.init),
                precipitation: precip.flatMap(Double.init),
                windSpeed: windSpeed.flatMap(Double.init),
                windDirection: wind360.flatMap(Double.init),
                windGusts: nil,
                cloudCover: cloud.flatMap(Int.init)
            )
        }
    }
}

private struct QWeatherDailyResponse: Decodable, Sendable {
    let code: String
    let daily: [Daily]

    struct Daily: Decodable, Sendable {
        let fxDate: String
        let tempMax: String
        let tempMin: String
        let iconDay: String
        let wind360Day: String?
        let windSpeedDay: String?
        let humidity: String?
        let precip: String?
        let cloud: String?
        let uvIndex: String?

        var forecast: DailyWeatherForecast? {
            guard let date = Self.dateFormatter.date(from: fxDate),
                  let maxTemperature = Double(tempMax),
                  let minTemperature = Double(tempMin) else {
                return nil
            }

            return DailyWeatherForecast(
                date: date,
                weatherCode: QWeatherIconMapper.weatherCode(for: iconDay),
                maxTemperature: maxTemperature,
                minTemperature: minTemperature,
                precipitationSum: precip.flatMap(Double.init),
                precipitationProbabilityMax: nil,
                windSpeedMax: windSpeedDay.flatMap(Double.init),
                windDirectionDominant: wind360Day.flatMap(Double.init),
                windGustsMax: nil,
                uvIndexMax: uvIndex.flatMap(Double.init)
            )
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

private struct QWeatherAirQualityResponse: Decodable, Sendable {
    let indexes: [Index]?
    let pollutants: [Pollutant]?

    func toSnapshot() -> AirQualitySnapshot? {
        let preferredIndex = indexes?.first { index in
            index.code.localizedCaseInsensitiveContains("cn")
        } ?? indexes?.first
        let pm25 = pollutants?.first { pollutant in
            pollutant.code == "pm2p5" || pollutant.code == "pm2_5"
        }?.concentration.value

        guard preferredIndex?.aqi != nil || pm25 != nil else {
            return nil
        }

        return AirQualitySnapshot(
            current: CurrentAirQualitySnapshot(
                usAQI: preferredIndex?.aqi.flatMap { Int($0.rounded()) },
                pm25: pm25
            ),
            hourlyForecasts: []
        )
    }

    struct Index: Decodable, Sendable {
        let code: String
        let aqi: Double?
    }

    struct Pollutant: Decodable, Sendable {
        let code: String
        let concentration: Concentration
    }

    struct Concentration: Decodable, Sendable {
        let value: Double
    }
}

private enum QWeatherIconMapper {
    static func weatherCode(for icon: String) -> Int {
        guard let code = Int(icon) else { return 3 }

        switch code {
        case 100, 150:
            return 0
        case 101, 102, 103, 151, 152, 153:
            return 2
        case 104, 154:
            return 3
        case 300...399:
            return 61
        case 400...499:
            return 71
        case 500...515:
            return 45
        default:
            return 3
        }
    }

    static func isDaytime(icon: String) -> Bool {
        guard let code = Int(icon) else { return true }
        return !(150...199).contains(code)
    }
}

final class CoreLocationWeatherLocationResolver: NSObject, WeatherLocationResolving, CLLocationManagerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<ResolvedWeatherLocation?, Never>?
    private var didFinish = false

    func resolveCurrentLocation() async -> ResolvedWeatherLocation? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.start(continuation: continuation)
            }
        }
    }

    private func start(continuation: CheckedContinuation<ResolvedWeatherLocation?, Never>) {
        lock.lock()
        if self.continuation != nil {
            lock.unlock()
            continuation.resume(returning: nil)
            return
        }
        self.continuation = continuation
        didFinish = false
        lock.unlock()

        guard CLLocationManager.locationServicesEnabled() else {
            finish(with: nil)
            return
        }

        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        self.manager = manager

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: nil)
        @unknown default:
            finish(with: nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.finish(with: nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: nil)
        case .notDetermined:
            break
        @unknown default:
            finish(with: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            finish(with: nil)
            return
        }

        finish(
            with: ResolvedWeatherLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                displayName: L("Current Location")
            )
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }

    private func finish(with location: ResolvedWeatherLocation?) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        let continuation = continuation
        self.continuation = nil
        manager?.delegate = nil
        manager = nil
        lock.unlock()

        continuation?.resume(returning: location)
    }
}
