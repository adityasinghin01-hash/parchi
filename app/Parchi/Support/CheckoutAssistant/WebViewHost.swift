import Observation
import SwiftUI
import WebKit

/// Owns the in-app browser. Parchi only loads pages and highlights text: it never clicks, types or submits on a seller's site.
@MainActor
@Observable
final class WebController: NSObject, WKNavigationDelegate, WKUIDelegate {
    enum Outcome: Equatable {
        case finished, failed(String), timedOut
    }

    private(set) var currentURL: URL?
    private(set) var pageTitle = ""
    private(set) var isLoading = false
    private(set) var canGoBack = false
    private(set) var note: String?
    @ObservationIgnored var onNavigated: ((URL) -> Void)?

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private var waiter: CheckedContinuation<Outcome, Never>?
    @ObservationIgnored private var waitToken = 0

    override init() {
        let config = WKWebsiteDataStore.default()   // persistent: logins survive; CheckoutPrivacy.clearSellerSessions() wipes them
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = config
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    // MARK: Commands

    func load(_ url: URL) {
        guard url.scheme == "https" else { note = "Only secure (https) pages open here."; return }
        note = nil
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func reload() { webView.reload() }

    /// Loads and waits until the page finishes, fails, or `timeout` seconds pass (used by the seller probe).
    func loadAndWait(_ url: URL, timeout: Double = 40) async -> Outcome {
        waiter?.resume(returning: .failed("interrupted"))
        waiter = nil
        waitToken += 1
        let token = waitToken
        let outcome: Outcome = await withCheckedContinuation { continuation in
            waiter = continuation
            load(url)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                if self?.waitToken == token { self?.finishWaiting(.timedOut) }   // a newer load must not be cut short by an old timer
            }
        }
        return outcome
    }

    /// Empties the view so a failed load can never be mistaken for the previous seller's page.
    func resetToBlank() async {
        waiter?.resume(returning: .failed("interrupted"))
        waiter = nil
        waitToken += 1
        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            waiter = continuation
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        }
    }

    private func finishWaiting(_ outcome: Outcome) {
        guard let waiter else { return }
        self.waiter = nil
        waiter.resume(returning: outcome)
    }

    /// Highlights the first place `text` appears and scrolls to it. Returns true when found. Only changes how the page looks.
    func highlight(_ text: String) async -> Bool {
        guard !text.isEmpty, let data = try? JSONEncoder().encode(text), let literal = String(data: data, encoding: .utf8) else { return false }
        let script = """
        (function(q){
          document.querySelectorAll('mark[data-parchi]').forEach(function(m){ m.replaceWith(document.createTextNode(m.textContent)); });
          var esc = q.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
          var re = new RegExp(esc, 'i');
          var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
          var node;
          while ((node = walker.nextNode())) {
            var p = node.parentElement;
            if (!p || /^(SCRIPT|STYLE|NOSCRIPT)$/.test(p.tagName)) continue;
            var m = re.exec(node.nodeValue);
            if (!m) continue;
            var r = document.createRange();
            r.setStart(node, m.index); r.setEnd(node, m.index + m[0].length);
            var mk = document.createElement('mark');
            mk.setAttribute('data-parchi', '1');
            mk.style.cssText = 'background:#ffe14d;color:#000;outline:3px solid #ff9500;border-radius:3px;';
            try { r.surroundContents(mk); } catch (e) { continue; }
            mk.scrollIntoView({block: 'center', behavior: 'smooth'});
            return 1;
          }
          return 0;
        })(\(literal))
        """
        let result = try? await webView.evaluateJavaScript(script)
        return (result as? NSNumber)?.intValue == 1
    }

    /// Plain facts about the loaded page for the probe: title, visible text length, and a snippet.
    func pageFacts() async -> (host: String, title: String, textLength: Int, snippet: String) {
        let script = "JSON.stringify({h: location.host, t: document.title || '', n: (document.body ? document.body.innerText.length : 0), s: (document.body ? document.body.innerText.slice(0, 600) : '')})"
        guard let json = try? await webView.evaluateJavaScript(script) as? String,
              let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ("", "", 0, "") }
        return (obj["h"] as? String ?? "", obj["t"] as? String ?? "", obj["n"] as? Int ?? 0, obj["s"] as? String ?? "")
    }

    // MARK: WKNavigationDelegate

    private func sync() {
        currentURL = webView.url
        pageTitle = webView.title ?? ""
        canGoBack = webView.canGoBack
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        if scheme == "https" || scheme == "about" {
            decisionHandler(.allow)
        } else {
            note = "Blocked a non-https link (\(scheme ?? "unknown")). Parchi only opens secure pages."
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        sync()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        sync()
        if let url = webView.url { onNavigated?(url) }
        finishWaiting(.finished)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        sync()
        if (error as NSError).code == NSURLErrorCancelled { return }
        finishWaiting(.failed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        sync()
        // -999 = this load was replaced by a redirect or a newer load: keep waiting for the one that replaced it.
        if (error as NSError).code == NSURLErrorCancelled { return }
        note = "Page did not load: \(error.localizedDescription)"
        finishWaiting(.failed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        sync()
        if let url = webView.url { onNavigated?(url) }
    }

    // MARK: WKUIDelegate: links that want a new window open in the same view (https only)

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url, url.scheme?.lowercased() == "https" {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

/// Shows the controller's web view. No autofill hacks: the seller's page and iOS handle sign-in themselves.
struct WebViewHost: UIViewRepresentable {
    let controller: WebController

    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
