import SwiftUI
import UIKit

/// Draws a screen of the HTML design natively in SwiftUI from its measured spec (`frontend/specs/web/<route>.json`, bundled as
/// `spec_<route>.json`): every element at its exact rectangle, with its exact font, colour, gradient, border, corner radius and shadow;
/// illustrations from the asset catalogue (`WebArt`), the logo, and the original SVG icons (`SVGIcon`). Values are CSS px at the 390 pt
/// design width and are scaled by `screenWidth / 390`, so the screen is identical to the HTML on every iPhone width.
/// `onTap` receives the CSS class of the tapped button/link (e.g. "account-bubble") so real navigation can be attached.
struct WebSpecScreen: View {
    let route: String
    var onTap: (String) -> Void = { _ in }
    /// Replaces the text of an element (by order index) with live data; return nil to keep the HTML text.
    var textOverride: (WebSpec.Element) -> String? = { _ in nil }

    private let spec: WebSpec?
    init(route: String, onTap: @escaping (String) -> Void = { _ in }, textOverride: @escaping (WebSpec.Element) -> String? = { _ in nil }) {
        self.route = route; self.onTap = onTap; self.textOverride = textOverride
        self.spec = WebSpec.load(route)
    }

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / 390
            if let spec {
                let scrolling = spec.nodes.filter { !$0.fixed }
                let pinned = spec.nodes.filter { $0.fixed }
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        ForEach(scrolling) { node in WebNodeView(node: node, k: k, onTap: onTap, textOverride: textOverride) }
                    }
                    .frame(width: geo.size.width, height: spec.scrollHeight * k, alignment: .topLeading)
                    .padding(.bottom, pinned.isEmpty ? 0 : 90 * k)
                }
                .overlay(alignment: .bottom) {
                    if let top = pinned.map({ $0.rect.y }).min(), let bottom = pinned.map({ $0.rect.y + $0.rect.h }).max() {
                        ZStack(alignment: .topLeading) {
                            ForEach(pinned) { node in WebNodeView(node: node, k: k, yShift: -top, onTap: onTap, textOverride: textOverride) }
                        }
                        .frame(width: geo.size.width, height: (bottom - top) * k, alignment: .topLeading)
                        .padding(.bottom, max(0, (spec.viewportHeight - bottom)) * k)
                    }
                }
            } else {
                Text("Missing screen spec: \(route)").padding()
            }
        }
        .background(Color.web(250, 238, 218))
        .ignoresSafeArea()
    }
}

// MARK: - Spec model

struct WebSpec: Decodable {
    struct Rect: Decodable { var x: CGFloat; var y: CGFloat; var w: CGFloat; var h: CGFloat }
    struct TypeInfo: Decodable {
        var family: String?; var size: CGFloat; var weight: String?; var style: String?; var color: String?
        var letterSpacing: String?; var lineHeight: String?; var align: String?; var transform: String?
    }
    struct Border: Decodable { var width: String; var style: String; var color: String }
    struct Element: Decodable, Identifiable {
        var order: Int; var tag: String; var cls: String; var rect: Rect; var z: Int?; var mask: String?; var blend: String?; var filter: String?
        var text: String?; var type: TypeInfo?; var bg: String?; var bgImage: String?; var border: Border?
        var radius: String?; var shadow: String?; var opacity: String?
        var placeholder: String?; var placeholderColor: String?; var svg: String?; var color: String?; var fixed: Bool?; var aria: String?
        var trect: Rect?; var lines: Int?; var pad: [CGFloat]?
        var id: Int { order }
    }
    struct Art: Decodable { var order: Int; var asset: String?; var rect: Rect; var z: Int?; var mask: String?; var blend: String?; var filter: String? }
    struct Img: Decodable { var order: Int; var src: String?; var rect: Rect; var radius: String?; var z: Int?; var mask: String?; var blend: String?; var filter: String? }

    var scrollHeight: CGFloat
    var viewport: Rect2
    struct Rect2: Decodable { var w: CGFloat; var h: CGFloat }
    var elements: [Element]
    var art: [Art]
    var images: [Img]
    var viewportHeight: CGFloat { viewport.h }

    enum Kind { case element(Element), art(Art), image(Img) }
    struct Node: Identifiable { var id: Int; var rect: Rect; var fixed: Bool; var kind: Kind; var z: Int = 0 }

