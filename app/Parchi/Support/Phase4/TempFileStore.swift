import Foundation
import ParchiCore

/// Where parchi photo crops and short-lived caches live, so the "deleted after 24 hours" promise has one place to enforce.
/// Everything the app writes for a photo goes through `url(for:)`; `purgeExpired()` runs at launch and when the app opens.
struct TempFileStore {
    let directory: URL
    private let fileManager = FileManager.default

    /// Extra folders swept by the same rule (the system temp folder holds anything a framework left behind).
    var sweptFolders: [URL]

    init(directory: URL? = nil, sweptFolders: [URL]? = nil) {
        let base = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ParchiTemp", isDirectory: true)
        self.directory = base
        self.sweptFolders = sweptFolders ?? [base, URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)]
    }

    /// A path for a new temp file; the folder is created on first use.
    func url(for name: String) -> URL {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    @discardableResult
    func write(_ data: Data, name: String) -> URL? {
        let target = url(for: name)
        do { try data.write(to: target, options: .atomic); return target } catch { return nil }
    }

    /// Deletes files 24 h old or older. Returns how many were removed.
    @discardableResult
    func purgeExpired(now: Date = Date()) -> Int {
        var removed = 0
        for folder in sweptFolders {
            let entries = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])) ?? []
            for entry in entries {
                let values = try? entry.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                guard let created = values?.creationDate ?? values?.contentModificationDate else { continue }
                if shouldPurge(created: created, now: now), (try? fileManager.removeItem(at: entry)) != nil { removed += 1 }
            }
        }
        return removed
    }

    /// Delete everything: every file in the folders, and the URL cache.
    func removeAll() {
        for folder in sweptFolders {
            for entry in (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
                try? fileManager.removeItem(at: entry)
            }
        }
        URLCache.shared.removeAllCachedResponses()
    }
}
