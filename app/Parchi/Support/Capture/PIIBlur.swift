import CoreImage
import UIKit
import Vision

/// On-phone privacy blur: tries to find the patient's name, age, phone and address on a parchi photo with Apple Vision text boxes
/// plus rules, and pixelates what it finds BEFORE the image is stored or sent anywhere. Medicine lines are never blurred.
/// It is a best effort, not a guarantee: the user must look at the preview. When nothing at all was hidden the photo cannot be
/// used until the user ticks "I checked: no name, phone or address is visible" (`Decision`). With no readable text at all
/// (`rule == "no_text"`) the photo is never used.
/// Port of `privacy/pii_blur.swift`. Measured (docs/research/10-dataset-training-verification.md, not shown in the app): names hidden
/// on 98.3% of 300 synthetic parchis and 12/12 real photos; PHONES only 46.0% (23/50); 7.1% of medicine lines over-blurred.
enum PIIBlur {
    struct Result {
        let image: UIImage
        let rule: String
        let boxCount: Int
        /// Languages Vision could not check on this phone (e.g. "hi-IN" when Hindi recognition is not installed).
        let unchecked: [String]
        var decision: Decision { Decision(rule: rule, hiddenCount: boxCount, unchecked: unchecked) }
        /// False when there is no readable text or no image at all: the photo is never kept.
        var usable: Bool { decision.hasReadableText }
    }

    /// The rule that decides whether a blurred photo may be used. Pure data, so it is tested without Vision.
    struct Decision: Equatable {
        let rule: String
        let hiddenCount: Int
        let unchecked: [String]

        /// Some text was read and we have an image to show.
        var hasReadableText: Bool { rule != "no_text" && rule != "no_image" }
        /// Nothing was hidden: the user has to confirm by eye before the photo can be used.
        var needsUserCheck: Bool { hasReadableText && hiddenCount == 0 }
        /// "Use this photo" (and so any Live upload) is possible only when at least one area was hidden, or the user ticked the box.
        func canUse(userChecked: Bool) -> Bool { hasReadableText && (hiddenCount > 0 || userChecked) }
        /// Shown in the preview when a language could not be checked; nil when everything was checked.
        var languageWarning: String? {
            unchecked.contains("hi-IN") ? "Hindi text could not be checked on this phone." : (unchecked.isEmpty ? nil : "Some text could not be checked on this phone.")
        }
    }

