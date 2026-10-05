import AppKit
import AudiateCore
import SwiftUI

/// Every library pattern on one sheet, for visual review of the engraving (docs/06 M3).
/// Launch with `-AudiateContactSheet /path/sheet.png` to write it and quit.
struct ContactSheet: View {
    let library: PatternLibrary

    var body: some View {
        let deriver = SyllableDeriver()
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(460), alignment: .leading), count: 3), alignment: .leading, spacing: 18) {
            ForEach(library.patterns) { p in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(p.id)  \(p.meter.timeSignature.description)  \(p.content.rawValue)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    RhythmStaffView(pattern: p, zoom: 1.5, syllables: (try? deriver.displays(for: p)))
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    @MainActor
    static func export(library: PatternLibrary, to path: String) {
        let renderer = ImageRenderer(content: ContactSheet(library: library))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            print("contact sheet: render failed")
            return
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("contact sheet: wrote \(path)")
        } catch {
            print("contact sheet: \(error)")
        }
    }
}
