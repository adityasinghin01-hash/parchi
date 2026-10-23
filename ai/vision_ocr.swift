// Runs Apple Vision text recognition over every image in a folder.
// Usage: swift vision_ocr.swift <imageDir> <out.json> [customWords.txt]
import Foundation
import Vision
import AppKit

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
var customWords: [String] = []
if args.count > 3, let s = try? String(contentsOfFile: args[3], encoding: .utf8) {
    customWords = s.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
}

let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    .filter { ["png", "jpg", "jpeg"].contains(($0 as NSString).pathExtension.lowercased()) }
    .sorted()

var results: [String: [[String: Any]]] = [:]
let start = Date()
for f in files {
    let url = dir.appendingPathComponent(f)
    guard let img = NSImage(contentsOf: url),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["en-US"]
    req.usesLanguageCorrection = true
    if !customWords.isEmpty { req.customWords = customWords }
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([req])
    var lines: [[String: Any]] = []
    for obs in req.results ?? [] {
        let cands = obs.topCandidates(3)
        guard let top = cands.first else { continue }
        lines.append([
            "text": top.string,
            "conf": top.confidence,
            "alts": cands.dropFirst().map { $0.string },
            "box": [obs.boundingBox.minX, obs.boundingBox.minY, obs.boundingBox.width, obs.boundingBox.height]
        ])
    }
    results[f] = lines
}
let elapsed = Date().timeIntervalSince(start)
let data = try JSONSerialization.data(withJSONObject: ["elapsed_s": elapsed, "count": files.count, "results": results], options: [.prettyPrinted])
try data.write(to: outURL)
print("done \(files.count) images in \(String(format: "%.1f", elapsed)) s")
