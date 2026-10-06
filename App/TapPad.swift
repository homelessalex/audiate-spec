import AudiateAudio
import SwiftUI

/// Area to click with the mouse or trackpad instead of pressing Space.
struct TapPad: View {
    let recorder: TapRecorder

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(recorder.isRunning ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            Text(recorder.isRunning ? "Click here to tap (\(recorder.tapCount))" : "Tap pad: click here or press your tap key")
                .foregroundStyle(.secondary)
            TapPadRepresentable { recorder.tap($0) }
        }
        .frame(height: 110)
    }
}

private struct TapPadRepresentable: NSViewRepresentable {
    let onTap: @MainActor (TapEvent) -> Void

    func makeNSView(context: Context) -> TapPadNSView {
        let view = TapPadNSView()
        view.onTap = onTap
        return view
    }

    func updateNSView(_ view: TapPadNSView, context: Context) {
        view.onTap = onTap
    }
}