    /// All drawable things in document order (the status bar / notch of the HTML phone frame are left out: the real device has its own).
    var nodes: [Node] {
        var out: [Node] = []
        for e in elements where !(e.cls.contains("clock") || e.cls.contains("dynamic-island") || (e.tag == "svg" && e.order <= 2 && e.rect.y < 30)) {
            out.append(Node(id: e.order, rect: e.rect, fixed: e.fixed ?? false, kind: .element(e), z: e.z ?? 0))
        }
        for a in art where a.asset != nil { out.append(Node(id: a.order, rect: a.rect, fixed: false, kind: .art(a), z: a.z ?? 0)) }
        for i in images where (i.src ?? "").contains("logo") { out.append(Node(id: i.order, rect: i.rect, fixed: false, kind: .image(i), z: i.z ?? 0)) }
        // CSS paint order: a negative z-index paints just above its container's background (and below the content), a positive one on top.
        func container(of n: Node) -> Int? {
            func overlap(_ q: Rect) -> CGFloat {
                let w = max(0, min(q.x + q.w, n.rect.x + n.rect.w) - max(q.x, n.rect.x)), h = max(0, min(q.y + q.h, n.rect.y + n.rect.h) - max(q.y, n.rect.y))
                return w * h / max(n.rect.w * n.rect.h, 1)
            }
            return elements.filter { $0.order < n.id && ($0.bg != nil || $0.bgImage != nil) && overlap($0.rect) >= 0.6 && $0.rect.h < 800 }.map(\.order).max()
        }
        func key(_ n: Node) -> Double {
            if n.z < 0 { return Double(container(of: n) ?? -1) + 0.5 }
            if n.z > 0 { return 1_000_000 + Double(n.z) * 1000 + Double(n.id) }
            return Double(n.id)
        }
        return out.sorted { key($0) < key($1) }
    }

    private static var cache: [String: WebSpec] = [:]
    static func load(_ route: String) -> WebSpec? {
        if let s = cache[route] { return s }
        guard let url = Bundle.main.url(forResource: "spec_\(route)", withExtension: "json"),
              let data = try? Data(contentsOf: url), let spec = try? JSONDecoder().decode(WebSpec.self, from: data) else { return nil }
        cache[route] = spec; return spec
    }
}

// MARK: - One node

private struct WebNodeView: View {
    let node: WebSpec.Node
    let k: CGFloat
    var yShift: CGFloat = 0
    let onTap: (String) -> Void
    let textOverride: (WebSpec.Element) -> String?

    var body: some View {
        let r = node.rect
        content
            .frame(width: r.w * k, height: r.h * k, alignment: .topLeading)
            .offset(x: r.x * k, y: (r.y + yShift) * k)
    }

    @ViewBuilder private var content: some View {
        switch node.kind {
        case .art(let a): Image(a.asset ?? "").resizable().scaledToFit().accessibilityHidden(true).modifier(CSS.Effects(mask: a.mask, blend: a.blend, filter: a.filter, w: node.rect.w * k, h: node.rect.h * k, k: k))
        case .image(let i): Image("ParchiLogo").resizable().scaledToFit().accessibilityHidden(true).modifier(CSS.Effects(mask: i.mask, blend: i.blend, filter: i.filter, w: node.rect.w * k, h: node.rect.h * k, k: k))
        case .element(let e): WebElementView(e: e, k: k, onTap: onTap, text: textOverride(e))
        }
    }
}

private struct WebElementView: View {
    let e: WebSpec.Element
    let k: CGFloat
    let onTap: (String) -> Void
    let text: String?

