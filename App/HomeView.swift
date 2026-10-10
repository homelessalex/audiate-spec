import AudiateCore
import SwiftUI

/// Today's session and the curriculum grid (units × levels).
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let content = model.content {
            // reading `today` makes this view refresh when a new day starts
            let _ = model.today
            let plan = model.planSession()
            let hasWork = plan?.isEmpty == false
            let canPractice = model.planFreePractice()?.isEmpty == false
            let due = model.progress.dueItems(on: model.now()).count
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Audiate").font(.largeTitle.bold())
                    Spacer()
                    Button("Pulse trainer") { model.openPulseTrainer() }
                    Button("Calibrate…") { openWindow(id: WindowID.calibration) }
                    if model.dayOffset != 0 { Text("Day offset +\(model.dayOffset)").foregroundStyle(.orange) }
                }

                HStack(spacing: 16) {
                    Button {
                        model.startSession(freePractice: !hasWork)
                    } label: {
                        Text(hasWork ? "Start today's session" : (canPractice ? "Free practice" : "Nothing to practice yet"))
                            .frame(minWidth: 260)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasWork && !canPractice)
                    VStack(alignment: .leading) {
                        if let plan, hasWork {
                            Text("Learning: " + plan.frontiers.map { "\($0.unitID) \(Self.levelName($0.level))" }.joined(separator: ", "))
                            Text("about \(Int((plan.estimatedSeconds / 60).rounded(.up))) min").foregroundStyle(.secondary)
                        } else {
                            Text("Today's work is done — free practice doesn't count toward passing a level.")
                                .foregroundStyle(.secondary)
                        }
                        Text("Due reviews: \(due)").foregroundStyle(.secondary)
                    }
                }

                ProgressGrid(curriculum: content.curriculum, progress: model.progress)
                PhraseTrackRow()
            }
            .padding(28)
        }
    }

    static func levelName(_ level: SkillLevel) -> String {
        switch level {
        case .aural: "AO · echo by ear"
        case .verbal: "VA · notation"
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

/// The phrase track (E13): where the learner is on the ladder, and a way straight in.
private struct PhraseTrackRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let planner = model.planner {
            let open = planner.isPhraseTrackOpen(model.progress)
            let rung = PhraseLadder.rung(after: model.progress.attempts)
            let step = PhrasePolicy.rungs[rung]
            let left = planner.phrasesLeftToday(model.progress, date: model.now())
            HStack(spacing: 16) {
                Button("Read phrases") { model.startSession(phrasesOnly: true) }
                    .disabled(!open)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phrase reading (E13)").font(.headline)
                    if open {
                        Text("Step \(rung + 1) of \(PhrasePolicy.rungs.count): \(step.measures) measures at \(Int(step.tempoFactor * 100)) % tempo"
                             + (left > 0 ? " · \(left) of \(PhrasePolicy.maxPhrasesPerDay) graded left today" : " · today's are done: practice, as long as you like"))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Opens once a unit has passed CS.").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
