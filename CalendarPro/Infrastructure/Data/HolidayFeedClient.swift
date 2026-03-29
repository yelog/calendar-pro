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

    static var configuredManifestURL: URL? {
        guard let value = ProcessInfo.processInfo.environment["CALENDAR_PRO_HOLIDAY_MANIFEST_URL"] else {
            return nil
        }

        return URL(string: value)
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
            let cachedManifest = try cache.cachedManifest(),
            let modifiedAt = cache.manifestModifiedAt(),
            now().timeIntervalSince(modifiedAt) < refreshInterval
        {
            return makeCachedResult(from: cachedManifest)
        }

        guard let manifestURL else {
            if let cachedManifest = try cache.cachedManifest() {
                return makeCachedResult(from: cachedManifest)
            }

            throw HolidayFeedClientError.manifestURLNotConfigured
        }

        do {
            let manifestData = try await fetchData(from: manifestURL)
            let manifest = try HolidayFeedManifest.decoder.decode(HolidayFeedManifest.self, from: manifestData)

            for payload in manifest.payloads {
                guard let payloadURL = payload.resolvedURL(relativeTo: manifestURL) else {
                    throw HolidayFeedClientError.invalidPayloadURL(payload.path)
                }

                let payloadData = try await fetchData(from: payloadURL)
                try cache.saveHolidayData(payloadData, regionID: payload.regionID, year: payload.year)
            }

            try cache.saveManifest(manifest)

            return RefreshResult(
                source: .remote,
                manifestVersion: manifest.version,
                generatedAt: manifest.generatedAt,
                refreshedPayloadCount: manifest.payloads.count
            )
        } catch {
            if let cachedManifest = try cache.cachedManifest() {
                return makeCachedResult(from: cachedManifest)
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

    private func makeCachedResult(from manifest: HolidayFeedManifest) -> RefreshResult {
        RefreshResult(
            source: .cache,
            manifestVersion: manifest.version,
            generatedAt: manifest.generatedAt,
            refreshedPayloadCount: manifest.payloads.count
        )
    }
}
