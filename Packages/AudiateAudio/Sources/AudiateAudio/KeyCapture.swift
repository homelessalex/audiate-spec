import AppKit

/// Waits for one key press (Settings → "Change…") and reports it as a binding.
@MainActor
public final class KeyCapture {
    private var monitor: Any?

    public init() {}

    public func capture(_ done: @escaping @MainActor (KeyBinding) -> Void) {
        cancel()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let binding = KeyBinding(keyCode: event.keyCode, label: Self.label(for: event))
            MainActor.assumeIsolated {
                self?.cancel()
                done(binding)
            }
            return nil
        }
    }

    public func cancel() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    static func label(for event: NSEvent) -> String {
        switch event.keyCode {
        case 49: return "Space"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 36, 76: return "Return"
        default:
            let chars = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return chars.isEmpty ? "Key \(event.keyCode)" : chars.uppercased()
        }
    }
}
