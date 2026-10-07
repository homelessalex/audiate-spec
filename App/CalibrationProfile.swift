import AudiateAudio
import Foundation
import SwiftData

/// Learner's tap offset per audio output device (headphones and speakers differ) and input source.
@Model
final class CalibrationProfile {
    /// The output device's UID, plus `#midi` for the MIDI keyboard (computer keys use the bare UID).
    @Attribute(.unique) var outputDeviceUID: String
    var inputOffsetMs: Double
    var date: Date

    init(outputDeviceUID: String, inputOffsetMs: Double, date: Date) {
        self.outputDeviceUID = outputDeviceUID
        self.inputOffsetMs = inputOffsetMs
        self.date = date
    }

    static func key(deviceUID: String, source: InputSource) -> String {
        switch source {
        case .computer: deviceUID
        case .midi: deviceUID + "#midi"
        }
    }
}

extension ModelContext {
    func calibration(for deviceUID: String, source: InputSource = .computer) -> CalibrationProfile? {
        let key = CalibrationProfile.key(deviceUID: deviceUID, source: source)
        let descriptor = FetchDescriptor<CalibrationProfile>(predicate: #Predicate { $0.outputDeviceUID == key })
        return (try? fetch(descriptor))?.first
    }

    /// Input offsets in seconds for the current output. An uncalibrated MIDI keyboard borrows the
    /// computer's offset (the learner's own timing is most of it); 0 if nothing is calibrated.
    func inputOffsets(for device: OutputDevice?) -> InputOffsets {
        func offset(_ source: InputSource) -> Double? {
            device.flatMap { calibration(for: $0.uid, source: source) }.map { $0.inputOffsetMs / 1000 }
        }
        let computer = offset(.computer) ?? 0
        return InputOffsets(computer: computer, midi: offset(.midi) ?? computer)
    }

    func saveCalibration(deviceUID: String, source: InputSource, inputOffset: Double, date: Date = .now) {
        if let existing = calibration(for: deviceUID, source: source) {
            existing.inputOffsetMs = inputOffset * 1000
            existing.date = date
        } else {
            insert(CalibrationProfile(outputDeviceUID: CalibrationProfile.key(deviceUID: deviceUID, source: source),
                                      inputOffsetMs: inputOffset * 1000, date: date))
        }
        try? save()
    }
}
