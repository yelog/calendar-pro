import XCTest
@testable import CalendarPro

final class WeatherServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        WeatherMockURLProtocol.requestHandler = nil
        StallingWeatherURLProtocol.mode = .stall
        StallingWeatherURLProtocol.onStalledRequest = nil
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
                XCTAssertEqual(queryItems.first(where: { $0.name == "current" })?.value, "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,is_day")
                XCTAssertEqual(queryItems.first(where: { $0.name == "hourly" })?.value, "weather_code,precipitation,precipitation_probability,rain,showers")
                XCTAssertEqual(queryItems.first(where: { $0.name == "daily" })?.value, "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant,wind_gusts_10m_max,uv_index_max")
                XCTAssertEqual(queryItems.first(where: { $0.name == "past_days" })?.value, "31")
                XCTAssertEqual(queryItems.first(where: { $0.name == "forecast_days" })?.value, "16")

                return makeForecastResponse(for: request.url!)
            case "air-quality-api.open-meteo.com":
                let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
                let queryItems = components?.queryItems ?? []
                XCTAssertEqual(queryItems.first(where: { $0.name == "current" })?.value, "us_aqi,pm2_5")
                XCTAssertEqual(queryItems.first(where: { $0.name == "hourly" })?.value, "us_aqi,pm2_5")
                XCTAssertEqual(queryItems.first(where: { $0.name == "forecast_days" })?.value, "7")
                return makeAirQualityResponse(for: request.url!)
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
        XCTAssertEqual(result.humidity, 82)
        XCTAssertEqual(result.precipitation, 0.4)
        XCTAssertEqual(result.windSpeed, 12.4)
        XCTAssertEqual(result.windDirection, 45)
        XCTAssertEqual(result.windGusts, 22.0)
        XCTAssertEqual(result.cloudCover, 68)
        XCTAssertEqual(result.airQualityIndex, 42)
        XCTAssertEqual(result.pm25, 9.6)
        XCTAssertTrue(result.isCurrentConditions)
        XCTAssertNil(result.forecastDate)
        XCTAssertEqual(requestedHosts.snapshot, ["ipwho.is", "api.open-meteo.com", "air-quality-api.open-meteo.com"])
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
            case "air-quality-api.open-meteo.com":
                return makeAirQualityResponse(for: request.url!)
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
        XCTAssertEqual(result.precipitation, 2.4)
        XCTAssertEqual(result.precipitationProbability, 60)
        XCTAssertEqual(result.windSpeed, 18.0)
        XCTAssertEqual(result.windDirection, 135)
        XCTAssertEqual(result.windGusts, 31.0)
        XCTAssertEqual(result.airQualityIndex, 72)
        XCTAssertEqual(result.pm25, 17.0)
        XCTAssertEqual(result.uvIndex, 8.0)
        XCTAssertFalse(result.isCurrentConditions)
        XCTAssertTrue(calendar.isDate(result.forecastDate ?? .distantPast, inSameDayAs: selectedDate))
        XCTAssertEqual(result.iconSystemName, "cloud.fill")
    }

    func testWeatherServiceForecastOverviewReturnsTenDayForecastStartingToday() async {
        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Hong Kong\",\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case "api.open-meteo.com":
                return makeTenDayForecastResponse(for: request.url!)
            case "air-quality-api.open-meteo.com":
                return makeAirQualityResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let calendar = makeCalendar()
        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) })

        let overview = await service.forecastOverview(days: 10, calendar: calendar)

        XCTAssertTrue(overview.hasContent)
        XCTAssertEqual(overview.current.locationName, "Hong Kong")
        XCTAssertEqual(overview.current.temperatureText, "26°")
        XCTAssertEqual(overview.dailyForecasts.count, 10)
        XCTAssertTrue(calendar.isDate(overview.dailyForecasts[0].forecastDate ?? .distantPast, inSameDayAs: makeDate(year: 2026, month: 4, day: 23)))
        XCTAssertEqual(overview.dailyForecasts[0].temperatureText, "28° / 24°")
        XCTAssertEqual(overview.dailyForecasts[0].precipitationProbability, 25)
        XCTAssertTrue(calendar.isDate(overview.dailyForecasts[9].forecastDate ?? .distantPast, inSameDayAs: makeDate(year: 2026, month: 5, day: 2)))
        XCTAssertEqual(overview.dailyForecasts[9].temperatureText, "37° / 33°")
        XCTAssertEqual(overview.dailyForecasts[9].precipitationProbability, 70)
        XCTAssertEqual(overview.dailyForecasts[9].windSpeed, 25)
    }

    func testWeatherServiceForecastOverviewSynthesizesTodayFromRemainingOpenMeteoHourlyData() async {
        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Shenzhen\",\"latitude\":22.538,\"longitude\":113.9389}".utf8)
                )
            case "api.open-meteo.com":
                return makeDailyThunderstormHourlyDryResponse(for: request.url!)
            case "air-quality-api.open-meteo.com":
                return makeAirQualityResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let calendar = makeCalendar()
        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 6, day: 22, hour: 10) })

        let overview = await service.forecastOverview(days: 10, calendar: calendar)

        XCTAssertEqual(overview.current.weatherCode, 3)
        XCTAssertEqual(overview.current.temperatureText, "31°")

        XCTAssertEqual(overview.dailyForecasts.first?.weatherCode, 3)
        XCTAssertEqual(overview.dailyForecasts.first?.temperatureText, "33° / 27°")
        XCTAssertEqual(overview.dailyForecasts.first?.precipitation, 0)
        XCTAssertEqual(overview.dailyForecasts.first?.precipitationProbability, 0)

        XCTAssertEqual(overview.dailyForecasts.dropFirst().first?.weatherCode, 3)
        XCTAssertEqual(overview.dailyForecasts.dropFirst().first?.temperatureText, "32° / 26°")
        XCTAssertEqual(overview.dailyForecasts.dropFirst().first?.precipitation, 0.2)
        XCTAssertEqual(overview.dailyForecasts.dropFirst().first?.precipitationProbability, 14)
    }

    func testWeatherServiceDescribeFiltersUnsupportedCurrentOpenMeteoThunderstorm() async {
        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Shenzhen\",\"latitude\":22.538,\"longitude\":113.9389}".utf8)
                )
            case "api.open-meteo.com":
                return makeDailyThunderstormHourlyDryResponse(for: request.url!)
            case "air-quality-api.open-meteo.com":
                return makeAirQualityResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let calendar = makeCalendar()
        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 6, day: 22, hour: 10) })

        let result = await service.describe(date: makeDate(year: 2026, month: 6, day: 22, hour: 10), calendar: calendar)

        XCTAssertEqual(result.weatherCode, 3)
        XCTAssertEqual(result.iconSystemName, "cloud.fill")
        XCTAssertEqual(result.temperatureText, "31°")
        XCTAssertEqual(result.precipitation, 0)
        XCTAssertTrue(result.isCurrentConditions)
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
            case "air-quality-api.open-meteo.com":
                return makeAirQualityResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) })

        let result = await service.fetchCurrentWeather()

        XCTAssertEqual(result.locationName, "Hong Kong")
        XCTAssertEqual(requestedHosts.snapshot, ["ipwho.is", "ipinfo.io", "api.open-meteo.com", "air-quality-api.open-meteo.com"])
    }

    func testWeatherServiceReturnsWeatherWhenAirQualityFetchFails() async {
        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "ipwho.is":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data("{\"success\":true,\"city\":\"Hong Kong\",\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
                )
            case "api.open-meteo.com":
                return makeForecastResponse(for: request.url!)
            case "air-quality-api.open-meteo.com":
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                    Data("{}".utf8)
                )
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(session: makeSession(), now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) })

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.temperatureText, "26°")
        XCTAssertNil(result.airQualityIndex)
        XCTAssertNil(result.pm25)
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

    func testWeatherServiceDeduplicatesInFlightSnapshotFetches() async {
        let ipWhoRequests = LockedBox(0)
        let forecastRequests = LockedBox(0)
        let airQualityRequests = LockedBox(0)

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
                Thread.sleep(forTimeInterval: 0.12)
                return makeForecastResponse(for: request.url!)
            case "air-quality-api.open-meteo.com":
                airQualityRequests.withValue { $0 += 1 }
                return makeAirQualityResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let calendar = makeCalendar()
        let service = WeatherService(
            session: makeSession(),
            now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) }
        )

        async let first = service.fetchCurrentWeather()
        async let second = service.describe(
            date: makeDate(year: 2026, month: 4, day: 24),
            calendar: calendar
        )
        _ = await (first, second)

        XCTAssertEqual(ipWhoRequests.snapshot, 1)
        XCTAssertEqual(forecastRequests.snapshot, 1)
        XCTAssertEqual(airQualityRequests.snapshot, 1)
    }

    func testWeatherServiceCancelsInFlightSnapshotBeforeRetrying() async {
        let firstRequestStarted = expectation(description: "first request started")
        StallingWeatherURLProtocol.mode = .stall
        StallingWeatherURLProtocol.onStalledRequest = { _ in
            firstRequestStarted.fulfill()
        }

        let service = WeatherService(
            session: makeStallingSession(),
            now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) }
        )
        let stalledTask = Task { await service.fetchCurrentWeather() }

        await fulfillment(of: [firstRequestStarted], timeout: 1.0)
        service.cancelInFlightSnapshot()
        StallingWeatherURLProtocol.mode = .success

        let result = await service.fetchCurrentWeather()

        stalledTask.cancel()
        _ = await stalledTask.value
        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.locationName, "Hong Kong")
        XCTAssertEqual(result.temperatureText, "26°")
    }

    func testWeatherServiceFetchReturnsEmptyOnNetworkError() async {
        let service = WeatherService(session: makeSession())
        let result = await service.fetchCurrentWeather()
        XCTAssertFalse(result.hasContent)
    }

    func testWeatherServiceUsesManualLocationSkippingIPGeolocation() async {
        let requestedHosts = LockedBox<[String]>([])

        WeatherMockURLProtocol.requestHandler = { request in
            requestedHosts.withValue { $0.append(request.url?.host ?? "") }

            switch request.url?.host {
            case "api.open-meteo.com":
                return makeForecastResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let manualLocation = WeatherLocation(
            latitude: 39.9042,
            longitude: 116.4074,
            name: "Beijing",
            country: "China",
            admin1: "Beijing"
        )

        let service = WeatherService(
            session: makeSession(),
            now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) },
            manualLocation: manualLocation
        )

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.locationName, "Beijing")
        XCTAssertEqual(requestedHosts.snapshot, ["api.open-meteo.com", "air-quality-api.open-meteo.com"])
    }

    func testWeatherServiceManualLocationDescriptorContainsLocationName() async {
        WeatherMockURLProtocol.requestHandler = { request in
            switch request.url?.host {
            case "api.open-meteo.com":
                return makeForecastResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let manualLocation = WeatherLocation(
            latitude: 35.6762,
            longitude: 139.6503,
            name: "Tokyo",
            country: "Japan",
            admin1: "Tokyo"
        )

        let service = WeatherService(
            session: makeSession(),
            now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) },
            manualLocation: manualLocation
        )

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.locationName, "Tokyo")
    }

    func testWeatherServiceUsesInjectedSystemLocationBeforeIPFallback() async {
        let requestedHosts = LockedBox<[String]>([])

        WeatherMockURLProtocol.requestHandler = { request in
            requestedHosts.withValue { $0.append(request.url?.host ?? "") }

            switch request.url?.host {
            case "api.open-meteo.com":
                let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
                let queryItems = components?.queryItems ?? []
                XCTAssertEqual(queryItems.first(where: { $0.name == "latitude" })?.value, "24.47979")
                XCTAssertEqual(queryItems.first(where: { $0.name == "longitude" })?.value, "118.08187")
                return makeForecastResponse(for: request.url!)
            case "air-quality-api.open-meteo.com":
                return makeAirQualityResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(
            session: makeSession(),
            now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) },
            locationResolver: StaticWeatherLocationResolver(
                location: ResolvedWeatherLocation(
                    latitude: 24.47979,
                    longitude: 118.08187,
                    displayName: "当前位置"
                )
            )
        )

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.locationName, "当前位置")
        XCTAssertEqual(requestedHosts.snapshot, ["api.open-meteo.com", "air-quality-api.open-meteo.com"])
    }

    func testQWeatherProviderUsesConfiguredHostAndAPIKeyWithLocalAirQuality() async {
        let requestedPaths = LockedBox<[String]>([])
        let requestedAPIKeys = LockedBox<[String?]>([])

        WeatherMockURLProtocol.requestHandler = { request in
            requestedPaths.withValue { $0.append(request.url?.path ?? "") }
            requestedAPIKeys.withValue { $0.append(request.value(forHTTPHeaderField: "X-QW-Api-Key")) }

            switch request.url?.path {
            case "/v7/weather/now":
                return makeQWeatherNowResponse(for: request.url!)
            case "/v7/weather/15d":
                return makeQWeatherDailyResponse(for: request.url!)
            case "/airquality/v1/current/39.90/116.41":
                return makeQWeatherAirQualityResponse(for: request.url!)
            default:
                throw URLError(.badURL)
            }
        }

        let service = WeatherService(
            session: makeSession(),
            now: { makeDate(year: 2026, month: 4, day: 23, hour: 10) },
            manualLocation: WeatherLocation(
                latitude: 39.9042,
                longitude: 116.4074,
                name: "北京",
                country: "中国",
                admin1: "北京市"
            ),
            providerConfiguration: .qWeather(
                apiHost: "abc1234xyz.def.qweatherapi.com",
                apiKey: "test-key"
            )
        )

        let result = await service.fetchCurrentWeather()

        XCTAssertTrue(result.hasContent)
        XCTAssertEqual(result.locationName, "北京")
        XCTAssertEqual(result.temperatureText, "24°")
        XCTAssertEqual(result.apparentTemperature, 26)
        XCTAssertEqual(result.humidity, 72)
        XCTAssertEqual(result.precipitation, 0)
        XCTAssertEqual(result.windSpeed, 3)
        XCTAssertEqual(result.windDirection, 123)
        XCTAssertEqual(result.cloudCover, 10)
        XCTAssertEqual(result.airQualityIndex, 68)
        XCTAssertEqual(result.pm25, 24)
        XCTAssertEqual(requestedPaths.snapshot, [
            "/v7/weather/now",
            "/v7/weather/15d",
            "/airquality/v1/current/39.90/116.41"
        ])
        XCTAssertEqual(requestedAPIKeys.snapshot, ["test-key", "test-key", "test-key"])
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

private final class StallingWeatherURLProtocol: URLProtocol {
    enum Mode {
        case stall
        case success
    }

    nonisolated(unsafe) static var mode: Mode = .stall
    nonisolated(unsafe) static var onStalledRequest: (@Sendable (URLRequest) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        switch Self.mode {
        case .stall:
            Self.onStalledRequest?(request)
        case .success:
            do {
                let (response, data) = try Self.successResponse(for: request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}

    private static func successResponse(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        switch request.url?.host {
        case "ipwho.is":
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{\"success\":true,\"city\":\"Hong Kong\",\"latitude\":22.276022,\"longitude\":114.1751471}".utf8)
            )
        case "api.open-meteo.com":
            return makeForecastResponse(for: request.url!)
        case "air-quality-api.open-meteo.com":
            return makeAirQualityResponse(for: request.url!)
        default:
            throw URLError(.badURL)
        }
    }
}

private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [WeatherMockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func makeStallingSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StallingWeatherURLProtocol.self]
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
    calendar.timeZone = .autoupdatingCurrent
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
            "relative_humidity_2m": 82,
            "precipitation": 0.4,
            "weather_code": 61,
            "wind_speed_10m": 12.4,
            "wind_direction_10m": 45.0,
            "wind_gusts_10m": 22.0,
            "cloud_cover": 68,
            "is_day": 1
          },
          "daily": {
            "time": ["2026-04-22", "2026-04-23", "2026-04-24", "2026-04-25"],
            "weather_code": [45, 61, 3, 0],
            "temperature_2m_max": [24.0, 28.0, 27.0, 30.0],
            "temperature_2m_min": [19.0, 24.0, 20.0, 25.0],
            "precipitation_sum": [0.0, 0.4, 2.4, 0.0],
            "precipitation_probability_max": [10, 30, 60, 5],
            "wind_speed_10m_max": [11.0, 16.0, 18.0, 9.0],
            "wind_direction_10m_dominant": [30.0, 45.0, 135.0, 210.0],
            "wind_gusts_10m_max": [18.0, 22.0, 31.0, 14.0],
            "uv_index_max": [6.0, 7.0, 8.0, 9.0]
          }
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}

private func makeAirQualityResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let data = Data(
        """
        {
          "current": {
            "us_aqi": 42,
            "pm2_5": 9.6
          },
          "hourly": {
            "time": [
              "2026-04-23T00:00",
              "2026-04-23T12:00",
              "2026-04-24T00:00",
              "2026-04-24T12:00",
              "2026-04-24T18:00"
            ],
            "us_aqi": [40, 42, 65, 72, 70],
            "pm2_5": [9.0, 9.6, 16.0, 18.0, 17.0]
          }
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}

private func makeTenDayForecastResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let startDate = makeDate(year: 2026, month: 4, day: 22)
    let calendar = makeCalendar()
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"

    let dates = (0..<12).map { offset in
        formatter.string(from: calendar.date(byAdding: .day, value: offset, to: startDate)!)
    }
    let weatherCodes = [45, 61, 3, 0, 1, 2, 61, 80, 3, 0, 1, 2]
    let maxTemperatures = (0..<12).map { 27.0 + Double($0) }
    let minTemperatures = (0..<12).map { 23.0 + Double($0) }
    let precipitation = (0..<12).map { Double($0) * 0.2 }
    let precipitationProbability = (0..<12).map { 20 + ($0 * 5) }
    let windSpeed = (0..<12).map { 15.0 + Double($0) }
    let windDirection = (0..<12).map { 45.0 + Double($0 * 15) }
    let windGusts = (0..<12).map { 22.0 + Double($0) }
    let uvIndex = (0..<12).map { 3.0 + Double($0 % 6) }

    let data = Data(
        """
        {
          "current": {
            "temperature_2m": 26.0,
            "apparent_temperature": 31.0,
            "relative_humidity_2m": 82,
            "precipitation": 0.4,
            "weather_code": 61,
            "wind_speed_10m": 12.4,
            "wind_direction_10m": 45.0,
            "wind_gusts_10m": 22.0,
            "cloud_cover": 68,
            "is_day": 1
          },
          "daily": {
            "time": \(jsonArray(dates)),
            "weather_code": \(jsonArray(weatherCodes)),
            "temperature_2m_max": \(jsonArray(maxTemperatures)),
            "temperature_2m_min": \(jsonArray(minTemperatures)),
            "precipitation_sum": \(jsonArray(precipitation)),
            "precipitation_probability_max": \(jsonArray(precipitationProbability)),
            "wind_speed_10m_max": \(jsonArray(windSpeed)),
            "wind_direction_10m_dominant": \(jsonArray(windDirection)),
            "wind_gusts_10m_max": \(jsonArray(windGusts)),
            "uv_index_max": \(jsonArray(uvIndex))
          }
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}

private func makeDailyThunderstormHourlyDryResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let data = Data(
        """
        {
          "current": {
            "temperature_2m": 31.0,
            "apparent_temperature": 36.0,
            "relative_humidity_2m": 72,
            "precipitation": 0.0,
            "weather_code": 95,
            "wind_speed_10m": 10.0,
            "wind_direction_10m": 120.0,
            "wind_gusts_10m": 18.0,
            "cloud_cover": 55,
            "is_day": 1
          },
          "hourly": {
            "time": ["2026-06-22T09:00", "2026-06-22T10:00", "2026-06-22T11:00", "2026-06-22T12:00", "2026-06-22T13:00", "2026-06-23T09:00", "2026-06-23T10:00", "2026-06-23T11:00"],
            "weather_code": [95, 95, 95, 3, 2, 3, 3, 2],
            "precipitation": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            "precipitation_probability": [0, 0, 0, 0, 0, 14, 10, 8],
            "rain": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            "showers": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
          },
          "daily": {
            "time": ["2026-06-22", "2026-06-23"],
            "weather_code": [95, 96],
            "temperature_2m_max": [33.0, 32.0],
            "temperature_2m_min": [27.0, 26.0],
            "precipitation_sum": [0.0, 0.2],
            "precipitation_probability_max": [0, 14],
            "wind_speed_10m_max": [16.0, 14.0],
            "wind_direction_10m_dominant": [135.0, 120.0],
            "wind_gusts_10m_max": [24.0, 20.0],
            "uv_index_max": [8.0, 7.0]
          }
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}

private func jsonArray<T: Encodable>(_ value: T) -> String {
    String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
}

private struct StaticWeatherLocationResolver: WeatherLocationResolving {
    let location: ResolvedWeatherLocation?

    func resolveCurrentLocation() async -> ResolvedWeatherLocation? {
        location
    }
}

private func makeQWeatherNowResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let data = Data(
        """
        {
          "code": "200",
          "now": {
            "obsTime": "2026-04-23T10:00+08:00",
            "temp": "24",
            "feelsLike": "26",
            "icon": "305",
            "text": "小雨",
            "wind360": "123",
            "windDir": "东南风",
            "windScale": "1",
            "windSpeed": "3",
            "humidity": "72",
            "precip": "0.0",
            "pressure": "1003",
            "vis": "16",
            "cloud": "10"
          }
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}

private func makeQWeatherDailyResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let data = Data(
        """
        {
          "code": "200",
          "daily": [
            {
              "fxDate": "2026-04-23",
              "tempMax": "26",
              "tempMin": "18",
              "iconDay": "305",
              "textDay": "小雨",
              "wind360Day": "123",
              "windSpeedDay": "8",
              "humidity": "72",
              "precip": "0.0",
              "cloud": "10",
              "uvIndex": "3"
            },
            {
              "fxDate": "2026-04-24",
              "tempMax": "28",
              "tempMin": "19",
              "iconDay": "101",
              "textDay": "多云",
              "wind360Day": "90",
              "windSpeedDay": "12",
              "humidity": "70",
              "precip": "1.0",
              "cloud": "30",
              "uvIndex": "6"
            }
          ]
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}

private func makeQWeatherAirQualityResponse(for url: URL) -> (HTTPURLResponse, Data) {
    let data = Data(
        """
        {
          "indexes": [
            {
              "code": "cn-mee",
              "name": "AQI",
              "aqi": 68,
              "aqiDisplay": "68",
              "level": "2",
              "category": "良"
            },
            {
              "code": "us-epa",
              "name": "AQI (US)",
              "aqi": 55,
              "aqiDisplay": "55",
              "level": "2",
              "category": "Moderate"
            }
          ],
          "pollutants": [
            {
              "code": "pm2p5",
              "name": "PM 2.5",
              "concentration": {
                "value": 24.0,
                "unit": "μg/m3"
              }
            }
          ]
        }
        """.utf8
    )

    return (
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        data
    )
}
