import SwiftUI

/// First launch: four short pages on what the app trains and how a session runs.
struct IntroductionView: View {
    let done: () -> Void
    @State private var page = 0

    private let pages: [(title: String, text: String)] = [
        ("Hear it before you read it",
         "Audiate trains audiation: hearing rhythm in your head and understanding where each sound falls in the pulse. You learn every pattern by ear first; notation comes once the unit is solid by ear."),
        ("Listen · hold · tap",
         "After a count-in you hear a pattern on a hi-hat. One silent measure: hold it in your head. Then tap it back with Space, J or a click on the pad. The metronome never stops — the next count-in shows ✓ or ✗ and what went wrong."),
        ("A level takes two days",
         "A level counts once every pattern has been right on two different days — sleep consolidates the skill. When today's work is done you can keep practicing freely; that doesn't count, but it all helps."),
        ("Calibrate first",
         "Tap along with 16 clicks once, so the app knows your device's delay. Use wired headphones or the speakers; Bluetooth adds a lot of latency. Settings (⌘,) has two-hand mode and the session length."),
    ]

    var body: some View {
        VStack(spacing: 22) {
            Text(pages[page].title).font(.largeTitle.bold())
            Text(pages[page].text).font(.title3).multilineTextAlignment(.center).frame(maxWidth: 520)
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Circle().fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
                }
            }
            HStack {
                if page > 0 { Button("Back") { page -= 1 } }
                Button(page == pages.count - 1 ? "Start" : "Next") {
                    if page == pages.count - 1 { done() } else { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(width: 640, height: 400)
    }
}
