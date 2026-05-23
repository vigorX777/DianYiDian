import DianYiDianCore
import SwiftUI

struct StatusMenuScenarioRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let iconStyle: IconStyle
    let themeColor: ThemeColor
    let count: Int
    let target: Int
    let isSelected: Bool
}

struct StatusMenuScenarioData: Identifiable {
    let id: UUID
    let snapshot: CounterSnapshot
    let monthProgress: MonthProgress
    let lastCheckInText: String
}

struct StatusMenuView: View {
    let initialScenarioID: UUID
    let scenarioData: [StatusMenuScenarioData]
    let onIncrement: (UUID) -> Void
    let onUndo: (UUID) -> Void
    let onReset: (UUID) -> Void
    let onSelectScenario: (UUID) -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    @State private var selectedScenarioID: UUID

    init(
        initialScenarioID: UUID,
        scenarioData: [StatusMenuScenarioData],
        onIncrement: @escaping (UUID) -> Void,
        onUndo: @escaping (UUID) -> Void,
        onReset: @escaping (UUID) -> Void,
        onSelectScenario: @escaping (UUID) -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.initialScenarioID = initialScenarioID
        self.scenarioData = scenarioData
        self.onIncrement = onIncrement
        self.onUndo = onUndo
        self.onReset = onReset
        self.onSelectScenario = onSelectScenario
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self._selectedScenarioID = State(initialValue: initialScenarioID)
    }

    var body: some View {
        ZStack {
            StatusMenuBackdrop()

            VStack(alignment: .leading, spacing: 10) {
                header
                LiquidMonthCalendarView(monthProgress: currentData.monthProgress, themeColor: currentSnapshot.scenario.themeColor)

                if scenarioData.count > 1 {
                    scenarioSwitcher
                }

                actionBar
            }
            .padding(12)
        }
        .frame(width: 326)
    }

    private var currentData: StatusMenuScenarioData {
        scenarioData.first { $0.id == selectedScenarioID } ?? scenarioData[0]
    }

    private var currentSnapshot: CounterSnapshot {
        currentData.snapshot
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeColor(currentSnapshot.scenario.themeColor).opacity(0.22))
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                Image(systemName: currentSnapshot.scenario.iconStyle.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themeColor(currentSnapshot.scenario.themeColor))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(currentSnapshot.scenario.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(currentData.lastCheckInText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currentSnapshot.state.count)/\(currentSnapshot.scenario.dailyTarget)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("今日")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(menuPanelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var scenarioSwitcher: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("切换场景")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            ForEach(scenarioData) { scenarioData in
                let snapshot = scenarioData.snapshot
                let scenario = snapshot.scenario
                let isSelected = scenario.id == selectedScenarioID
                HStack(spacing: 9) {
                    Image(systemName: scenario.iconStyle.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .foregroundStyle(themeColor(scenario.themeColor))
                        .background(themeColor(scenario.themeColor).opacity(0.15), in: Circle())
                    Text(scenario.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(snapshot.state.count)/\(scenario.dailyTarget)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundStyle(themeColor(scenario.themeColor))
                    }
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.34) : Color.white.opacity(0.14))
                }
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard selectedScenarioID != scenario.id else {
                                return
                            }
                            selectedScenarioID = scenario.id
                            onSelectScenario(scenario.id)
                        }
                )
                .onTapGesture {
                    selectedScenarioID = scenario.id
                    onSelectScenario(scenario.id)
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    onIncrement(selectedScenarioID)
                } label: {
                    Label("打卡", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onUndo(selectedScenarioID)
                } label: {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .disabled(!currentSnapshot.state.hasUndoableIncrement || currentSnapshot.state.count == 0)

                Button {
                    onReset(selectedScenarioID)
                } label: {
                    Label("重置", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
            }

            HStack(spacing: 8) {
                Button(action: onOpenSettings) {
                    Label("设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                Button(role: .destructive, action: onQuit) {
                    Label("退出", systemImage: "power")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
            }
        }
        .controlSize(.regular)
    }

    private var menuPanelFill: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor).opacity(0.96)
    }

    private func themeColor(_ color: ThemeColor) -> Color {
        switch color {
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        case .pink: .pink
        case .gray: .gray
        }
    }
}

private struct LiquidMonthCalendarView: View {
    let monthProgress: MonthProgress
    let themeColor: ThemeColor

    private let cellWidth: CGFloat = 34
    private let cellHeight: CGFloat = 30
    private let columns = Array(repeating: GridItem(.fixed(34), spacing: 6), count: 7)
    private var menuPanelFill: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor).opacity(0.96)
    }

    var body: some View {
        VStack(spacing: 9) {
            Text(monthProgress.monthTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(monthProgress.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: cellWidth)
                }

                ForEach(0..<monthProgress.leadingBlankCount, id: \.self) { _ in
                    Color.clear.frame(width: cellWidth, height: cellHeight)
                }

                ForEach(monthProgress.days, id: \.dayID) { day in
                    dayCell(day)
                }
            }
        }
        .padding(12)
        .background(menuPanelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    private func dayCell(_ day: DayProgress) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(day.isFuture ? Color.white.opacity(0.18) : Color.white.opacity(0.26))

            if !day.isFuture, day.completionRatio > 0 {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color(for: day).opacity(0.86),
                                    color(for: day).opacity(0.54)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: max(3, cellHeight * CGFloat(day.completionRatio)))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Color.white.opacity(0.38))
                                .frame(height: 1)
                                .padding(.horizontal, 4)
                        }
                }
            }

            Text("\(day.dayNumber)")
                .font(.system(size: 11, weight: day.isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(day.isFuture ? Color.secondary.opacity(0.55) : Color.primary)
                .frame(width: cellWidth, height: cellHeight, alignment: .center)
        }
        .frame(width: cellWidth, height: cellHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(dayBorder(day), lineWidth: day.isToday ? 1.4 : 1)
        )
    }

    private func color(for day: DayProgress) -> Color {
        if day.completionRatio >= 1 {
            return .green
        }
        switch themeColor {
        case .blue: return .blue
        case .teal: return .teal
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }

    private func dayBorder(_ day: DayProgress) -> Color {
        if day.isToday {
            return color(for: day).opacity(0.85)
        }
        if day.hasRecord && day.completionRatio >= 1 {
            return Color.green.opacity(0.46)
        }
        return Color.white.opacity(0.18)
    }
}

private struct StatusMenuBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.97))
            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.accentColor.opacity(0.06),
                    Color.black.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
