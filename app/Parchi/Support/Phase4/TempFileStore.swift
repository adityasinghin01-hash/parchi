import Foundation
import ParchiCore

/// Where parchi photo copies and short-lived caches live, so the retention promise has one place to enforce:
/// "removed the next time you open Parchi after 24 hours" (the sweep runs at launch and whenever the app becomes active,
/// so a file can outlive 24 hours if the app is not opened).
/// Each file's start date is remembered in a small index (`temp-index.json`, outside every swept folder). The start is the
/// EARLIER of the index date and the file system's creation date, never later than "now": rolling the clock back can therefore
/// delay removal by about the size of the rollback, not for ever (see `retentionStart`).
struct TempFileStore {
    let directory: URL
    private let fileManager = FileManager.default

    /// Folders swept by the same rule: our own folder, the system temp folder (frameworks such as the scanner leave files there)
    /// and the Documents/Inbox folder iOS uses for "Open in Parchi".
    var sweptFolders: [URL]
    let indexURL: URL
    /// Injected by tests to simulate a file that cannot be deleted.
    var removeItem: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }

    init(directory: URL? = nil, sweptFolders: [URL]? = nil, indexURL: URL? = nil) {
        let fm = FileManager.default
        let base = directory ?? fm.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ParchiTemp", isDirectory: true)
        self.directory = base
        var folders = [base, URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)]
        if let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            folders.append(documents.appendingPathComponent("Inbox", isDirectory: true))
        }
        self.sweptFolders = sweptFolders ?? folders
        self.indexURL = indexURL ?? (fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory)
            .appendingPathComponent("Parchi", isDirectory: true).appendingPathComponent("temp-index.json")
    }

    /// A path for a new temp file; the folder is created on first use.
    func url(for name: String) -> URL {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    @discardableResult
    func write(_ data: Data, name: String, now: Date = Date()) -> URL? {
        let target = url(for: name)
        do { try data.write(to: target, options: .atomic) } catch { return nil }
        var index = loadIndex()
        index[target.path] = now
        saveIndex(index)
        return target
    }

    // MARK: Index

    func loadIndex() -> [String: Date] {
        guard let data = try? Data(contentsOf: indexURL),
              let raw = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else { return [:] }
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    private func saveIndex(_ index: [String: Date]) {
        try? fileManager.createDirectory(at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(index.mapValues { $0.timeIntervalSince1970 }) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: Sweep

    /// Removes files whose 24 hours are over. Returns how many were removed. The index keeps only files that still exist.
    @discardableResult
    func purgeExpired(now: Date = Date()) -> Int {
        let old = loadIndex()
        var kept: [String: Date] = [:]
        var removed = 0
        for folder in sweptFolders {
            let entries = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])) ?? []
            for entry in entries where entry.standardizedFileURL != indexURL.standardizedFileURL {
                let values = try? entry.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                let start = retentionStart(recorded: old[entry.path], fileCreated: values?.creationDate ?? values?.contentModificationDate, now: now)
                if shouldPurge(created: start, now: now) {
                    if (try? removeItem(entry)) != nil { removed += 1 } else { kept[entry.path] = start }
                } else {
                    kept[entry.path] = start   // also stores a rebased date when the clock had been rolled back
                }
            }
        }
        saveIndex(kept)
        return removed
    }

    /// Delete everything: every file in the folders, the index, and the URL cache. Returns the names that could NOT be deleted.
    @discardableResult
    func removeAll() -> [String] {
        var failed: [String] = []
        for folder in sweptFolders {
            for entry in (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
                if entry.standardizedFileURL == indexURL.standardizedFileURL { continue }
                do { try removeItem(entry) } catch { failed.append(entry.lastPathComponent) }
            }
        }
        if fileManager.fileExists(atPath: indexURL.path) {
            do { try removeItem(indexURL) } catch { failed.append(indexURL.lastPathComponent) }
        }
        URLCache.shared.removeAllCachedResponses()
        return failed
    }
}
