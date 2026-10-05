import AudiateCore
import SwiftUI

/// Today's session and the curriculum grid (units × levels).
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let content = model.content {
            let plan = model.planSession()
            let due = model.progress.dueItems(on: model.now()).count
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Audiate").font(.largeTitle.bold())
                    Spacer()
                    Button("Calibrate…") { openWindow(id: WindowID.calibration) }
                    if model.dayOffset != 0 { Text("Day offset +\(model.dayOffset)").foregroundStyle(.orange) }
                }

                HStack(spacing: 16) {
                    Button {
                        model.startSession()
                    } label: {
                        Text(plan?.isEmpty == false ? "Start today's session" : "Nothing to practice now — come back tomorrow")
                            .frame(minWidth: 260)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(plan?.isEmpty != false)
                    VStack(alignment: .leading) {
                        if let plan, let frontier = plan.frontier {
                            Text("Learning: \(frontier.unitID) \(Self.levelName(frontier.level))")
                            Text("about \(Int((plan.estimatedSeconds / 60).rounded(.up))) min").foregroundStyle(.secondary)
                        }
                        Text("Due reviews: \(due)").foregroundStyle(.secondary)
                    }
                }

                ProgressGrid(curriculum: content.curriculum, progress: model.progress)
            }
            .padding(28)
        }
    }

    static func levelName(_ level: SkillLevel) -> String {
        switch level {
        case .aural: "AO · echo by ear"
        case .verbal: "VA · syllables"
        case .symbolic: "SA · reading"
        default: level.code
        }
    }
}

private struct ProgressGrid: View {
    let curriculum: Curriculum
    let progress: LearnerProgress

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Text("")
                ForEach(SkillLevel.allCases, id: \.self) { Text($0.code).font(.caption.monospaced()).frame(width: 34) }
            }
            ForEach(curriculum.units) { unit in
                GridRow {
                    Text("\(unit.id)  \(unit.title)").font(.callout).lineLimit(1).frame(width: 240, alignment: .leading)
                    ForEach(SkillLevel.allCases, id: \.self) { level in
                        let status = progress.status(of: LevelKey(unitID: unit.id, level: level), curriculum: curriculum)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Self.color(status))
                            .frame(width: 34, height: 18)
                            .help("\(unit.id) \(level.code): \(status.rawValue)")
                    }
                }
            }
            GridRow {
                Text("")
                HStack(spacing: 12) {
                    ForEach([LevelStatus.locked, .available, .inProgress, .passed], id: \.self) { s in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3).fill(Self.color(s)).frame(width: 12, height: 12)
                            Text(s.rawValue).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .gridCellColumns(SkillLevel.allCases.count)
            }
        }
    }

    static func color(_ status: LevelStatus) -> Color {
        switch status {
        case .locked: Color.secondary.opacity(0.12)
        case .available: Color.accentColor.opacity(0.35)
        case .inProgress: Color.orange.opacity(0.7)
        case .passed: Color.green.opacity(0.75)
        }
    }
}
