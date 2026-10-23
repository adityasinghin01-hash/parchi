import XCTest

/// K24: shared helpers for the "ordinary user" journeys. A run is described by environment variables
/// (`TEST_RUNNER_K24_TAG`, `_SIZE`, `_DARK`) so the same journey can be replayed at big text, in dark mode, on a small phone.
/// Screenshots go to /tmp/k24/<tag>/ and every observation goes to /tmp/k24/<tag>/findings.txt (not asserted: they are a list for a human).
struct K24Env {
    let tag: String
    let size: String?      // e.g. UICTContentSizeCategoryAccessibilityXXXL
    let dark: Bool

    static var current: K24Env {
        let env = ProcessInfo.processInfo.environment
        return K24Env(tag: env["K24_TAG"] ?? "default", size: env["K24_SIZE"], dark: env["K24_DARK"] == "1")
    }

    var launchArguments: [String] {
        var args = ["-backendMode", "mock"]
        if let size { args += ["-UIPreferredContentSizeCategoryName", size] }
        return args
    }

    var dir: String { "/tmp/k24/\(tag)" }
}

final class K24Recorder {
    let env = K24Env.current
    init() { try? FileManager.default.createDirectory(atPath: env.dir, withIntermediateDirectories: true) }

    func note(_ text: String) {
        let line = text + "\n"
        let path = env.dir + "/findings.txt"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    func shot(_ app: XCUIApplication, _ journey: String, _ step: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(env.dir)/k24-\(journey)-\(step).png"))
    }

    /// Looks at one screen the way a person would: tiny tap targets, text running off the screen, labels with nothing in them.
    func scan(_ app: XCUIApplication, _ screen: String) {
        guard let root = try? app.snapshot() else { note("[\(screen)] could not snapshot"); return }
        let screenFrame = app.windows.firstMatch.frame
        var small: [String] = [], offscreen: [String] = [], unlabeled: [String] = []
        func walk(_ s: XCUIElementSnapshot) {
            let f = s.frame
            let visible = f.width > 0 && f.height > 0 && f.intersects(screenFrame)
            let interactive: [XCUIElement.ElementType] = [.button, .switch, .link, .textField, .secureTextField, .stepper, .segmentedControl]
            if visible, interactive.contains(s.elementType), s.isEnabled {
                if f.height < 43.5 || f.width < 43.5 {
                    // Segments of a segmented control and the keyboard are exempt from the width rule.
                    if !(s.elementType == .button && f.height >= 43.5) { small.append("\(s.elementType.rawValue):\(s.label.isEmpty ? s.identifier : s.label) \(Int(f.width))x\(Int(f.height))") }
                }
                if s.label.isEmpty && s.identifier.isEmpty && s.elementType == .button { unlabeled.append("button at \(Int(f.minX)),\(Int(f.minY))") }
            }
            if visible, s.elementType == .staticText, f.minX < -1 || f.maxX > screenFrame.maxX + 1 {
                offscreen.append("\"\(s.label.prefix(40))\" x \(Int(f.minX))..\(Int(f.maxX))")
            }
            s.children.forEach(walk)
        }
        walk(root)
        if !small.isEmpty { note("[\(screen)] SMALL TARGET: " + Array(Set(small)).sorted().prefix(8).joined(separator: " | ")) }
        if !offscreen.isEmpty { note("[\(screen)] TEXT OFF SCREEN: " + offscreen.prefix(5).joined(separator: " | ")) }
        if !unlabeled.isEmpty { note("[\(screen)] UNLABELLED BUTTON: " + unlabeled.prefix(5).joined(separator: " | ")) }
    }

    /// `performAccessibilityAudit`, recording every issue instead of failing the test.
    func audit(_ app: XCUIApplication, _ screen: String) {
        var count = 0
        do {
            try app.performAccessibilityAudit { issue in
                count += 1
                let element = issue.element.map { "\($0.elementType.rawValue) \"\(String($0.label.prefix(40)))\" id=\($0.identifier)" } ?? "(no element)"
                self.note("[\(screen)] AUDIT \(issue.auditType.rawValue): \(issue.compactDescription) | \(element)")
                return true
            }
        } catch {
            note("[\(screen)] AUDIT could not run: \(error)")
        }
        note("[\(screen)] AUDIT done, \(count) issue(s)")
    }

    /// All the visible text on the screen, for the wording check (jargon, English-only dead ends).
    func texts(_ app: XCUIApplication, _ screen: String) {
        guard let root = try? app.snapshot() else { return }
        var seen: [String] = []
        func walk(_ s: XCUIElementSnapshot) {
            if (s.elementType == .staticText || s.elementType == .button), !s.label.isEmpty, !seen.contains(s.label) { seen.append(s.label) }
            s.children.forEach(walk)
        }
        walk(root)
        let jargon = ["live", "mock", "sandbox", "temporal", "paise", "backend", "server", "json", "api", "idempotent", "workflow", "demo", "developer"]
        let hits = seen.filter { text in
            let lower = text.lowercased()
            return jargon.contains { word in lower.range(of: "\\b\(word)\\b", options: .regularExpression) != nil }
        }
        if !hits.isEmpty { note("[\(screen)] JARGON: " + hits.prefix(6).map { "\"\($0.prefix(70))\"" }.joined(separator: " | ")) }
        try? seen.joined(separator: "\n").write(toFile: "\(env.dir)/text-\(screen).txt", atomically: true, encoding: .utf8)
    }

    /// shot + scan + wording; audit only when asked (it is slow and only meaningful once per screen).
    func look(_ app: XCUIApplication, _ journey: String, _ step: String, audit doAudit: Bool = false) {
        Thread.sleep(forTimeInterval: 0.6)
        shot(app, journey, step)
        scan(app, "\(journey)-\(step)")
        texts(app, "\(journey)-\(step)")
        if doAudit && ProcessInfo.processInfo.environment["K24_AUDIT"] == "1" { audit(app, "\(journey)-\(step)") }
    }
}

extension XCUIApplication {
    func labelled(_ text: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    func labelContaining(_ text: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// Scrolls the first scrollable thing (a List, Form or ScrollView) up until `element` is on screen, at most `tries` swipes.
    func scrollTo(_ element: XCUIElement, tries: Int = 10) {
        for _ in 0..<tries where !(element.exists && element.isHittable) { swipeUp() }
    }

    /// Drags the screen a short way (about a third), the way a thumb does, so nothing is scrolled past unseen.
    func nudge(up: Bool = true) {
        let a = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.62 : 0.38))
        let b = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.38 : 0.62))
        a.press(forDuration: 0.05, thenDragTo: b)
    }

    /// Scrolls down in small steps, then back up, until `element` can be tapped. Returns whether it ever could.
    @discardableResult
    func reach(_ element: XCUIElement, steps: Int = 25) -> Bool {
        for _ in 0..<steps { if element.exists && element.isHittable { return true }; nudge(up: true) }
        for _ in 0..<steps { if element.exists && element.isHittable { return true }; nudge(up: false) }
        return element.exists && element.isHittable
    }

    /// Taps in the middle of the frame (taps on buttons inside a List can miss with `.tap()` in this app).
    func press(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
