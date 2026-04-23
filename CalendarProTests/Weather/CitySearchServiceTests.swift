import XCTest
@testable import CalendarPro

final class CitySearchServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        CitySearchMockURLProtocol.requestHandler = nil
    }

    func testSearchReturnsResultsFromAPI() async {
        CitySearchMockURLProtocol.requestHandler = { request in
            let data = Data("""
            {
              "results": [
                {
                  "id": 1816670,
                  "name": "Beijing",
                  "country": "China",
                  "admin1": "Beijing",
                  "latitude": 39.9075,
                  "longitude": 116.3972
                },
                {
                  "id": 1815628,
                  "name": "Beijing",
                  "country": "China",
                  "admin1": "Jiangxi",
                  "latitude": 27.85,
                  "longitude": 115.0,
                  "population": 26564
                }
              ]
            }
            """.utf8)

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let service = CitySearchService(session: makeSession())
        let results = await service.search(query: "Beijing")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "Beijing")
        XCTAssertEqual(results[0].admin1, "Beijing")
        XCTAssertEqual(results[0].displayName, "Beijing, Beijing, China")
    }

    func testSearchReturnsEmptyForEmptyQuery() async {
        let service = CitySearchService(session: makeSession())
        let results = await service.search(query: "")
        XCTAssertTrue(results.isEmpty)

        let whitespaceResults = await service.search(query: "   ")
        XCTAssertTrue(whitespaceResults.isEmpty)
    }

    func testSearchReturnsEmptyOnNetworkError() async {
        CitySearchMockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let service = CitySearchService(session: makeSession())
        let results = await service.search(query: "Tokyo")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchReturnsEmptyWhenNoResults() async {
        CitySearchMockURLProtocol.requestHandler = { request in
            let data = Data("""
            {}
            """.utf8)

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }

        let service = CitySearchService(session: makeSession())
        let results = await service.search(query: "xyznonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testCitySearchResultToWeatherLocation() {
        let result = CitySearchResult(
            id: 1816670,
            name: "Beijing",
            country: "China",
            admin1: "Beijing",
            latitude: 39.9075,
            longitude: 116.3972
        )

        let location = result.toWeatherLocation
        XCTAssertEqual(location.name, "Beijing")
        XCTAssertEqual(location.country, "China")
        XCTAssertEqual(location.admin1, "Beijing")
        XCTAssertEqual(location.latitude, 39.9075, accuracy: 0.001)
        XCTAssertEqual(location.longitude, 116.3972, accuracy: 0.001)
    }

    func testCitySearchResultDisplayNameWithoutOptionalFields() {
        let result = CitySearchResult(
            id: 1,
            name: "Tokyo",
            country: nil,
            admin1: nil,
            latitude: 35.6762,
            longitude: 139.6503
        )

        XCTAssertEqual(result.displayName, "Tokyo")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CitySearchMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class CitySearchMockURLProtocol: URLProtocol {
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
