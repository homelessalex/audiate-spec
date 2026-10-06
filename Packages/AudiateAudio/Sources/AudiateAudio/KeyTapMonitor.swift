import AppKit

/// Captures the tap keys of a `KeyMap` while an exercise is active and consumes them so they don't trigger UI.
@MainActor
public final class KeyTapMonitor {
    private var monitor: Any?

    public init() {}

    public var isRunning: Bool { monitor != nil }

    public func start(keyMap: KeyMap = .standard, _ handler: @escaping @MainActor (TapEvent) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            guard let key = keyMap.role(for: event.keyCode),
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            else { return event }
            if event.type == .keyDown, event.isARepeat { return nil }
            let tap = TapEvent(key: key, isDown: event.type == .keyDown, timestamp: event.timestamp)
            MainActor.assumeIsolated { handler(tap) }
            return nil
        }
    }

    public func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
