import SwiftUI

/// Debug screen for research item R1: which seller sites render and allow login/cart inside an in-app browser.
/// It only loads pages and reads the title and visible text length. It never taps or types on a seller's site.
struct SellerProbeView: View {
    enum Verdict: String, Codable, CaseIterable {
        case unknown = "Not tried", renders = "Renders", blocked = "Blocked", needsLogin = "Needs login"
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .renders: return .green
            case .blocked: return .red
            case .needsLogin: return .orange
            }
        }
    }

    struct Row: Identifiable {
        let site: SellerSites.Site
        let productURL: URL?
        /// First word of the product name the link is for (e.g. "azithral"); nil for home pages.
        var brand: String?
        var verdict = Verdict.unknown
        var detail = ""
        var id: String { site.id }
        var url: URL { productURL ?? site.home }
    }

    @State private var web = WebController()
    @State private var rows: [Row] = []
    @State private var running = false
    @State private var selected: String?
    @State private var status = "idle"
    @State private var entries: [Entry] = []
    private let autoRun: Bool
    /// `-probeOut <dir>` (K21 test runs): write report.json and one PNG per page there. Nothing is written when absent.
    private let outDir = UserDefaults.standard.string(forKey: "probeOut")

    /// One loaded page, read-only checks only (K21).
    struct Entry: Codable {
        var seller = "", id = "", page = "", url = "", outcome = "", note = ""
        var seconds = 0.0
        var checks = WebController.PageChecks()
        var startedAt = ""
    }

    init(autoRun: Bool = false) { self.autoRun = autoRun }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                WebViewHost(controller: web)
                if web.isLoading { ProgressView().padding(8).background(.thinMaterial, in: Capsule()).padding(.top, 8) }
            }
            .frame(maxHeight: .infinity)
            Text(web.currentURL?.absoluteString ?? "No page loaded").font(.caption2).lineLimit(1)
                .padding(.horizontal).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
            Text(status).font(.caption2).accessibilityIdentifier("probe.status").frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
            List($rows) { $row in
                HStack {
                    Button {
                        selected = row.id
                        web.load(row.url)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.site.name).font(.subheadline.bold()).foregroundStyle(row.id == selected ? Color.accentColor : .primary)
                            Text(row.detail.isEmpty ? row.url.host() ?? "" : row.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Menu {
                        ForEach(Verdict.allCases, id: \.self) { v in Button(v.rawValue) { row.verdict = v; save() } }
                    } label: {
                        Text(row.verdict.rawValue).font(.caption.bold()).foregroundStyle(row.verdict.color)
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: 260)
        }
        .navigationTitle("Seller probe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(running ? "Probing…" : "Probe all") { Task { await probeAll() } }.disabled(running)
            }
        }
        .task {
            let links = SellerSites.productLinks()
            rows = SellerSites.all.map { site in
                let brand = site.linkKey.flatMap { links.firstItemKey(linkKey: $0) }?.split(separator: "_").first.map(String.init)
                return Row(site: site, productURL: site.linkKey.flatMap { links.firstURL(linkKey: $0) }, brand: brand)
            }
            if autoRun { await probeAll() }
        }
    }

    // MARK: Probe

    private func probeAll() async {
        running = true
        status = "running"
        entries = []
        defer { running = false }
        for index in rows.indices {
            rows[index].detail = "loading…"
            status = "running: \(rows[index].site.name)"
            let row = rows[index]
            var result = await probe(row, url: row.url, page: row.productURL == nil ? "home" : "product")
            if result.verdict != .renders, rows[index].productURL != nil {
                let home = await probe(row, url: row.site.home, page: "home")
                result.detail += " | home: \(home.verdict.rawValue) \(home.detail)"
                if home.verdict == .renders { result.verdict = .renders }
            }
            rows[index].verdict = result.verdict
            rows[index].detail = result.detail
            save()
        }
        writeReport()
        status = "done"
        if let best = rows.first(where: { $0.verdict == .renders }) {
            selected = best.id
            _ = await web.loadAndWait(best.url)
        }
    }

    private func probe(_ row: Row, url: URL, page: String) async -> (verdict: Verdict, detail: String) {
        await web.resetToBlank()
        let started = Date()
        let stamp = ISO8601DateFormatter().string(from: started)
        let outcome = await web.loadAndWait(url)
        let seconds = Date().timeIntervalSince(started)
        try? await Task.sleep(for: .seconds(2))   // let script-built pages finish drawing
        let facts = await web.pageFacts()
        let checks = await web.pageChecks(brand: page == "product" ? row.brand : nil)
        if let dir = outDir, let png = await web.snapshotPNG() {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(row.id)-\(page).png"))
        }
        let host = facts.host.isEmpty ? "?" : facts.host
        let lower = (facts.title + " " + facts.snippet).lowercased()
        let markers = ["access denied", "forbidden", "captcha", "verify you are human", "unusual traffic", "request blocked", "are you a robot", "403", "blocked"]
        var entry = Entry(seller: row.site.name, id: row.id, page: page, url: url.absoluteString, seconds: (seconds * 10).rounded() / 10, checks: checks, startedAt: stamp)
        entry.checks.textLength = max(entry.checks.textLength, facts.textLength)
        let hit = markers.first(where: { lower.contains($0) })
        var verdict = Verdict.renders
        var detail = "\(facts.title.prefix(40)) · \(facts.textLength) chars · \(host)"
        if case .failed(let message) = outcome {
            verdict = .blocked; detail = "error: \(message)"
            entry.outcome = message.lowercased().contains("internet") || message.lowercased().contains("offline") ? "offline" : "blocked"
            entry.note = message
        } else if outcome == .timedOut && facts.textLength < 150 {
            verdict = .blocked; detail = "timed out, nothing rendered"; entry.outcome = "timed out"
        } else if let hit, facts.textLength < 1500 {
            verdict = .blocked; detail = "page says \"\(hit)\" · \(host)"; entry.outcome = "blocked"; entry.note = "page says \(hit)"
        } else if !checks.botWall.isEmpty && facts.textLength < 1500 {
            verdict = .blocked; detail = "bot wall: \(checks.botWall) · \(host)"; entry.outcome = "blocked"; entry.note = checks.botWall
        } else if facts.textLength < 150 {
            verdict = .blocked; detail = "blank page (\(facts.textLength) chars) · \(host)"; entry.outcome = "blank"
        } else {
            entry.outcome = outcome == .timedOut ? "timed out" : "loaded"
            if outcome == .timedOut { entry.note = "page never finished loading but rendered \(facts.textLength) chars" }
        }
        entries.append(entry)
        return (verdict, detail)
    }

    private func writeReport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: docs.appendingPathComponent("seller_probe_pages.json"))
        }
        if let dir = outDir {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("report.json"))
        }
    }

    /// Writes Documents/seller_probe.json so results can be read off the Simulator.
    private func save() {
        let payload = rows.map { ["seller": $0.site.name, "url": $0.url.absoluteString, "verdict": $0.verdict.rawValue, "detail": $0.detail] }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? data.write(to: dir.appendingPathComponent("seller_probe.json"))
    }
}
