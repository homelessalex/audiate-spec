import AudiateAudio
import Foundation
import SwiftData

/// Learner's tap offset per audio output device (headphones and speakers differ).
@Model
final class CalibrationProfile {
    @Attribute(.unique) var outputDeviceUID: String
    var inputOffsetMs: Double
    var date: Date

    init(outputDeviceUID: String, inputOffsetMs: Double, date: Date) {
        self.outputDeviceUID = outputDeviceUID
        self.inputOffsetMs = inputOffsetMs
        self.date = date
    }
}

extension ModelContext {
    func calibration(for deviceUID: String) -> CalibrationProfile? {
        let descriptor = FetchDescriptor<CalibrationProfile>(predicate: #Predicate { $0.outputDeviceUID == deviceUID })
        return (try? fetch(descriptor))?.first
    }

    /// Input offset in seconds for the current output, 0 if not calibrated.
    func inputOffset(for device: OutputDevice?) -> Double {
        device.flatMap { calibration(for: $0.uid) }.map { $0.inputOffsetMs / 1000 } ?? 0
    }

    func saveCalibration(deviceUID: String, inputOffset: Double, date: Date = .now) {
        if let existing = calibration(for: deviceUID) {
            existing.inputOffsetMs = inputOffset * 1000
            existing.date = date
        } else {
            insert(CalibrationProfile(outputDeviceUID: deviceUID, inputOffsetMs: inputOffset * 1000, date: date))
        }
        try? save()
    }
}
