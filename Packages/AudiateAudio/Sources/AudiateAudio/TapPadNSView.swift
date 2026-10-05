import AppKit

/// Click target for the exercise area: mouse / trackpad presses are taps (docs/05-architecture.md §4).
/// Uses the event's own timestamp, the same clock as key taps.
public final class TapPadNSView: NSView {
    public var onTap: (@MainActor (TapEvent) -> Void)?

    /// Count the first click even when the window isn't key yet.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public override func mouseDown(with event: NSEvent) {
        onTap?(TapEvent(key: .pointer, isDown: true, timestamp: event.timestamp))
    }

    public override func mouseUp(with event: NSEvent) {
        onTap?(TapEvent(key: .pointer, isDown: false, timestamp: event.timestamp))
    }
}
