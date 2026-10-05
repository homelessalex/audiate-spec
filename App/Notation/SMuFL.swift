import CoreText
import Foundation

/// Bravura glyphs used by the staff (SMuFL code points, docs/03-rhythm-model.md §4).
/// The font's em is 4 staff spaces, so a font of size 4·space draws at staff scale.
enum SMuFL {
    static let noteheadBlack: UInt32 = 0xE0A4
    static let noteheadHalf: UInt32 = 0xE0A3
    static let augmentationDot: UInt32 = 0xE1E7
    static let restHalf: UInt32 = 0xE4E4
    static let restQuarter: UInt32 = 0xE4E5
    static let rest8th: UInt32 = 0xE4E6
    static let rest16th: UInt32 = 0xE4E7
    static let flag8thUp: UInt32 = 0xE240
    static let flag16thUp: UInt32 = 0xE242
    static let tuplet3: UInt32 = 0xE883
    static func timeSigDigit(_ d: Int) -> UInt32 { 0xE080 + UInt32(d) }

    /// Notehead width in staff spaces (Bravura).
    static let noteheadWidth = 1.18

    /// Bravura at `size` points, loaded straight from the bundle (no registration needed for CoreText).
    static func font(size: CGFloat) -> CTFont? {
        guard let descriptor = descriptor else { return nil }
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    /// CTFontDescriptor is immutable, so sharing it across threads is safe.
    nonisolated(unsafe) private static let descriptor: CTFontDescriptor? = {
        guard let url = Bundle.main.url(forResource: "Bravura", withExtension: "otf"),
              let list = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return nil }
        return list.first
    }()
}
