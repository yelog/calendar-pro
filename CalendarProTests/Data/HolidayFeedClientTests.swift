import XCTest
@testable import CalendarPro

final class HolidayFeedClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
    }

    func testFeedClientDownloadsManifestAndPayloadsIntoCache() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2026.json")!
        let manifest = HolidayFeedManifest(
            version: "2026.03.29",
            generatedAt: Date(timeIntervalSince1970: 1_764_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2026, path: payloadURL.absoluteString)
            ]
        )

        let payloadData = Data(
            """
            [
              {
                "date": "2026-02-17",
                "name": "春节",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )

        MockURLProtocol.requestHandler = { request in
            switch request.url {
            case manifestURL:
                return (
                    HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try HolidayFeedManifest.encoder.encode(manifest)
                )
            case payloadURL:
                return (
                    HTTPURLResponse(url: payloadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    payloadData
                )
            default:
                throw URLError(.badURL)
            }
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL
        )

        let result = try await client.refreshIfNeeded(force: true)

        XCTAssertEqual(result.source, .remote)
        XCTAssertEqual(result.manifestVersion, "2026.03.29")
        XCTAssertNotNil(try cache.cachedManifest())

        let cachedData = try XCTUnwrap(try cache.loadHolidayData(regionID: "mainland-cn", year: 2026))
        let occurrences = try BundledHolidayDataLoader.decode(
            data: cachedData,
            regionID: "mainland-cn",
            source: .remoteFeed
        )
        XCTAssertEqual(occurrences.first?.name, "春节")
        XCTAssertEqual(occurrences.first?.source, .remoteFeed)
    }

    func testFeedClientPrefersCachedDataWhenRemoteFetchFails() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifest = HolidayFeedManifest(
            version: "cached-2026",
            generatedAt: Date(timeIntervalSince1970: 1_764_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2026, path: "mainland-cn-2026.json")
            ]
        )
        try cache.saveManifest(manifest)
        try cache.saveHolidayData(
            Data(
                """
                [
                  {
                    "date": "2026-02-17",
                    "name": "春节",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays"
                  }
                ]
                """.utf8
            ),
            regionID: "mainland-cn",
            year: 2026
        )

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: URL(string: "https://example.com/manifest.json")
        )

        let result = try await client.refreshIfNeeded(force: true)

        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.manifestVersion, "cached-2026")
    }

    private func makeCacheStore(name: String) -> HolidayCacheStore {
        let sanitizedName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CalendarProTests", isDirectory: true)
            .appendingPathComponent(sanitizedName, isDirectory: true)
        return HolidayCacheStore(baseURL: url)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol {
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
