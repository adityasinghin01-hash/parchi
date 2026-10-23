import UIKit
import XCTest
@testable import Parchi

/// K21 measurement runner (test photos only, never used to tune the reader). Skipped unless `/tmp/k21/run.json` exists, e.g.
/// `{"images": "/tmp/k21/img", "out": "/tmp/k21/out.json", "blurred": "/tmp/k21/blurred"}`.
/// Per photo: PIIBlur first (like the capture screen), then OnPhoneReader on the BLURRED image. Writes only to /tmp on the test Mac.
final class WebPhotoMeasureK21: XCTestCase {
    func testMeasureWebPhotos() async throws {
        guard let data = FileManager.default.contents(atPath: "/tmp/k21/run.json"),
              let cfg = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let dir = cfg["images"], let outPath = cfg["out"], let blurDir = cfg["blurred"] else { throw XCTSkip("no /tmp/k21/run.json") }
        try FileManager.default.createDirectory(atPath: blurDir, withIntermediateDirectories: true)
        let reader = OnPhoneReader(bundle: .main)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir)
            .filter { ["jpg", "jpeg", "png"].contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
        var out: [[String: Any]] = []
        for f in files {
            guard let image = UIImage(contentsOfFile: dir + "/" + f) else { continue }
            let id = (f as NSString).deletingPathExtension
            let t0 = Date()
            let blur = await PIIBlur.blurred(image)
            let t1 = Date()
            let result = await reader.read(blur.image)
            let t2 = Date()
            try? blur.image.pngData()?.write(to: URL(fileURLWithPath: blurDir + "/" + id + ".png"))
            out.append([
                "id": id, "size": "\(Int(image.size.width))x\(Int(image.size.height))", "rule": blur.rule, "boxes": blur.boxCount,
                "unchecked": blur.unchecked, "blurSec": t1.timeIntervalSince(t0), "readSec": t2.timeIntervalSince(t1),
                "needsHelp": result.needsHelp, "note": result.note,
                "lines": result.lines.map { [$0.kind ?? "", $0.name, $0.strength ?? ""].joined(separator: "|") },
            ])
        }
        try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted]).write(to: URL(fileURLWithPath: outPath))
        XCTAssertEqual(out.count, files.count)
    }
}
