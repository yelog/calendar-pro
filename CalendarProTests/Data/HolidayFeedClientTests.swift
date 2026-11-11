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
        XCTAssertTrue(result.didUpdatePayloads)
        XCTAssertNil(result.fallbackReason)
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
        XCTAssertFalse(result.didUpdatePayloads)
        XCTAssertNotNil(result.fallbackReason)
    }

    func testFeedClientSkipsPayloadDownloadsWhenManifestIsUnchanged() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2027.json")!
        let manifest = HolidayFeedManifest(
            version: "2027.11.05",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: payloadURL.absoluteString)
            ]
        )
        try cache.saveManifest(manifest)
        try cache.saveHolidayData(
            Data(
                """
                [
                  {
                    "date": "2027-01-01",
                    "name": "元旦",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays"
                  }
                ]
                """.utf8
            ),
            regionID: "mainland-cn",
            year: 2027
        )

        let counter = RequestCounter()
        MockURLProtocol.requestHandler = { request in
            counter.record(request.url)
            guard request.url == manifestURL else {
                throw URLError(.badURL)
            }
            return (
                HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                try HolidayFeedManifest.encoder.encode(manifest)
            )
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL
        )

        let result = try await client.refreshIfNeeded(force: true)

        XCTAssertEqual(result.source, .remote)
        XCTAssertFalse(result.didUpdatePayloads)
        XCTAssertEqual(result.refreshedPayloadCount, 0)
        XCTAssertEqual(counter.count(for: manifestURL), 1)
        XCTAssertEqual(counter.count(for: payloadURL), 0)
    }

    func testFeedClientRepairsMissingCachedPayloadWhenManifestIsUnchanged() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2027.json")!
        let manifest = HolidayFeedManifest(
            version: "2027.11.05",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: payloadURL.absoluteString)
            ]
        )
        try cache.saveManifest(manifest)

        let payloadData = Data(
            """
            [
              {
                "date": "2027-01-01",
                "name": "元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )
        MockURLProtocol.requestHandler = { request in
            if request.url == manifestURL {
                return (
                    HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try HolidayFeedManifest.encoder.encode(manifest)
                )
            }
            return (
                HTTPURLResponse(url: payloadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                payloadData
            )
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL
        )
        let result = try await client.refreshIfNeeded(force: true)

        XCTAssertEqual(result.source, .remote)
        XCTAssertTrue(result.didUpdatePayloads)
        XCTAssertEqual(result.refreshedPayloadCount, 1)
        XCTAssertEqual(try cache.loadHolidayData(regionID: "mainland-cn", year: 2027), payloadData)
    }

    func testFeedClientKeepsLastGoodCacheWhenAnyPayloadIsInvalid() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2027.json")!
        let cachedManifest = HolidayFeedManifest(
            version: "cached-2026",
            generatedAt: Date(timeIntervalSince1970: 1_764_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2026, path: "mainland-cn-2026.json")
            ]
        )
        let oldPayload = Data(
            """
            [
              {
                "date": "2026-02-17",
                "name": "旧缓存",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )
        try cache.saveManifest(cachedManifest)
        try cache.saveHolidayData(oldPayload, regionID: "mainland-cn", year: 2026)

        let newManifest = HolidayFeedManifest(
            version: "broken-2027",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: payloadURL.absoluteString)
            ]
        )
        MockURLProtocol.requestHandler = { request in
            if request.url == manifestURL {
                return (
                    HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try HolidayFeedManifest.encoder.encode(newManifest)
                )
            }
            return (
                HTTPURLResponse(url: payloadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("not-json".utf8)
            )
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL
        )
        let result = try await client.refreshIfNeeded(force: true)

        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.manifestVersion, "cached-2026")
        XCTAssertNotNil(result.fallbackReason)
        XCTAssertEqual(try cache.loadHolidayData(regionID: "mainland-cn", year: 2026), oldPayload)
        XCTAssertNil(try cache.loadHolidayData(regionID: "mainland-cn", year: 2027))
        XCTAssertEqual(try cache.cachedManifest()?.version, "cached-2026")
    }

    func testFeedClientAppliesRevisedPayloadWhenManifestTimestampChanges() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2027.json")!
        let oldManifest = HolidayFeedManifest(
            version: "2027.11.05",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: payloadURL.absoluteString)
            ]
        )
        let oldPayload = Data(
            """
            [
              {
                "date": "2027-01-01",
                "name": "旧元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )
        try cache.saveManifest(oldManifest)
        try cache.saveHolidayData(oldPayload, regionID: "mainland-cn", year: 2027)

        let revisedManifest = HolidayFeedManifest(
            version: oldManifest.version,
            generatedAt: oldManifest.generatedAt.addingTimeInterval(60),
            payloads: oldManifest.payloads
        )
        let revisedPayload = Data(
            """
            [
              {
                "date": "2027-01-01",
                "name": "修订元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )
        MockURLProtocol.requestHandler = { request in
            if request.url == manifestURL {
                return (
                    HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try HolidayFeedManifest.encoder.encode(revisedManifest)
                )
            }
            return (
                HTTPURLResponse(url: payloadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                revisedPayload
            )
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL
        )
        let result = try await client.refreshIfNeeded(force: true)

        XCTAssertTrue(result.didUpdatePayloads)
        XCTAssertEqual(try cache.loadHolidayData(regionID: "mainland-cn", year: 2027), revisedPayload)
        XCTAssertEqual(try cache.cachedManifest()?.generatedAt, revisedManifest.generatedAt)
    }

    func testFeedClientRepairsIncompleteCacheWithoutForcingRefresh() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2027.json")!
        let manifest = HolidayFeedManifest(
            version: "2027.11.05",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: payloadURL.absoluteString)
            ]
        )
        try cache.saveManifest(manifest)

        let payloadData = Data(
            """
            [
              {
                "date": "2027-01-01",
                "name": "元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )
        let counter = RequestCounter()
        MockURLProtocol.requestHandler = { request in
            counter.record(request.url)
            if request.url == manifestURL {
                return (
                    HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try HolidayFeedManifest.encoder.encode(manifest)
                )
            }
            return (
                HTTPURLResponse(url: payloadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                payloadData
            )
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL,
            now: { Date() },
            refreshInterval: 60 * 60
        )
        let result = try await client.refreshIfNeeded()

        XCTAssertTrue(result.didUpdatePayloads)
        XCTAssertEqual(counter.count(for: payloadURL), 1)
        XCTAssertEqual(try cache.loadHolidayData(regionID: "mainland-cn", year: 2027), payloadData)
    }

    func testSnapshotCommitFailureKeepsPreviousSnapshot() throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let oldManifest = HolidayFeedManifest(
            version: "old",
            generatedAt: Date(timeIntervalSince1970: 1_764_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2026, path: "mainland-cn-2026.json")
            ]
        )
        let oldPayload = Data("old-payload".utf8)
        try cache.commitSnapshot(
            HolidayCacheStore.Snapshot(
                manifest: oldManifest,
                payloads: [
                    .init(regionID: "mainland-cn", year: 2026, data: oldPayload)
                ]
            )
        )

        let newManifest = HolidayFeedManifest(
            version: "new",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: "mainland-cn-2027.json")
            ]
        )
        var writeCount = 0

        XCTAssertThrowsError(
            try cache.commitSnapshot(
                HolidayCacheStore.Snapshot(
                    manifest: newManifest,
                    payloads: [
                        .init(regionID: "mainland-cn", year: 2027, data: Data("new-payload".utf8))
                    ]
                ),
                writeData: { data, url in
                    writeCount += 1
                    if writeCount == 2 {
                        throw TestWriteError.forced
                    }
                    try data.write(to: url, options: .atomic)
                }
            )
        )

        XCTAssertEqual(writeCount, 2)
        XCTAssertEqual(try cache.cachedManifest(), oldManifest)
        XCTAssertEqual(
            try cache.loadHolidayData(regionID: "mainland-cn", year: 2026),
            oldPayload
        )
        XCTAssertNil(try cache.loadHolidayData(regionID: "mainland-cn", year: 2027))

        let snapshotDirectories = try FileManager.default.contentsOfDirectory(
            at: cache.baseURL.appendingPathComponent("snapshots", isDirectory: true),
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(snapshotDirectories.count, 1)
    }

    @MainActor
    func testSchedulerCoalescesConcurrentRefreshes() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2027.json")!
        let manifest = HolidayFeedManifest(
            version: "2027.11.05",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: payloadURL.absoluteString)
            ]
        )
        let payloadData = Data(
            """
            [
              {
                "date": "2027-01-01",
                "name": "元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )
        let counter = RequestCounter()
        MockURLProtocol.requestHandler = { request in
            counter.record(request.url)
            Thread.sleep(forTimeInterval: 0.2)
            if request.url == manifestURL {
                return (
                    HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try HolidayFeedManifest.encoder.encode(manifest)
                )
            }
            return (
                HTTPURLResponse(url: payloadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                payloadData
            )
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL
        )
        let scheduler = HolidayFeedRefreshScheduler(client: client)

        async let first = scheduler.refresh(force: true)
        async let second = scheduler.refresh(force: true)
        let (firstResult, secondResult) = try await (first, second)

        XCTAssertEqual(firstResult.source, .remote)
        XCTAssertEqual(secondResult.source, .remote)
        XCTAssertEqual(counter.count(for: manifestURL), 1)
    }

    @MainActor
    func testSchedulerPublishesBackgroundRefreshStatusToRegionSettings() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let suiteName = "HolidayFeedSchedulerStatus-\(#function)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let manifestURL = URL(string: "https://example.com/manifest.json")!
        let payloadURL = URL(string: "https://example.com/mainland-cn-2027.json")!
        let manifest = HolidayFeedManifest(
            version: "2027.11.05.120000",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: payloadURL.absoluteString)
            ]
        )
        let payloadData = Data(
            """
            [
              {
                "date": "2027-01-01",
                "name": "元旦",
                "kind": "statutoryHoliday",
                "holidaySetID": "statutory-holidays"
              }
            ]
            """.utf8
        )
        MockURLProtocol.requestHandler = { request in
            if request.url == manifestURL {
                return (
                    HTTPURLResponse(url: manifestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try HolidayFeedManifest.encoder.encode(manifest)
                )
            }
            return (
                HTTPURLResponse(url: payloadURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                payloadData
            )
        }

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: manifestURL
        )
        let scheduler = HolidayFeedRefreshScheduler(client: client)
        let viewModel = RegionSettingsViewModel(
            store: SettingsStore(userDefaults: userDefaults),
            feedClient: client,
            refreshScheduler: scheduler,
            cacheStore: cache
        )

        let result = try await scheduler.refresh(force: true)

        XCTAssertEqual(scheduler.latestOutcome, .success(result))
        XCTAssertEqual(
            viewModel.refreshStatusMessage,
            LF("Refreshed remote holiday data v%@", result.manifestVersion)
        )

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let fallback = try await scheduler.refresh(force: true)

        XCTAssertEqual(fallback.source, .cache)
        XCTAssertNotNil(fallback.fallbackReason)
        XCTAssertEqual(
            viewModel.refreshStatusMessage,
            LF("Using cached holiday data v%@, remote refresh failed", fallback.manifestVersion)
        )
    }

    @MainActor
    func testSchedulerReportsCachedDataWithoutClaimingRemoteUnchanged() async throws {
        let cache = makeCacheStore(name: #function)
        defer { try? FileManager.default.removeItem(at: cache.baseURL) }

        let suiteName = "HolidayFeedSchedulerCache-\(#function)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let manifest = HolidayFeedManifest(
            version: "2027.11.05.120000",
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: "mainland-cn-2027.json")
            ]
        )
        try cache.saveManifest(manifest)
        try cache.saveHolidayData(
            Data(
                """
                [
                  {
                    "date": "2027-01-01",
                    "name": "元旦",
                    "kind": "statutoryHoliday",
                    "holidaySetID": "statutory-holidays"
                  }
                ]
                """.utf8
            ),
            regionID: "mainland-cn",
            year: 2027
        )

        let client = HolidayFeedClient(
            session: makeSession(),
            cache: cache,
            manifestURL: URL(string: "https://example.com/manifest.json")
        )
        let scheduler = HolidayFeedRefreshScheduler(client: client)
        let viewModel = RegionSettingsViewModel(
            store: SettingsStore(userDefaults: userDefaults),
            feedClient: client,
            refreshScheduler: scheduler,
            cacheStore: cache
        )

        let result = try await scheduler.refresh()

        XCTAssertEqual(result.source, .cache)
        XCTAssertNil(result.fallbackReason)
        XCTAssertEqual(
            viewModel.refreshStatusMessage,
            LF("Using cached holiday data v%@", manifest.version)
        )
    }

    func testManifestValidationRejectsUnsafeAndDuplicatePayloads() {
        let unsafeManifest = HolidayFeedManifest(
            version: "test",
            generatedAt: Date(),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: "../mainland-cn-2027.json")
            ]
        )
        XCTAssertThrowsError(try unsafeManifest.validate()) { error in
            XCTAssertEqual(error as? HolidayFeedManifestError, .unsafePath("../mainland-cn-2027.json"))
        }

        let duplicateManifest = HolidayFeedManifest(
            version: "test",
            generatedAt: Date(),
            payloads: [
                .init(regionID: "mainland-cn", year: 2027, path: "a.json"),
                .init(regionID: "mainland-cn", year: 2027, path: "b.json")
            ]
        )
        XCTAssertThrowsError(try duplicateManifest.validate()) { error in
            XCTAssertEqual(error as? HolidayFeedManifestError, .duplicatePayload("mainland-cn-2027"))
        }
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

private enum TestWriteError: Error {
    case forced
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

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [URL: Int] = [:]

    func record(_ url: URL?) {
        guard let url else { return }
        lock.lock()
        counts[url, default: 0] += 1
        lock.unlock()
    }

    func count(for url: URL) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[url, default: 0]
    }
}
