import XCTest
@testable import CalendarPro

final class WeatherServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        WeatherMockURLProtocol.requestHandler = nil
    }

    func testWeatherDescriptorIconSystemNameForClearDay() {
        XCTAssertEqual(makeDescriptor(weatherCode: 0, isDaytime: true).iconSystemName, "sun.max.fill")
    }

    func testWeatherDescriptorIconSystemNameForClearNight() {
        XCTAssertEqual(makeDescriptor(weatherCode: 0, isDaytime: false).iconSystemName, "moon.stars.fill")
    }

    func testWeatherDescriptorIconSystemNameForRain() {
        XCTAssertEqual(makeDescriptor(weatherCode: 61, isDaytime: true).iconSystemName, "cloud.rain.fill")
    }

    func testWeatherDescriptorHasContentWithLocationAndTemperature() {
        XCTAssertTrue(makeDescriptor(weatherCode: 3, isDaytime: true).hasContent)
    }

    func testWeatherDescriptorEmptyHasNoContent() {
        XCTAssertFalse(WeatherDescriptor.empty.hasContent)
    }

    func testWeatherServiceFetchCurrentWeatherUsesIPWhoLocation() async {
        let requestedHosts = LockedBox<[String]>([])

        WeatherMockURLProtocol.requestHandler = { request in
            requestedHosts.withValue { $0.append(request.url?.host ?? "") }

            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Hong Kong\",\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case "api.open-meteo.com":
                let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
                let queryItems = components?.queryItems ?? []
                XCTAssertEqual(queryItems.first(where: { $0.name == "latitude" })?.value, "22.276022")
                XCTAssertEqual(queryItems.first(where: { $0.name == "longitude" })?.value, "114.1751471")
                XCTAssertEqual(queryItems.first(where: { $0.name == "daily" })?.value, "weather_code,temperature_2m_max,temperature_2m_min")
                XCTAssertEqual(queryItems.first(where: { $0.name == "past_days" })?.value, "31")
                XCTAssertEqual(queryItems.first(where: { $0.name == "forecast_days" })?.value, "16")

                return makeForecastResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) })

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.locationName, "Hong Kong")
        XCTAssertEqual(result.temperatureText, "26°")
        XCTAssertEqual(result.apparentTemperature, 31)
        XCTAssertTrue(result.isCurrentConditions)
        XCTAssertNil(result.forecastDate)
        XCTAssertEqual(requestedHosts.snapshot, ["ipwho.is", "api.open-meteo.com"])
    }

    func testWeatherServiceDescribeFutureDateUsesDailyForecast() async {
        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Hong Kong\",\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case "api.open-meteo.com":
                return makeForecastResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let calendar = makeCalendar()
        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) })
        let selectedDate = makeDate(year: 2026, month: 4, day: 24)

        let result = await service.describe(date: selectedDate, calendar: calendar)

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.locationName, "Hong Kong")
        XCTAssertEqual(result.temperatureText, "27° / 20°")
        XCTAssertNil(result.apparentTemperature)
        XCTAssertFalse(result.isCurrentConditions)
        XCTAssertTrue(calendar.isDate(result.forecastDate ?? .distantPast, inSameDayAs: selectedDate))
        XCTAssertEqual(result.iconSystemName, "cloud.fill")
    }

    func testWeatherServiceFallsBackToIPInfoWhenPrimaryLocationProviderFails() async {
        let requestedHosts = LockedBox<[String]>([])

        WeatherMockURLProtocol.requestHandler = { request in
            requestedHosts.withValue { $0.append(request.url?.host ?? "") }

            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":false}".utf8)
                )
            case "ipinfo.io":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"city\":\"Hong Kong\",\"region\":\"Hong Kong\",\"country\":\"HK\",\"loc\":\"22.2783,114.1747\"}".utf8)
                )
            case "api.open-meteo.com":
                return makeForecastResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) })

        let result = await service.fetchCurrentWeather()

        XCTAssertEqual(result.locationName, "Hong Kong")
        XCTAssertEqual(requestedHosts.snapshot, ["ipwho.is", "ipinfo.io", "api.open-meteo.com"])
    }

    func testWeatherServiceCachesSnapshotWithinRefreshIntervalAcrossDateSelections() async {
        let nowBox = LockedBox(makeDate(year: 2026, month: 4, day: 23, hour: 10))
        let ipWhoRequests = LockedBox(0)
        let forecastRequests = LockedBox(0)

        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                ipWhoRequests.withValue { $0 += 1 }
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Hong Kong\",\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case "api.open-meteo.com":
                forecastRequests.withValue { $0 += 1 }
                return makeForecastResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let calendar = makeCalendar()
        let service = WeatherService(
            session: makeSession(),
            now: { nowBox.snapshot },
            refreshInterval: 30 * 60
        )

        let first = await service.describe(date: makeDate(year: 2026, month: 4, day: 23), calendar: calendar)
        let second = await service.describe(date: makeDate(year: 2026, month: 4, day: 24), calendar: calendar)
        nowBox.withValue { $0 = makeDate(year: 2026, month: 4, day: 23, hour: 10, minute: 31) }
        let third = await service.describe(date: makeDate(year: 2026, month: 4, day: 25), calendar: calendar)

        XCTAssertEqual(first.locationName, "Hong Kong")
        XCTAssertEqual(second.locationName, "Hong Kong")
        XCTAssertEqual(third.locationName, "Hong Kong")
        XCTAssertEqual(ipWhoRequests.snapshot, 1)
        XCTAssertEqual(forecastRequests.snapshot, 2)
    }

    func testWeatherServiceReturnsEmptyWhenSelectedForecastDateIsUnavailable() async {
        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Hong Kong\",\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case "api.open-meteo.com":
                return makeForecastResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) })
        let result = await service.describe(date: makeDate(year: 2026, month: 7, day: 1), calendar: makeCalendar())

        XCTAssertEqual(result, .empty)
    }

    func testWeatherServiceFetchReturnsEmptyOnNetworkError() async {
        let service = WeatherService()
        let result = await service.fetchCurrentWeather()
        XCTAssertFalse(result.hasContent)
    }
}

private final class LockedBox<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    var snapshot: Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func withValue<T>(_ update: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return update(&value)
    }
}

private final class WeatherMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WeatherMockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func makeDescriptor(weatherCode: Int, isDaytime: Bool) -> WeatherDescriptor {
    WeatherDescriptor(
        locationName: "Hong Kong",
        temperatureText: "20°",
        apparentTemperature: 22,
        forecastDate: nil,
        weatherCode: weatherCode,
        isDaytime: isDaytime,
        isCurrentConditions: true
    )
}

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    let calendar = makeCalendar()
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func makeForecastResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let data = Data(
        """
        {
          "current": {
            "temperature_2m": 26.0,
            "apparent_temperature": 31.0,
            "weather_code": 61,
            "is_day": 1
          },
          "daily": {
            "time": ["2026-04-22", "2026-04-23", "2026-04-24", "2026-04-25"],
            "weather_code": [45, 61, 3, 0],
            "temperature_2m_max": [24.0, 28.0, 27.0, 30.0],
            "temperature_2m_min": [19.0, 24.0, 20.0, 25.0]
          }
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}
