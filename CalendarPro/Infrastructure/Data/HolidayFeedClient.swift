import Foundation

enum HolidayFeedClientError: Error, Equatable, Sendable {
    case manifestURLNotConfigured
    case invalidPayloadURL(String)
    case invalidResponse(URL)
}

struct HolidayFeedClient: Sendable {
    enum RefreshSource: Equatable, Sendable {
        case remote
        case cache
    }

    struct RefreshResult: Equatable, Sendable {
        let source: RefreshSource
        let manifestVersion: String
        let generatedAt: Date
        let refreshedPayloadCount: Int
        let didUpdatePayloads: Bool
        let fallbackReason: String?
    }

    let session: URLSession
    let cache: HolidayCacheStore
    let manifestURL: URL?
    let now: @Sendable () -> Date
    let refreshInterval: TimeInterval

    init(
        session: URLSession = .shared,
        cache: HolidayCacheStore = .default,
        manifestURL: URL? = Self.configuredManifestURL,
        now: @escaping @Sendable () -> Date = Date.init,
        refreshInterval: TimeInterval = 12 * 60 * 60
    ) {
        self.session = session
        self.cache = cache
        self.manifestURL = manifestURL
        self.now = now
        self.refreshInterval = refreshInterval
    }

    static let defaultManifestURL = URL(string: "https://raw.githubusercontent.com/yelog/calendar-pro/main/feed/holidays/manifest.json")!

    static var configuredManifestURL: URL? {
        if let value = ProcessInfo.processInfo.environment["CALENDAR_PRO_HOLIDAY_MANIFEST_URL"] {
            return URL(string: value)
        }

        return defaultManifestURL
    }

    static func configuredClient(cache: HolidayCacheStore = .default) -> HolidayFeedClient? {
        guard let manifestURL = configuredManifestURL else {
            return nil
        }

        return HolidayFeedClient(cache: cache, manifestURL: manifestURL)
    }

    func refreshIfNeeded(force: Bool = false) async throws -> RefreshResult {
        if
            !force,
            let cachedManifest = validCachedManifest(),
            let modifiedAt = cache.manifestModifiedAt(),
            now().timeIntervalSince(modifiedAt) < refreshInterval,
            hasCompleteCachedPayloads(for: cachedManifest)
        {
            return makeCachedResult(from: cachedManifest)
        }

        guard let manifestURL else {
            if let cachedManifest = validCachedManifest() {
                return makeCachedResult(from: cachedManifest)
            }

            throw HolidayFeedClientError.manifestURLNotConfigured
        }

        do {
            let manifestData = try await fetchData(from: manifestURL)
            let manifest = try HolidayFeedManifest.decoder.decode(HolidayFeedManifest.self, from: manifestData)
            try manifest.validate()

            if
                let cachedManifest = validCachedManifest(),
                cachedManifest == manifest,
                hasCompleteCachedPayloads(for: manifest)
            {
                do {
                    try cache.markManifestChecked(at: now())
                } catch {
                    // Valid cached data remains usable. The scheduler falls back
                    // to a full refresh interval when the check time is stale.
                }
                return RefreshResult(
                    source: .remote,
                    manifestVersion: manifest.version,
                    generatedAt: manifest.generatedAt,
                    refreshedPayloadCount: 0,
                    didUpdatePayloads: false,
                    fallbackReason: nil
                )
            }

            var downloadedPayloads: [(payload: HolidayFeedManifest.Payload, data: Data)] = []
            for payload in manifest.payloads {
                guard let payloadURL = payload.resolvedURL(relativeTo: manifestURL) else {
                    throw HolidayFeedClientError.invalidPayloadURL(payload.path)
                }

                let payloadData = try await fetchData(from: payloadURL)
                _ = try BundledHolidayDataLoader.decode(
                    data: payloadData,
                    regionID: payload.regionID,
                    year: payload.year,
                    source: .remoteFeed
                )
                downloadedPayloads.append((payload, payloadData))
            }

            try cache.commitSnapshot(
                HolidayCacheStore.Snapshot(
                    manifest: manifest,
                    payloads: downloadedPayloads.map { download in
                        HolidayCacheStore.Snapshot.Payload(
                            regionID: download.payload.regionID,
                            year: download.payload.year,
                            data: download.data
                        )
                    }
                )
            )

            return RefreshResult(
                source: .remote,
                manifestVersion: manifest.version,
                generatedAt: manifest.generatedAt,
                refreshedPayloadCount: downloadedPayloads.count,
                didUpdatePayloads: true,
                fallbackReason: nil
            )
        } catch {
            if let cachedManifest = validCachedManifest() {
                return makeCachedResult(from: cachedManifest, fallbackReason: error.localizedDescription)
            }

            throw error
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw HolidayFeedClientError.invalidResponse(url)
        }

        return data
    }

    private func hasCompleteCachedPayloads(for manifest: HolidayFeedManifest) -> Bool {
        manifest.payloads.allSatisfy { payload in
            guard
                let data = try? cache.loadHolidayData(
                    regionID: payload.regionID,
                    year: payload.year
                )
            else {
                return false
            }

            return (try? BundledHolidayDataLoader.decode(
                data: data,
                regionID: payload.regionID,
                year: payload.year,
                source: .remoteFeed
            )) != nil
        }
    }

    private func validCachedManifest() -> HolidayFeedManifest? {
        guard
            let manifest = try? cache.cachedManifest(),
            (try? manifest.validate()) != nil
        else {
            return nil
        }
        return manifest
    }

    private func makeCachedResult(from manifest: HolidayFeedManifest) -> RefreshResult {
        RefreshResult(
            source: .cache,
            manifestVersion: manifest.version,
            generatedAt: manifest.generatedAt,
            refreshedPayloadCount: manifest.payloads.count,
            didUpdatePayloads: false,
            fallbackReason: nil
        )
    }

    private func makeCachedResult(
        from manifest: HolidayFeedManifest,
        fallbackReason: String
    ) -> RefreshResult {
        RefreshResult(
            source: .cache,
            manifestVersion: manifest.version,
            generatedAt: manifest.generatedAt,
            refreshedPayloadCount: manifest.payloads.count,
            didUpdatePayloads: false,
            fallbackReason: fallbackReason
        )
    }
}