    var body: some View {
        let w = e.rect.w * k, h = e.rect.h * k
        ZStack(alignment: .topLeading) {
            if hasBox { box(w: w, h: h).frame(width: w, height: h) }
            if let svg = e.svg { SVGIcon(svg: svg, tint: (e.filter ?? "").contains("invert(1)") ? .white : (CSS.color(e.color) ?? .black)).frame(width: w, height: h).modifier(CSS.Effects(mask: e.mask, blend: e.blend, filter: nil, w: w, h: h, k: k)) }
            if let t = displayText { label(t, w: w, h: h) }
            if ["button", "a"].contains(e.tag) || e.cls.contains("account-bubble") {
                Color.clear.contentShape(Rectangle()).onTapGesture { onTap(e.cls.split(separator: " ").first.map(String.init) ?? e.tag) }
                    .accessibilityElement().accessibilityLabel(e.aria ?? e.text ?? e.cls).accessibilityAddTraits(.isButton)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .opacity(Double(e.opacity ?? "1") ?? 1)
    }

    private var hasBox: Bool { e.bg != nil || e.bgImage != nil || e.border != nil || e.shadow != nil }
    private var displayText: String? {
        if let t = text { return t }
        if let t = e.text, !t.isEmpty { return t }
        if e.tag == "input", let p = e.placeholder, (e.type != nil) { return p }
        return nil
    }

    // box: background colour, gradients, border, shadow
    @ViewBuilder private func box(w: CGFloat, h: CGFloat) -> some View {
        let shape = CSS.shape(e.radius, w: w, h: h, k: k)
        ZStack {
            if let bg = CSS.color(e.bg) { shape.fill(bg) }
            if let g = e.bgImage { ForEach(Array(CSS.gradients(g, w: w, h: h, k: k).enumerated()), id: \.offset) { _, style in shape.fill(style) } }
            if let b = e.border { CSS.borderView(b, shape: shape, w: w, h: h, k: k) }
        }
        .modifier(CSS.ShadowModifier(css: e.shadow, k: k))
    }

    @ViewBuilder private func label(_ raw: String, w: CGFloat, h: CGFloat) -> some View {
        let t = e.type!
        let size = t.size * k
        let font = CSS.font(t, size: size)
        let lh = CSS.px(t.lineHeight)
        let fontLH = font.lineHeight
        let tracking = CSS.px(t.letterSpacing) ?? 0
        // the browser's own measurement of where the glyphs are (falls back to the element box, inset by padding for inputs)
        let pad = e.pad ?? [0, 0, 0, 0]
        let tr = e.trect ?? WebSpec.Rect(x: e.rect.x + (pad.count == 4 ? pad[3] : 0), y: e.rect.y, w: e.rect.w - (pad.count == 4 ? pad[3] + pad[1] : 0), h: e.rect.h)
        let tw = tr.w * k, th = tr.h * k
        let dx = (tr.x - e.rect.x) * k, dy = (tr.y - e.rect.y) * k
        let color = (e.tag == "input" && e.text == nil ? CSS.color(e.placeholderColor) : CSS.color(t.color)) ?? .black
        let str = t.transform == "uppercase" ? raw.uppercased() : raw
        let ta: TextAlignment = t.align == "center" ? .center : (t.align == "right" || t.align == "end" ? .trailing : .leading)
        let single = !raw.contains("\n") && (e.lines ?? 1) <= 1
        if single {
            Text(str).font(Font(font)).tracking(tracking * k).foregroundStyle(color).lineLimit(1).fixedSize()
                .frame(width: tw, height: th, alignment: .center)
                .offset(x: dx, y: dy)
                .accessibilityLabel(str)
        } else {
            let extra = lh != nil ? lh! * k - fontLH : 0
            Text(str).font(Font(font)).tracking(tracking * k).foregroundStyle(color).multilineTextAlignment(ta)
                .lineSpacing(extra).fixedSize(horizontal: raw.contains("\n"), vertical: true)      // explicit breaks never re-wrap
                .frame(width: tw + 8 * k, height: th, alignment: .topLeading)
                .offset(x: dx, y: dy + extra / 2)
                .accessibilityLabel(str)
        }
    }
}

// MARK: - CSS value parsing

enum CSS {
    static func px(_ s: String?) -> CGFloat? {
        guard let s, s != "normal", s != "auto" else { return nil }
        return Double(s.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces)).map { CGFloat($0) }
    }

    static func color(_ s: String?) -> Color? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        let nums = s.drop(while: { $0 != "(" }).dropFirst().prefix(while: { $0 != ")" })
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).compactMap { Double($0.replacingOccurrences(of: "%", with: "")) }
        guard nums.count >= 3 else { return nil }
        return Color(.sRGB, red: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255, opacity: nums.count > 3 ? nums[3] : 1)
    }

    static func font(_ t: WebSpec.TypeInfo, size: CGFloat) -> UIFont {
        let weight = Double(t.weight ?? "400") ?? 400
        let italic = t.style == "italic"
        if (t.family ?? "").lowercased().contains("georgia") {
            let name = weight >= 600 ? (italic ? "Georgia-BoldItalic" : "Georgia-Bold") : (italic ? "Georgia-Italic" : "Georgia")
            return UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
        }
        let f = UIFont.systemFont(ofSize: size, weight: UIFont.Weight(rawValue: cssWeightToUIKit(weight)))
        return italic ? (f.fontDescriptor.withSymbolicTraits(.traitItalic).map { UIFont(descriptor: $0, size: size) } ?? f) : f
    }

    // corner radius: "27px", "50%", "10px 20px 0px 0px"
    static func shape(_ r: String?, w: CGFloat, h: CGFloat, k: CGFloat) -> UnevenRoundedRectangle {
        guard let r, r != "0px" else { return UnevenRoundedRectangle(cornerRadii: .init(), style: .continuous) }
        let parts = r.split(separator: " ").map(String.init)
        func one(_ p: String) -> CGFloat { p.hasSuffix("%") ? (Double(p.dropLast()) ?? 0) / 100 * min(w, h) : min((px(p) ?? 0) * k, min(w, h) / 2) }
        let v = parts.map(one)
        let tl = v.first ?? 0, tr = v.count > 1 ? v[1] : tl, br = v.count > 2 ? v[2] : tl, bl = v.count > 3 ? v[3] : tr
        return UnevenRoundedRectangle(cornerRadii: .init(topLeading: min(tl, min(w, h) / 2), bottomLeading: min(bl, min(w, h) / 2),
                                                          bottomTrailing: min(br, min(w, h) / 2), topTrailing: min(tr, min(w, h) / 2)), style: .continuous)
    }

    @ViewBuilder static func borderView(_ b: WebSpec.Border, shape: UnevenRoundedRectangle, w: CGFloat, h: CGFloat, k: CGFloat) -> some View {
        let widths = b.width.split(separator: " ").compactMap { px(String($0)) }
        let col = color(b.color) ?? .clear
        if widths.count == 4, Set(widths).count > 1 {      // different sides: draw each as a line (top, right, bottom, left)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(col).frame(width: w, height: widths[0] * k).offset(y: 0).opacity(widths[0] > 0 ? 1 : 0)
                Rectangle().fill(col).frame(width: widths[1] * k, height: h).offset(x: w - widths[1] * k).opacity(widths[1] > 0 ? 1 : 0)
                Rectangle().fill(col).frame(width: w, height: widths[2] * k).offset(y: h - widths[2] * k).opacity(widths[2] > 0 ? 1 : 0)
                Rectangle().fill(col).frame(width: widths[3] * k, height: h).opacity(widths[3] > 0 ? 1 : 0)
            }.frame(width: w, height: h, alignment: .topLeading)
        } else {
            let lw = (widths.first ?? 1) * k
            if b.style == "dashed" { shape.strokeBorder(col, style: StrokeStyle(lineWidth: lw, dash: [5 * k, 4 * k])) }
            else { shape.strokeBorder(col, lineWidth: lw) }
        }
    }

    /// "linear-gradient(...), radial-gradient(...)" -> one fill per layer, top layer LAST (CSS lists the top layer first).
    static func gradients(_ css: String, w: CGFloat, h: CGFloat, k: CGFloat) -> [AnyShapeStyle] {
        splitTop(css).reversed().compactMap { layer -> AnyShapeStyle? in
            let l = layer.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("linear-gradient("), let args = inner(l) { return linear(args, w: w, h: h) }
            if l.hasPrefix("radial-gradient("), let args = inner(l) { return radial(args, w: w, h: h, k: k) }
            return nil
        }
    }

    private static func inner(_ s: String) -> [String]? {
        guard let a = s.firstIndex(of: "("), let b = s.lastIndex(of: ")") else { return nil }
        return splitTop(String(s[s.index(after: a)..<b]))
    }

    private static func splitTop(_ s: String) -> [String] {
        var out: [String] = [], depth = 0, cur = ""
        for ch in s {
            if ch == "(" { depth += 1 } else if ch == ")" { depth -= 1 }
            if ch == "," && depth == 0 { out.append(cur); cur = "" } else { cur.append(ch) }
        }
        if !cur.trimmingCharacters(in: .whitespaces).isEmpty { out.append(cur) }
        return out
    }

    private static func stops(_ items: [String]) -> [Gradient.Stop] {
        var parsed: [(Color, CGFloat?)] = []
        for it in items {
            let t = it.trimmingCharacters(in: .whitespaces)
            guard let close = t.lastIndex(of: ")") else { continue }
            let colorPart = String(t[...close]); let rest = t[t.index(after: close)...].trimmingCharacters(in: .whitespaces)
            guard let c = color(colorPart) else { continue }
            parsed.append((c, rest.hasSuffix("%") ? Double(rest.dropLast()).map { CGFloat($0) / 100 } : nil))
        }
        guard !parsed.isEmpty else { return [] }
        var out: [Gradient.Stop] = []
        for (i, p) in parsed.enumerated() { out.append(.init(color: p.0, location: p.1 ?? (parsed.count == 1 ? 0 : CGFloat(i) / CGFloat(parsed.count - 1)))) }
        return out
    }

    private static func linear(_ a: [String], w: CGFloat, h: CGFloat) -> AnyShapeStyle? {
        var items = a; var angle: CGFloat = 180
        if let first = items.first?.trimmingCharacters(in: .whitespaces) {
            if first.hasSuffix("deg") { angle = CGFloat(Double(first.dropLast(3)) ?? 180); items.removeFirst() }
            else if first.hasPrefix("to ") {
                items.removeFirst()
                switch first { case "to right": angle = 90; case "to left": angle = 270; case "to top": angle = 0; case "to bottom": angle = 180
                case "to bottom right": angle = 135; case "to bottom left": angle = 225; case "to top right": angle = 45; case "to top left": angle = 315; default: break }
            }
        }
        let st = stops(items); guard st.count >= 1 else { return nil }
        let rad = angle * .pi / 180, dx = sin(rad), dy = -cos(rad)
        let len = abs(w * dx) + abs(h * dy), cx = w / 2, cy = h / 2
        let s = CGPoint(x: (cx - dx * len / 2) / max(w, 1), y: (cy - dy * len / 2) / max(h, 1))
        let e = CGPoint(x: (cx + dx * len / 2) / max(w, 1), y: (cy + dy * len / 2) / max(h, 1))
        return AnyShapeStyle(LinearGradient(stops: st, startPoint: UnitPoint(x: s.x, y: s.y), endPoint: UnitPoint(x: e.x, y: e.y)))
    }

    private static func radial(_ a: [String], w: CGFloat, h: CGFloat, k: CGFloat) -> AnyShapeStyle? {
        var items = a; var center = UnitPoint.center
        if let first = items.first, !first.contains("rgb"), !first.contains("#") {
            items.removeFirst()
            if let r = first.range(of: " at ") {
                let pos = first[r.upperBound...].split(separator: " ").map(String.init)
                func comp(_ s: String, _ total: CGFloat) -> CGFloat { s.hasSuffix("%") ? CGFloat(Double(s.dropLast()) ?? 50) / 100 : (px(s).map { $0 * k / max(total, 1) } ?? 0.5) }
                if pos.count >= 2 { center = UnitPoint(x: comp(pos[0], w), y: comp(pos[1], h)) }
            }
        }
        let st = stops(items); guard !st.isEmpty else { return nil }
        let far = max(hypot(max(center.x, 1 - center.x) * w, max(center.y, 1 - center.y) * h), 1)
        return AnyShapeStyle(RadialGradient(stops: st, center: center, startRadius: 0, endRadius: far))
    }

    /// CSS mask-image (gradient alpha), mix-blend-mode: multiply, filter: blur()/invert.
    struct Effects: ViewModifier {
        let mask: String?; let blend: String?; let filter: String?; let w: CGFloat; let h: CGFloat; let k: CGFloat
        func body(content: Content) -> some View {
            var v = AnyView(content)
            if let f = filter, f.contains("blur("), let r = f.range(of: "blur("), let px = CSS.px(String(f[r.upperBound...].prefix(while: { $0 != ")" }))) { v = AnyView(v.blur(radius: px * k)) }
            if let f = filter, f.contains("invert(1)") { v = AnyView(v.colorInvert()) }
            if let m = mask, m != "none" { for g in CSS.gradients(m, w: w, h: h, k: k) { v = AnyView(v.mask(Rectangle().fill(g))) } }
            if blend == "multiply" { v = AnyView(v.blendMode(.multiply)) }
            return v
        }
    }

    struct ShadowModifier: ViewModifier {
        let css: String?
        let k: CGFloat
        func body(content: Content) -> some View {
            let layers = (css.map(CSS.splitTop) ?? []).compactMap { raw -> (Color, CGFloat, CGFloat, CGFloat)? in
                let s = raw.trimmingCharacters(in: .whitespaces)
                guard !s.contains("inset"), let close = s.firstIndex(of: ")") else { return nil }
                let nums = s[s.index(after: close)...].split(separator: " ").compactMap { CSS.px(String($0)) }
                guard let c = CSS.color(String(s[...close])), nums.count >= 3 else { return nil }
                return (c, nums[0] * k, nums[1] * k, nums[2] * k)
            }
            return content
                .shadow(color: layers.first?.0 ?? .clear, radius: (layers.first?.3 ?? 0) / 2, x: layers.first?.1 ?? 0, y: layers.first?.2 ?? 0)
                .shadow(color: layers.count > 1 ? layers[1].0 : .clear, radius: (layers.count > 1 ? layers[1].3 : 0) / 2, x: layers.count > 1 ? layers[1].1 : 0, y: layers.count > 1 ? layers[1].2 : 0)
        }
    }
}