    /// Runs the blur on a background task. Cancelling the CALLER cancels the render too (checked between the Vision and drawing steps),
    /// and the original image is released as soon as this call returns.
    static func blurred(_ source: UIImage) async -> Result {
        let task = Task.detached(priority: .userInitiated) { render(source) }
        return await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    struct Line { let text: String; let box: CGRect; let obs: VNRecognizedTextObservation; let cand: VNRecognizedText }

    static let medCue = try! NSRegularExpression(pattern: #"(?i)^\s*(\d+[\).]?\s*)?[-—–]?\s*(tab|tabs|cap|caps|syp|syr|syrup|inj|oint|gel|drops?|cream|lotion|t\.|c\.)\b|^\s*(\d+[\).]?\s*)?[-—–]?\s*(टैब|टेब|कैप|सिरप|इंज)"#)
    static let rxCue = try! NSRegularExpression(pattern: #"(?i)^\s*(rx|℞|r/x|adv\b|inv\b|investigations?)"#)
    static let nameLabel = try! NSRegularExpression(pattern: #"(?i)\b(patient'?s?\s*name|pt\.?\s*name|name|mr\.|mrs\.|ms\.|shri|smt\.?|baby|master)\s*[:\-.]?\s*|(रोगी\s*का\s*नाम|मरीज़?\s*का\s*नाम|नाम)\s*[:\-.]?\s*"#)
    static let ageLabel = try! NSRegularExpression(pattern: #"(?i)\b(age\s*/\s*sex|age|sex|उम्र|आयु)\s*[:\-.]?\s*"#)
    static let phoneLabel = try! NSRegularExpression(pattern: #"(?i)\b(mob(ile)?|phone|contact|cell|m\.?\s*no)\b\s*[:\-.]?\s*"#)
    static let addrLabel = try! NSRegularExpression(pattern: #"(?i)\b(address|addr|r/o|h\.?\s*no|vill(age)?|dist(t|rict)?|पता)\s*[:\-.]?\s*"#)
    static let otherLabel = try! NSRegularExpression(pattern: #"(?i)\b(age|sex|date|wt|weight|temp|bp|pulse|dt)\b"#)
    static let phone = try! NSRegularExpression(pattern: #"(?:\+91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}"#)
    static let ageValue = try! NSRegularExpression(pattern: #"(?i)\b\d{1,3}\s*(y|yr|yrs|years|y/m|y/f|m|f)\b|\b\d{1,3}\s*/\s*[mf]\b"#)
    static let letterhead = try! NSRegularExpression(pattern: #"(?i)(^\s*dr\b|^\s*dr\.|m\.?b\.?b\.?s|\breg\b|reg\.|clinic|hospital|nursing|centre|center|physician|specialist|consultant|surgeon|timing|m\.?d\b|d\.?n\.?b|d\.?c\.?h|d\.?g\.?o|polyclinic|emergency|डॉ|चिकित्स|अस्पताल|क्लिनिक|केन्द्र|केंद्र|समिति|समय)"#)

    static func has(_ r: NSRegularExpression, _ s: String) -> NSTextCheckingResult? {
        r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s))
    }

    /// Box of the text after a label inside one recognised line (Vision gives per-substring boxes).
    static func valueBox(_ l: Line, after m: NSTextCheckingResult) -> CGRect? {
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
    static func rightRegion(_ l: Line, labelEnd: CGFloat, lines: [Line], maxWidth: CGFloat) -> CGRect {
        let h = l.box.height
        var right = min(1, labelEnd + maxWidth)
        for o in lines where o.box.minX > labelEnd + 0.01 && abs(o.box.midY - l.box.midY) < h * 1.5 && has(otherLabel, o.text) != nil {
            right = min(right, o.box.minX - 0.005)
        }
        return CGRect(x: labelEnd, y: l.box.minY - h * 0.9, width: max(0.05, right - labelEnd), height: h * 2.8)
    }

    static func pad(_ r: CGRect, _ p: CGFloat = 0.01) -> CGRect { r.insetBy(dx: -p, dy: -p * 0.7) }

    static func blurBoxes(_ lines: [Line]) -> (boxes: [CGRect], rule: String) {
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


    // MARK: Vision + rendering (UIKit)

    private static func upright(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(at: .zero) }
    }

    private static func render(_ source: UIImage) -> Result {
        if Task.isCancelled { return Result(image: UIImage(), rule: "no_image", boxCount: 0, unchecked: []) }
        let image = upright(source)
        guard let cg = image.cgImage else { return Result(image: UIImage(), rule: "no_image", boxCount: 0, unchecked: []) }
        // Vision reads one script per request (the first language decides), so English and Hindi run separately.
        var lines: [Line] = []
        var unchecked: [String] = []
        for langs in [["en-US"], ["hi-IN"]] {
            if Task.isCancelled { return Result(image: UIImage(), rule: "no_image", boxCount: 0, unchecked: unchecked) }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let supported = Set((try? request.supportedRecognitionLanguages()) ?? [])
            guard langs.allSatisfy(supported.contains) else { unchecked += langs; continue }   // reported to the user, never skipped silently
            request.recognitionLanguages = langs
            do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request]) } catch { unchecked += langs; continue }
            lines += (request.results ?? []).compactMap { o in
                guard let c = o.topCandidates(1).first else { return nil }
                return Line(text: c.string, box: o.boundingBox, obs: o, cand: c)
            }
        }
        if Task.isCancelled { return Result(image: UIImage(), rule: "no_image", boxCount: 0, unchecked: unchecked) }
        let (boxes, rule) = blurBoxes(lines)
        let width = CGFloat(cg.width), height = CGFloat(cg.height)
        let pixelBoxes = boxes.map { b -> CGRect in
            let c = b.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            return CGRect(x: c.minX * width, y: c.minY * height, width: c.width * width, height: c.height * height)  // CIImage origin is bottom-left, like Vision
        }.filter { $0.width > 0 && $0.height > 0 }
        let ci = CIImage(cgImage: cg)
        let pixel = ci.applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(12, width / 60)]).cropped(to: ci.extent)
        var output = ci
        for r in pixelBoxes { output = pixel.cropped(to: r).composited(over: output) }
        guard !Task.isCancelled, let done = CIContext().createCGImage(output, from: ci.extent) else {
            return Result(image: UIImage(), rule: "no_image", boxCount: 0, unchecked: unchecked)
        }
        return Result(image: UIImage(cgImage: done), rule: rule, boxCount: pixelBoxes.count, unchecked: unchecked)
    }
}
