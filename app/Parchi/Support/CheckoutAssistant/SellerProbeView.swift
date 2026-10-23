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
        var verdict = Verdict.unknown
        var detail = ""
        var id: String { site.id }
        var url: URL { productURL ?? site.home }
    }

    @State private var web = WebController()
    @State private var rows: [Row] = []
    @State private var running = false
    @State private var selected: String?
    private let autoRun: Bool

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
            rows = SellerSites.all.map { site in Row(site: site, productURL: site.linkKey.flatMap { links.firstURL(linkKey: $0) }) }
            if autoRun { await probeAll() }
        }
    }

    // MARK: Probe

    private func probeAll() async {
        running = true
        defer { running = false }
        for index in rows.indices {
            rows[index].detail = "loading…"
            var result = await probe(rows[index].url)
            if result.verdict != .renders, rows[index].productURL != nil {
                let home = await probe(rows[index].site.home)
                result.detail += " | home: \(home.verdict.rawValue) \(home.detail)"
                if home.verdict == .renders { result.verdict = .renders }
            }
            rows[index].verdict = result.verdict
            rows[index].detail = result.detail
            save()
        }
        if let best = rows.first(where: { $0.verdict == .renders }) {
            selected = best.id
            _ = await web.loadAndWait(best.url)
        }
    }

    private func probe(_ url: URL) async -> (verdict: Verdict, detail: String) {
        await web.resetToBlank()
        let outcome = await web.loadAndWait(url)
        try? await Task.sleep(for: .seconds(2))   // let script-built pages finish drawing
        let facts = await web.pageFacts()
        let host = facts.host.isEmpty ? "?" : facts.host
        let lower = (facts.title + " " + facts.snippet).lowercased()
        let markers = ["access denied", "forbidden", "captcha", "verify you are human", "unusual traffic", "request blocked", "are you a robot", "403", "blocked"]
        if case .failed(let message) = outcome { return (.blocked, "error: \(message)") }
        if outcome == .timedOut && facts.textLength < 150 { return (.blocked, "timed out, nothing rendered") }
        if let hit = markers.first(where: { lower.contains($0) }), facts.textLength < 1500 { return (.blocked, "page says \"\(hit)\" · \(host)") }
        if facts.textLength < 150 { return (.blocked, "blank page (\(facts.textLength) chars) · \(host)") }
        return (.renders, "\(facts.title.prefix(40)) · \(facts.textLength) chars · \(host)")
    }

    /// Writes Documents/seller_probe.json so results can be read off the Simulator.
    private func save() {
        let payload = rows.map { ["seller": $0.site.name, "url": $0.url.absoluteString, "verdict": $0.verdict.rawValue, "detail": $0.detail] }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? data.write(to: dir.appendingPathComponent("seller_probe.json"))
    }
}
