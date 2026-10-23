// Parchi on-phone privacy blur: finds the patient's name, age, phone and address on a parchi photo
// with Apple Vision text boxes + rules, and returns boxes to blur. Medicine lines are never blurred.
// Fails closed: if no "Name" label is found, every non-letterhead line above the first medicine line is blurred.
// Usage: pii_blur <imageDir> <out.json> [blurredOutDir]
import AppKit
import Foundation
import Vision

struct Line { let text: String; let box: CGRect; let obs: VNRecognizedTextObservation; let cand: VNRecognizedText }

let medCue = try! NSRegularExpression(pattern: #"(?i)^\s*(\d+[\).]?\s*)?[-—–]?\s*(tab|tabs|cap|caps|syp|syr|syrup|inj|oint|gel|drops?|cream|lotion|t\.|c\.)\b|^\s*(\d+[\).]?\s*)?[-—–]?\s*(टैब|टेब|कैप|सिरप|इंज)"#)
let rxCue = try! NSRegularExpression(pattern: #"(?i)^\s*(rx|℞|r/x|adv\b|inv\b|investigations?)"#)
let nameLabel = try! NSRegularExpression(pattern: #"(?i)\b(patient'?s?\s*name|pt\.?\s*name|name|mr\.|mrs\.|ms\.|shri|smt\.?|baby|master)\s*[:\-.]?\s*|(रोगी\s*का\s*नाम|मरीज़?\s*का\s*नाम|नाम)\s*[:\-.]?\s*"#)
let ageLabel = try! NSRegularExpression(pattern: #"(?i)\b(age\s*/\s*sex|age|sex|उम्र|आयु)\s*[:\-.]?\s*"#)
let phoneLabel = try! NSRegularExpression(pattern: #"(?i)\b(mob(ile)?|phone|contact|cell|m\.?\s*no)\b\s*[:\-.]?\s*"#)
let addrLabel = try! NSRegularExpression(pattern: #"(?i)\b(address|addr|r/o|h\.?\s*no|vill(age)?|dist(t|rict)?|पता)\s*[:\-.]?\s*"#)
let otherLabel = try! NSRegularExpression(pattern: #"(?i)\b(age|sex|date|wt|weight|temp|bp|pulse|dt)\b"#)
let phone = try! NSRegularExpression(pattern: #"(?:\+91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}"#)
let ageValue = try! NSRegularExpression(pattern: #"(?i)\b\d{1,3}\s*(y|yr|yrs|years|y/m|y/f|m|f)\b|\b\d{1,3}\s*/\s*[mf]\b"#)
let letterhead = try! NSRegularExpression(pattern: #"(?i)(\bdr\b|dr\.|m\.?b\.?b\.?s|\breg\b|reg\.|clinic|hospital|nursing|centre|center|physician|specialist|consultant|surgeon|timing|m\.?d\b|d\.?n\.?b|d\.?c\.?h|d\.?g\.?o|polyclinic|road|nagar|\bph\b|ph:|emergency|डॉ|चिकित्स|अस्पताल|क्लिनिक|केन्द्र|केंद्र|समिति|समय)"#)

func has(_ r: NSRegularExpression, _ s: String) -> NSTextCheckingResult? {
    r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s))
}

/// Box of the text after a label inside one recognised line (Vision gives per-substring boxes).
func valueBox(_ l: Line, after m: NSTextCheckingResult) -> CGRect? {
    let ns = l.text as NSString
    var end = ns.length
    if let o = otherLabel.firstMatch(in: l.text, range: NSRange(location: m.range.upperBound, length: ns.length - m.range.upperBound)) {
        end = o.range.location
    }
    guard end > m.range.upperBound,
          let r = Range(NSRange(location: m.range.upperBound, length: end - m.range.upperBound), in: l.text),
          !l.text[r].trimmingCharacters(in: .whitespaces).isEmpty,
          let b = try? l.cand.boundingBox(for: r) else { return nil }
    return b.boundingBox
}

/// Region to the right of a printed label whose handwritten value Vision read as a separate line.
func rightRegion(_ l: Line, labelEnd: CGFloat, lines: [Line], maxWidth: CGFloat) -> CGRect {
    let h = l.box.height
    var right = min(1, labelEnd + maxWidth)
    for o in lines where o.box.minX > labelEnd + 0.01 && abs(o.box.midY - l.box.midY) < h * 1.5 && has(otherLabel, o.text) != nil {
        right = min(right, o.box.minX - 0.005)
    }
    return CGRect(x: labelEnd, y: l.box.minY - h * 0.9, width: max(0.05, right - labelEnd), height: h * 2.8)
}

func pad(_ r: CGRect, _ p: CGFloat = 0.01) -> CGRect { r.insetBy(dx: -p, dy: -p * 0.7) }

func blurBoxes(_ lines: [Line]) -> (boxes: [CGRect], rule: String) {
    // Vision boxes: normalised, origin bottom-left. "Above" on the page = larger y.
    // The fallback cut is the first medicine line; a printed "Rx" often sits beside the patient's name, so it is only a backup.
    let medY = lines.filter { has(medCue, $0.text) != nil }.map { $0.box.maxY }.max()
    let firstMedY = medY ?? lines.filter { has(rxCue, $0.text) != nil }.map { $0.box.maxY }.max()
    var out: [CGRect] = []
    var foundName = false
    let protected: (Line) -> Bool = { has(medCue, $0.text) != nil }
    for l in lines where !protected(l) {
        for (label, width) in [(nameLabel, CGFloat(0.55)), (ageLabel, CGFloat(0.22)), (addrLabel, CGFloat(0.6)), (phoneLabel, CGFloat(0.45))] {
            if label === phoneLabel && has(letterhead, l.text) != nil { continue }
            guard let m = has(label, l.text) else { continue }
            if label === nameLabel { foundName = true }
            if let vb = valueBox(l, after: m) {
                out.append(pad(vb.union(CGRect(x: vb.minX, y: vb.minY - vb.height * 0.4, width: vb.width * 1.15, height: vb.height * 1.8))))
            } else {
                let ns = l.text as NSString
                let labelRange = Range(NSRange(location: 0, length: min(ns.length, m.range.upperBound)), in: l.text)!
                let lb = (try? l.cand.boundingBox(for: labelRange))?.boundingBox ?? l.box
                let region = rightRegion(l, labelEnd: lb.maxX, lines: lines, maxWidth: width)
                out.append(pad(region))
                for o in lines where !protected(o) && o.box.intersects(region) { out.append(pad(o.box)) }
            }
        }
        if let m = has(phone, l.text), let r = Range(m.range, in: l.text), let b = try? l.cand.boundingBox(for: r) {
            if has(letterhead, l.text) == nil { out.append(pad(b.boundingBox)) }
        }
        if has(ageValue, l.text) != nil, let y = firstMedY, l.box.minY > y { out.append(pad(l.box)) }
    }
    if !foundName, let y = firstMedY {  // fail closed
        for l in lines where l.box.minY > y && has(letterhead, l.text) == nil && !protected(l) { out.append(pad(l.box)) }
        return (out, "fallback")
    }
    if !foundName {  // no name label and no medicine line: blur every non-letterhead line in the top half
        for l in lines where l.box.minY > 0.5 && has(letterhead, l.text) == nil { out.append(pad(l.box)) }
        return (out, lines.isEmpty ? "no_text" : "fallback_top_half")
    }
    return (out, foundName ? "label" : "none")
}

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let blurredDir = args.count > 3 ? URL(fileURLWithPath: args[3]) : nil
if let b = blurredDir { try? FileManager.default.createDirectory(at: b, withIntermediateDirectories: true) }
let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    .filter { ["png", "jpg", "jpeg"].contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
var results: [String: Any] = [:]
for f in files {
    let url = dir.appendingPathComponent(f)
    guard let img = NSImage(contentsOf: url), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    // Two passes: Vision reads one script per request (the first language decides), so English and Hindi run separately.
    var lines: [Line] = []
    for langs in [["en-US"], ["hi-IN"]] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = langs
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        lines += (req.results ?? []).compactMap { o in
            guard let c = o.topCandidates(1).first else { return nil }
            return Line(text: c.string, box: o.boundingBox, obs: o, cand: c)
        }
    }
    let (boxes, rule) = blurBoxes(lines)
    let W = CGFloat(cg.width), H = CGFloat(cg.height)
    // pixel boxes, origin top-left: [x0, y0, x1, y1]
    let px = boxes.map { b -> [Int] in
        let c = b.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return [Int(c.minX * W), Int((1 - c.maxY) * H), Int(c.maxX * W), Int((1 - c.minY) * H)]
    }.filter { $0[2] > $0[0] && $0[3] > $0[1] }
    results[f] = ["rule": rule, "boxes": px]
    if let bdir = blurredDir {
        let ci = CIImage(cgImage: cg)
        var outImg = ci
        let pixel = ci.applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(12, W / 60)]).cropped(to: ci.extent)
        for b in px {
            let r = CGRect(x: CGFloat(b[0]), y: H - CGFloat(b[3]), width: CGFloat(b[2] - b[0]), height: CGFloat(b[3] - b[1]))
            outImg = pixel.cropped(to: r).composited(over: outImg)
        }
        let rep = NSBitmapImageRep(ciImage: outImg)
        if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? data.write(to: bdir.appendingPathComponent((f as NSString).deletingPathExtension + ".jpg"))
        }
    }
}
let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: args[2]))
print("done", results.count)
