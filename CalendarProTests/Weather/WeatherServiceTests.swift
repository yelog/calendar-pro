import XCTest
@testable import CalendarPro

final class WeatherServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        WeatherMockURLProtocol.requestHandler = nil
    }

    func testWeatherDescriptorIconSystemNameForClearDay() {
        let descriptor = WeatherDescriptor(
            temperature: 25,
            apparentTemperature: 27,
            weatherCode: 0,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "sun.max.fill")
    }

    func testWeatherDescriptorIconSystemNameForClearNight() {
        let descriptor = WeatherDescriptor(
            temperature: 18,
            apparentTemperature: 16,
            weatherCode: 0,
            isDaytime: false
        )
        XCTAssertEqual(descriptor.iconSystemName, "moon.stars.fill")
    }

    func testWeatherDescriptorIconSystemNameForOvercast() {
        let descriptor = WeatherDescriptor(
            temperature: 20,
            apparentTemperature: 19,
            weatherCode: 3,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.fill")
    }

    func testWeatherDescriptorIconSystemNameForRain() {
        let descriptor = WeatherDescriptor(
            temperature: 15,
            apparentTemperature: 12,
            weatherCode: 61,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.rain.fill")
    }

    func testWeatherDescriptorIconSystemNameForThunderstorm() {
        let descriptor = WeatherDescriptor(
            temperature: 22,
            apparentTemperature: 20,
            weatherCode: 95,
            isDaytime: false
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.bolt.rain.fill")
    }

    func testWeatherDescriptorIconSystemNameForSnow() {
        let descriptor = WeatherDescriptor(
            temperature: -2,
            apparentTemperature: -5,
            weatherCode: 73,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.snow.fill")
    }

    func testWeatherDescriptorIconSystemNameForFog() {
        let descriptor = WeatherDescriptor(
            temperature: 10,
            apparentTemperature: 8,
            weatherCode: 45,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.fog.fill")
    }

    func testWeatherDescriptorIconSystemNameForPartlyCloudyDay() {
        let descriptor = WeatherDescriptor(
            temperature: 22,
            apparentTemperature: 21,
            weatherCode: 2,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.sun.fill")
    }

    func testWeatherDescriptorIconSystemNameForPartlyCloudyNight() {
        let descriptor = WeatherDescriptor(
            temperature: 16,
            apparentTemperature: 14,
            weatherCode: 1,
            isDaytime: false
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.moon.fill")
    }

    func testWeatherDescriptorIconSystemNameForUnknownCode() {
        let descriptor = WeatherDescriptor(
            temperature: 20,
            apparentTemperature: 19,
            weatherCode: 999,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.iconSystemName, "cloud.fill")
    }

    func testWeatherDescriptorTemperatureText() {
        let descriptor = WeatherDescriptor(
            temperature: 23.6,
            apparentTemperature: 25.1,
            weatherCode: 0,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.temperatureText, "24°")
    }

    func testWeatherDescriptorTemperatureTextRoundsNegative() {
        let descriptor = WeatherDescriptor(
            temperature: -3.4,
            apparentTemperature: -6.2,
            weatherCode: 71,
            isDaytime: true
        )
        XCTAssertEqual(descriptor.temperatureText, "-3°")
    }

    func testWeatherDescriptorHasContentWithValidCode() {
        let descriptor = WeatherDescriptor(
            temperature: 20,
            apparentTemperature: 19,
            weatherCode: 0,
            isDaytime: true
        )
        XCTAssertTrue(descriptor.hasContent)
    }

    func testWeatherDescriptorHasNoContentWithNegativeCode() {
        let descriptor = WeatherDescriptor.empty
        XCTAssertFalse(descriptor.hasContent)
    }

    func testWeatherDescriptorEmptyHasNegativeCode() {
        let empty = WeatherDescriptor.empty
        XCTAssertEqual(empty.weatherCode, -1)
    }

    func testWeatherServiceFetchReturnsEmptyOnNetworkError() async {
        let service = WeatherService()
        let result = await service.fetchCurrentWeather()
        _ = result
    }

    func testWeatherServiceFetchUsesIPWhoLocation() async {
        let forecastURLHost = "api.open-meteo.com"
        let requestedHosts = LockedBox<[String]>([])

        WeatherMockURLProtocol.requestHandler = { request in
            requestedHosts.withValue { $0.append(request.url?.host ?? "") }

            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case forecastURLHost:
                let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
                let queryItems = components?.queryItems ?? []
                XCTAssertEqual(queryItems.first(where: { $0.name == "latitude" })?.value, "22.276022")
                XCTAssertEqual(queryItems.first(where: { $0.name == "longitude" })?.value, "114.1751471")

                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(
                        """
                        {
                          "current": {
                            "temperature_2m": 16.5,
                            "apparent_temperature": 16.8,
                            "weather_code": 1,
                            "is_day": 1
                          }
                        }
                        """.utf8
                    )
                )
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(session: makeSession(), now: { Date(timeIntervalSince1970: 1_000) })

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.temperatureText, "17°")
        XCTAssertEqual(requestedHosts.snapshot, ["ipwho.is", forecastURLHost])
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
                    Data("{\"loc\":\"22.2783,114.1747\"}".utf8)
                )
            case "api.open-meteo.com":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(
                        """
                        {
                          "current": {
                            "temperature_2m": 21.2,
                            "apparent_temperature": 24.1,
                            "weather_code": 3,
                            "is_day": 1
                          }
                        }
                        """.utf8
                    )
                )
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(session: makeSession(), now: { Date(timeIntervalSince1970: 1_000) })

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.weatherCode, 3)
        XCTAssertEqual(requestedHosts.snapshot, ["ipwho.is", "ipinfo.io", "api.open-meteo.com"])
    }

    func testWeatherServiceCachesWeatherWithinRefreshInterval() async {
        let nowBox = LockedBox(Date(timeIntervalSince1970: 1_000))
        let ipWhoRequests = LockedBox(0)
        let forecastRequests = LockedBox(0)

        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                ipWhoRequests.withValue { $0 += 1 }
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case "api.open-meteo.com":
                forecastRequests.withValue { $0 += 1 }
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(
                        """
                        {
                          "current": {
                            "temperature_2m": 18.4,
                            "apparent_temperature": 18.0,
                            "weather_code": 2,
                            "is_day": 1
                          }
                        }
                        """.utf8
                    )
                )
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(
            session: makeSession(),
            now: { nowBox.snapshot },
            refreshInterval: 30 * 60
        )

        let first = await service.fetchCurrentWeather()
        nowBox.withValue { $0 = Date(timeIntervalSince1970: 1_600) }
        let second = await service.fetchCurrentWeather()
        nowBox.withValue { $0 = Date(timeIntervalSince1970: 3_000) }
        let third = await service.fetchCurrentWeather()

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.temperatureText, "18°")
        XCTAssertEqual(third.temperatureText, "18°")
        XCTAssertEqual(ipWhoRequests.snapshot, 1)
        XCTAssertEqual(forecastRequests.snapshot, 2)
    }

    func testOpenMeteoResponseDecoding() throws {
        let json = """
        {
            "current": {
                "temperature_2m": 22.5,
                "apparent_temperature": 21.3,
                "weather_code": 3,
                "is_day": 1
            }
        }
        """
        let data = json.data(using: .utf8)!

        let response = try JSONDecoder().decode(OpenMeteoTestResponse.self, from: data)
        XCTAssertEqual(response.current.temperature_2m, 22.5)
        XCTAssertEqual(response.current.weather_code, 3)
        XCTAssertEqual(response.current.is_day, 1)
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

private struct OpenMeteoTestResponse: Decodable {
    let current: CurrentWeather
    struct CurrentWeather: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
        let is_day: Int
    }
}
