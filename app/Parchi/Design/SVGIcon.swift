import SwiftUI
import UIKit

/// Draws the HTML's inline SVG icons exactly (markup copied from the spec: `frontend/specs/web/<route>.json`, field `svg`).
///
///     SVGIcon(svg: "<svg viewBox=\"0 0 24 24\" ...>...</svg>", tint: Theme.Color.accent)
///         .frame(width: 24 * u, height: 24 * u)
///
/// Supports svg/g, path (all commands incl. arcs), circle, ellipse, rect (rx/ry), line, polyline, polygon; fill, stroke, stroke-width,
/// stroke-linecap, stroke-linejoin, fill-rule, opacity, transform (translate, scale, rotate, matrix). `currentColor` uses `tint`.
/// Gradients and filters are not supported (the shape falls back to a solid colour).
struct SVGIcon: View {
    let svg: String
    var tint: Color? = nil

    var body: some View {
        let doc = SVGDocument.cached(svg)
        Canvas { ctx, size in doc.draw(in: &ctx, size: size, tint: tint) }
            .accessibilityHidden(true)
    }
}

// MARK: - Model

private struct SVGStyle {
    var fill: String? = "black"
    var stroke: String? = nil
    var strokeWidth: CGFloat = 1
    var cap: CGLineCap = .butt
    var join: CGLineJoin = .miter
    var evenOdd = false
    var opacity: CGFloat = 1
    var fillOpacity: CGFloat = 1
    var strokeOpacity: CGFloat = 1

    mutating func apply(_ a: [String: String]) {
        var attrs = a
        if let style = a["style"] {
            for part in style.split(separator: ";") {
                let kv = part.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if kv.count == 2 { attrs[kv[0]] = kv[1] }
            }
        }
        if let v = attrs["fill"] { fill = v == "none" ? nil : v }
        if let v = attrs["stroke"] { stroke = v == "none" ? nil : v }
        if let v = attrs["stroke-width"], let d = Double(v) { strokeWidth = CGFloat(d) }
        if let v = attrs["stroke-linecap"] { cap = v == "round" ? .round : (v == "square" ? .square : .butt) }
        if let v = attrs["stroke-linejoin"] { join = v == "round" ? .round : (v == "bevel" ? .bevel : .miter) }
        if let v = attrs["fill-rule"] { evenOdd = v == "evenodd" }
        if let v = attrs["opacity"], let d = Double(v) { opacity *= CGFloat(d) }
        if let v = attrs["fill-opacity"], let d = Double(v) { fillOpacity = CGFloat(d) }
        if let v = attrs["stroke-opacity"], let d = Double(v) { strokeOpacity = CGFloat(d) }
    }
}

private struct SVGShape {
    var path: CGPath
    var style: SVGStyle
    var transform: CGAffineTransform
}

private final class SVGDocument: NSObject, XMLParserDelegate {
    private static var store: [String: SVGDocument] = [:]
    static func cached(_ svg: String) -> SVGDocument {
        if let d = store[svg] { return d }
        let d = SVGDocument(svg); store[svg] = d; return d
    }

    var viewBox = CGRect(x: 0, y: 0, width: 24, height: 24)
    private var shapes: [SVGShape] = []
    private var styleStack: [SVGStyle] = []
    private var transformStack: [CGAffineTransform] = []

