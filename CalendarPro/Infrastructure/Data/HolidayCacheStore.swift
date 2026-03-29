import Foundation

struct HolidayCacheStore: Sendable {
    let baseURL: URL

    init(baseURL: URL? = nil, fileManager: FileManager = .default) {
        if let baseURL {
            self.baseURL = baseURL
        } else if let appSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            self.baseURL = appSupportURL
                .appendingPathComponent("CalendarPro", isDirectory: true)
                .appendingPathComponent("HolidayCache", isDirectory: true)
        } else {
            self.baseURL = fileManager.temporaryDirectory
                .appendingPathComponent("CalendarPro", isDirectory: true)
                .appendingPathComponent("HolidayCache", isDirectory: true)
        }
    }

    static let `default` = HolidayCacheStore()

    func cachedManifest() throws -> HolidayFeedManifest? {
        let fileManager = FileManager.default
        let url = manifestURL
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try HolidayFeedManifest.decoder.decode(HolidayFeedManifest.self, from: data)
    }

    func manifestModifiedAt() -> Date? {
        let values = try? manifestURL.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    func saveManifest(_ manifest: HolidayFeedManifest) throws {
        try ensureDirectory()
        let data = try HolidayFeedManifest.encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }

    func loadHolidayData(regionID: String, year: Int) throws -> Data? {
        let fileManager = FileManager.default
        let url = payloadURL(regionID: regionID, year: year)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func saveHolidayData(_ data: Data, regionID: String, year: Int) throws {
        try ensureDirectory()
        try data.write(to: payloadURL(regionID: regionID, year: year), options: .atomic)
    }

    private var manifestURL: URL {
        baseURL.appendingPathComponent("manifest.json")
    }

    private func payloadURL(regionID: String, year: Int) -> URL {
        baseURL.appendingPathComponent("\(regionID)-\(year).json")
    }

    private func ensureDirectory() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
    }
}
