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

struct StatusMenuView: View {
    let snapshot: CounterSnapshot
    let monthProgress: MonthProgress
    let lastCheckInText: String
    let scenarios: [StatusMenuScenarioRow]
    let onIncrement: () -> Void
    let onUndo: () -> Void
    let onReset: () -> Void
    let onSelectScenario: (UUID) -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            StatusMenuBackdrop()

            VStack(alignment: .leading, spacing: 14) {
                header
                LiquidMonthCalendarView(monthProgress: monthProgress, themeColor: snapshot.scenario.themeColor)

                if scenarios.count > 1 {
                    scenarioSwitcher
                }

                actionBar
            }
            .padding(16)
        }
        .frame(width: 318)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeColor(snapshot.scenario.themeColor).opacity(0.22))
                    .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
                Image(systemName: snapshot.scenario.iconStyle.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themeColor(snapshot.scenario.themeColor))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.scenario.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(lastCheckInText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(snapshot.state.count)/\(snapshot.scenario.dailyTarget)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("今日")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var scenarioSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("切换场景")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            ForEach(scenarios) { scenario in
                Button {
                    onSelectScenario(scenario.id)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: scenario.iconStyle.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .foregroundStyle(themeColor(scenario.themeColor))
                            .background(themeColor(scenario.themeColor).opacity(0.15), in: Circle())
                        Text(scenario.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(scenario.count)/\(scenario.target)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        if scenario.isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(themeColor(scenario.themeColor))
                        }
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(scenario.isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.07))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Button(action: onIncrement) {
                    Label("打卡", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onUndo) {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!snapshot.state.hasUndoableIncrement || snapshot.state.count == 0)

                Button(action: onReset) {
                    Label("重置", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 8) {
                Button(action: onOpenSettings) {
                    Label("设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                Button(role: .destructive, action: onQuit) {
                    Label("退出", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .controlSize(.small)
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

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 7), count: 7)

    var body: some View {
        VStack(spacing: 9) {
            Text(monthProgress.monthTitle)
                .font(.system(size: 13, weight: .semibold))

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(monthProgress.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 32)
                }

                ForEach(0..<monthProgress.leadingBlankCount, id: \.self) { _ in
                    Color.clear.frame(width: 32, height: 30)
                }

                ForEach(monthProgress.days, id: \.dayID) { day in
                    dayCell(day)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    private func dayCell(_ day: DayProgress) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(day.isFuture ? Color.white.opacity(0.08) : Color.white.opacity(0.14))

            if !day.isFuture, day.completionRatio > 0 {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                color(for: day).opacity(0.75),
                                color(for: day).opacity(0.42)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: max(2, 30 * CGFloat(day.completionRatio)))
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.30))
                            .frame(height: 1)
                            .padding(.horizontal, 4)
                    }
            }

            Text("\(day.dayNumber)")
                .font(.system(size: 10, weight: day.isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(day.isFuture ? Color.secondary.opacity(0.55) : Color.primary)
        }
        .frame(width: 32, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
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
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.34),
                    Color.accentColor.opacity(0.10),
                    Color.black.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