    init(_ svg: String) {
        super.init()
        let parser = XMLParser(data: Data(svg.utf8))
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String] = [:]) {
        var style = styleStack.last ?? SVGStyle()
        var tf = transformStack.last ?? .identity
        if name != "svg" || styleStack.isEmpty { style.apply(a) }
        if let t = a["transform"] { tf = parseTransform(t).concatenating(tf) }
        styleStack.append(style); transformStack.append(tf)
        let n = { (k: String) -> CGFloat in CGFloat(Double(a[k] ?? "") ?? 0) }
        var p: CGPath?
        switch name {
        case "svg":
            if let vb = a["viewBox"] {
                let v = vb.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
                if v.count == 4 { viewBox = CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }
            }
        case "path": if let d = a["d"] { p = SVGPathParser.parse(d) }
        case "circle": p = CGPath(ellipseIn: CGRect(x: n("cx") - n("r"), y: n("cy") - n("r"), width: 2 * n("r"), height: 2 * n("r")), transform: nil)
        case "ellipse": p = CGPath(ellipseIn: CGRect(x: n("cx") - n("rx"), y: n("cy") - n("ry"), width: 2 * n("rx"), height: 2 * n("ry")), transform: nil)
        case "rect":
            let r = CGRect(x: n("x"), y: n("y"), width: n("width"), height: n("height"))
            var rx = n("rx"), ry = n("ry"); if a["rx"] != nil && a["ry"] == nil { ry = rx }; if a["ry"] != nil && a["rx"] == nil { rx = ry }
            p = rx > 0 || ry > 0 ? CGPath(roundedRect: r, cornerWidth: min(rx, r.width / 2), cornerHeight: min(ry, r.height / 2), transform: nil) : CGPath(rect: r, transform: nil)
        case "line":
            let m = CGMutablePath(); m.move(to: CGPoint(x: n("x1"), y: n("y1"))); m.addLine(to: CGPoint(x: n("x2"), y: n("y2"))); p = m
        case "polyline", "polygon":
            let v = (a["points"] ?? "").split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" }).compactMap { Double($0) }
            let m = CGMutablePath()
            for i in stride(from: 0, to: v.count - 1, by: 2) { let pt = CGPoint(x: v[i], y: v[i + 1]); i == 0 ? m.move(to: pt) : m.addLine(to: pt) }
            if name == "polygon" { m.closeSubpath() }
            p = m
        default: break
        }
        if let p { shapes.append(SVGShape(path: p, style: style, transform: tf)) }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        _ = styleStack.popLast(); _ = transformStack.popLast()
    }

    func draw(in ctx: inout GraphicsContext, size: CGSize, tint: Color?) {
        guard viewBox.width > 0, viewBox.height > 0 else { return }
        let s = min(size.width / viewBox.width, size.height / viewBox.height)            // preserveAspectRatio = xMidYMid meet
        let ox = (size.width - viewBox.width * s) / 2 - viewBox.minX * s
        let oy = (size.height - viewBox.height * s) / 2 - viewBox.minY * s
        let root = CGAffineTransform(translationX: ox, y: oy).scaledBy(x: s, y: s)
        func color(_ v: String?, _ alpha: CGFloat) -> Color? {
            guard let v else { return nil }
            if v == "currentColor" { return (tint ?? .black).opacity(alpha) }
            return (SVGDocument.parseColor(v) ?? tint ?? .black).opacity(alpha)
        }
        for shape in shapes {
            var t = shape.transform.concatenating(root)
            guard let moved = shape.path.copy(using: &t) else { continue }
            let path = Path(moved)
            let st = shape.style
            if let c = color(st.fill, st.opacity * st.fillOpacity) { ctx.fill(path, with: .color(c), style: FillStyle(eoFill: st.evenOdd)) }
            if let c = color(st.stroke, st.opacity * st.strokeOpacity) {
                ctx.stroke(path, with: .color(c), style: StrokeStyle(lineWidth: st.strokeWidth * s * sqrt(abs(shape.transform.a * shape.transform.d - shape.transform.b * shape.transform.c)), lineCap: st.cap, lineJoin: st.join))
            }
        }
    }

    static func parseColor(_ v: String) -> Color? {
        let s = v.trimmingCharacters(in: .whitespaces).lowercased()
        switch s { case "black": return .black; case "white": return .white; case "red": return .red; case "none", "transparent": return .clear; default: break }
        if s.hasPrefix("#") {
            var h = String(s.dropFirst()); if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
            guard h.count == 6, let n = UInt32(h, radix: 16) else { return nil }
            return Color(.sRGB, red: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255, blue: Double(n & 255) / 255, opacity: 1)
        }
        if s.hasPrefix("rgb") {
            let v = s.drop(while: { $0 != "(" }).dropFirst().prefix(while: { $0 != ")" }).split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).compactMap { Double($0.replacingOccurrences(of: "%", with: "")) }
            if v.count >= 3 { return Color(.sRGB, red: v[0] / 255, green: v[1] / 255, blue: v[2] / 255, opacity: v.count > 3 ? v[3] : 1) }
        }
        return nil
    }

    private func parseTransform(_ text: String) -> CGAffineTransform {
        var result = CGAffineTransform.identity
        let scanner = Scanner(string: text)
        while !scanner.isAtEnd {
            guard let name = scanner.scanUpToString("("), scanner.scanString("(") != nil, let args = scanner.scanUpToString(")") else { break }
            _ = scanner.scanString(")")
            let v = args.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }.map { CGFloat($0) }
            let key = name.trimmingCharacters(in: .whitespaces)
            var t = CGAffineTransform.identity
            switch key {
            case "translate": t = CGAffineTransform(translationX: v.first ?? 0, y: v.count > 1 ? v[1] : 0)
            case "scale": t = CGAffineTransform(scaleX: v.first ?? 1, y: v.count > 1 ? v[1] : (v.first ?? 1))
            case "rotate":
                t = CGAffineTransform(rotationAngle: (v.first ?? 0) * .pi / 180)
                if v.count == 3 { t = CGAffineTransform(translationX: v[1], y: v[2]).rotated(by: (v[0]) * .pi / 180).translatedBy(x: -v[1], y: -v[2]) }
            case "matrix": if v.count == 6 { t = CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5]) }
            default: break
            }
            result = t.concatenating(result)
        }
        return result
    }
}

