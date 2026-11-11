import Foundation

enum HolidayCacheStoreError: Error, Equatable {
    case invalidSnapshot
}

struct HolidayCacheStore: Sendable {
    struct Snapshot: Sendable {
        struct Payload: Sendable {
            let regionID: String
            let year: Int
            let data: Data
        }

        let manifest: HolidayFeedManifest
        let payloads: [Payload]
    }

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
        let url = currentManifestURL
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try HolidayFeedManifest.decoder.decode(HolidayFeedManifest.self, from: data)
    }

    func manifestModifiedAt() -> Date? {
        let values = try? currentManifestURL.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    func markManifestChecked(at date: Date) throws {
        let fileManager = FileManager.default
        let url = currentManifestURL
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func saveManifest(_ manifest: HolidayFeedManifest) throws {
        try ensureDirectory()
        let data = try HolidayFeedManifest.encoder.encode(manifest)
        try data.write(to: legacyManifestURL, options: .atomic)
    }

    func loadHolidayData(regionID: String, year: Int) throws -> Data? {
        let fileManager = FileManager.default
        let url = currentPayloadURL(regionID: regionID, year: year)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func saveHolidayData(_ data: Data, regionID: String, year: Int) throws {
        try ensureDirectory()
        try data.write(
            to: legacyPayloadURL(regionID: regionID, year: year),
            options: .atomic
        )
    }

    func commitSnapshot(
        _ snapshot: Snapshot,
        writeData: (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) throws {
        try validate(snapshot)

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: snapshotsDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let snapshotID = UUID().uuidString
        let stagingURL = snapshotsDirectoryURL
            .appendingPathComponent(".staging-\(snapshotID)", isDirectory: true)
        let publishedURL = snapshotsDirectoryURL
            .appendingPathComponent(snapshotID, isDirectory: true)

        try fileManager.createDirectory(
            at: stagingURL,
            withIntermediateDirectories: false,
            attributes: nil
        )

        var movedSnapshotURL: URL?
        do {
            let manifestData = try HolidayFeedManifest.encoder.encode(snapshot.manifest)
            try writeData(manifestData, stagingURL.appendingPathComponent(Self.manifestFilename))

            for payload in snapshot.payloads {
                try writeData(
                    payload.data,
                    stagingURL.appendingPathComponent(
                        Self.payloadFilename(regionID: payload.regionID, year: payload.year)
                    )
                )
            }

            try fileManager.moveItem(at: stagingURL, to: publishedURL)
            movedSnapshotURL = publishedURL
            try Data("\(snapshotID)\n".utf8).write(
                to: activeSnapshotPointerURL,
                options: .atomic
            )
            movedSnapshotURL = nil
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if let movedSnapshotURL {
                try? fileManager.removeItem(at: movedSnapshotURL)
            }
            throw error
        }

        cleanupSnapshots(keeping: snapshotID)
    }

    private static let manifestFilename = "manifest.json"
    private static let activeSnapshotFilename = "active-snapshot"

    private var snapshotsDirectoryURL: URL {
        baseURL.appendingPathComponent("snapshots", isDirectory: true)
    }

    private var activeSnapshotPointerURL: URL {
        baseURL.appendingPathComponent(Self.activeSnapshotFilename)
    }

    private var legacyManifestURL: URL {
        baseURL.appendingPathComponent(Self.manifestFilename)
    }

    private var currentManifestURL: URL {
        activeSnapshotDirectoryURL?.appendingPathComponent(Self.manifestFilename)
            ?? legacyManifestURL
    }

    private func currentPayloadURL(regionID: String, year: Int) -> URL {
        if let activeSnapshotDirectoryURL {
            return activeSnapshotDirectoryURL.appendingPathComponent(
                Self.payloadFilename(regionID: regionID, year: year)
            )
        }
        return legacyPayloadURL(regionID: regionID, year: year)
    }

    private var activeSnapshotDirectoryURL: URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: activeSnapshotPointerURL.path) else {
            return nil
        }
        guard
            let rawValue = try? String(contentsOf: activeSnapshotPointerURL, encoding: .utf8)
        else {
            return nil
        }

        let snapshotID = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !snapshotID.isEmpty,
            snapshotID.range(
                of: #"^[A-Za-z0-9-]+$"#,
                options: .regularExpression
            ) != nil
        else {
            return nil
        }

        let directoryURL = snapshotsDirectoryURL
            .appendingPathComponent(snapshotID, isDirectory: true)
        let manifestURL = directoryURL.appendingPathComponent(Self.manifestFilename)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return nil
        }
        return directoryURL
    }

    private func legacyPayloadURL(regionID: String, year: Int) -> URL {
        baseURL.appendingPathComponent(
            Self.payloadFilename(regionID: regionID, year: year)
        )
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func validate(_ snapshot: Snapshot) throws {
        try snapshot.manifest.validate()

        let manifestIDs = Set(snapshot.manifest.payloads.map(\.id))
        let payloadIDs = snapshot.payloads.map { payload in
            "\(payload.regionID)-\(payload.year)"
        }
        guard
            Set(payloadIDs).count == payloadIDs.count,
            manifestIDs.count == payloadIDs.count,
            manifestIDs == Set(payloadIDs)
        else {
            throw HolidayCacheStoreError.invalidSnapshot
        }
    }

    private static func payloadFilename(regionID: String, year: Int) -> String {
        "\(regionID)-\(year).json"
    }

    private func cleanupSnapshots(keeping snapshotID: String) {
        let fileManager = FileManager.default
        guard
            let directories = try? fileManager.contentsOfDirectory(
                at: snapshotsDirectoryURL,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        else {
            return
        }

        for directory in directories where directory.lastPathComponent != snapshotID {
            try? fileManager.removeItem(at: directory)
        }
    }
}