// MARK: - Path data

enum SVGPathParser {
    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        let chars = Array(d.unicodeScalars)
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl = CGPoint.zero, lastCmd: Character = "M"

        func skipSep() { while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" || chars[i] == "\r" { i += 1 } }
        func number() -> CGFloat? {
            skipSep(); let begin = i
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
            var dot = false
            while i < chars.count {
                let c = chars[i]
                if c.properties.numericType != nil, c.value >= 48, c.value <= 57 { i += 1 }
                else if c == ".", !dot { dot = true; i += 1 }
                else if c == "e" || c == "E" { i += 1; if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 } }
                else { break }
            }
            guard i > begin, let v = Double(String(String.UnicodeScalarView(chars[begin..<i]))) else { i = begin; return nil }
            return CGFloat(v)
        }
        func flag() -> Bool? { skipSep(); guard i < chars.count, chars[i] == "0" || chars[i] == "1" else { return nil }; defer { i += 1 }; return chars[i] == "1" }

        while true {
            skipSep()
            if i >= chars.count { break }
            let c = Character(chars[i])
            if c.isLetter { cmd = c; i += 1 } else if cmd == "M" { cmd = "L" } else if cmd == "m" { cmd = "l" }
            let rel = cmd.isLowercase
            let up = Character(cmd.uppercased())
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y) }
            switch up {
            case "Z": path.closeSubpath(); cur = start; lastCmd = "Z"; continue
            case "M": guard let x = number(), let y = number() else { return path }; cur = pt(x, y); start = cur; path.move(to: cur)
            case "L": guard let x = number(), let y = number() else { return path }; cur = pt(x, y); path.addLine(to: cur)
            case "H": guard let x = number() else { return path }; cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y); path.addLine(to: cur)
            case "V": guard let y = number() else { return path }; cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y); path.addLine(to: cur)
            case "C":
                guard let x1 = number(), let y1 = number(), let x2 = number(), let y2 = number(), let x = number(), let y = number() else { return path }
                let c1 = pt(x1, y1), c2 = pt(x2, y2), e = pt(x, y); path.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "S":
                guard let x2 = number(), let y2 = number(), let x = number(), let y = number() else { return path }
                let c1 = (lastCmd == "C" || lastCmd == "S") ? CGPoint(x: 2 * cur.x - lastCtrl.x, y: 2 * cur.y - lastCtrl.y) : cur
                let c2 = pt(x2, y2), e = pt(x, y); path.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "Q":
                guard let x1 = number(), let y1 = number(), let x = number(), let y = number() else { return path }
                let c1 = pt(x1, y1), e = pt(x, y); path.addQuadCurve(to: e, control: c1); lastCtrl = c1; cur = e
            case "T":
                guard let x = number(), let y = number() else { return path }
                let c1 = (lastCmd == "Q" || lastCmd == "T") ? CGPoint(x: 2 * cur.x - lastCtrl.x, y: 2 * cur.y - lastCtrl.y) : cur
                let e = pt(x, y); path.addQuadCurve(to: e, control: c1); lastCtrl = c1; cur = e
            case "A":
                guard let rx = number(), let ry = number(), let rot = number(), let fa = flag(), let fs = flag(), let x = number(), let y = number() else { return path }
                let e = pt(x, y); addArc(path, from: cur, rx: rx, ry: ry, rotation: rot, large: fa, sweep: fs, to: e); cur = e
            default: return path
            }
            lastCmd = up
        }
        return path
    }

    /// SVG arc (endpoint form) -> cubic Beziers (W3C implementation notes F.6).
    private static func addArc(_ path: CGMutablePath, from p0: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool, to p1: CGPoint) {
        var rx = abs(rx0), ry = abs(ry0)
        if p0 == p1 { return }
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180, cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosP * dx + sinP * dy, y1p = -sinP * dx + cosP * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : sqrt(max(0, num / den)); if large == sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry, cyp = -coef * ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2, cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy); return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi } else if sweep && delta < 0 { delta += 2 * .pi }
        let segments = Int(ceil(abs(delta) / (.pi / 2)))
        let step = delta / CGFloat(segments)
        let t = 4.0 / 3.0 * tan(step / 4)
        var a1 = theta1
        for _ in 0..<segments {
            let a2 = a1 + step
            func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cosP * rx * x - sinP * ry * y + cx, y: sinP * rx * x + cosP * ry * y + cy) }
            let c1 = map(cos(a1) - t * sin(a1), sin(a1) + t * cos(a1))
            let c2 = map(cos(a2) + t * sin(a2), sin(a2) - t * cos(a2))
            let e = map(cos(a2), sin(a2))
            path.addCurve(to: e, control1: c1, control2: c2)
            a1 = a2
        }
    }
}
