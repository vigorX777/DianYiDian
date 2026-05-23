import DianYiDianCore
import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            LiquidBackdrop()

            VStack(spacing: 18) {
                header

                HStack(alignment: .top, spacing: 16) {
                    sidebar
                        .frame(width: 250)

                    ScrollView {
                        VStack(spacing: 14) {
                            appSettingsPanel
                            scenarioEditorPanel
                        }
                        .padding(.trailing, 2)
                    }
                    .scrollIndicators(.hidden)
                }

                footer
            }
            .padding(22)
        }
        .frame(minWidth: 900, minHeight: 640)
        .tint(accentColor)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("点一点")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("菜单栏里的轻量打卡")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            LiquidMetric(title: "场景", value: "\(viewModel.scenarios.count)")
            LiquidMetric(title: "目标", value: "\(viewModel.dailyTarget)")
        }
    }

    private var sidebar: some View {
        LiquidPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("场景")
                    .font(.headline)
                    .padding(.horizontal, 4)

                ForEach(viewModel.scenarios) { scenario in
                    Button {
                        withAnimation(.smooth(duration: 0.18)) {
                            viewModel.selectedScenarioID = scenario.id
                        }
                    } label: {
                        scenarioRow(scenario)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                Button {
                    viewModel.addScenario()
                } label: {
                    Label("新增场景", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func scenarioRow(_ scenario: CheckInScenario) -> some View {
        let isSelected = viewModel.selectedScenarioID == scenario.id

        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(themeColor(scenario.themeColor).opacity(isSelected ? 0.95 : 0.18))
                Image(systemName: scenario.iconStyle.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.white : themeColor(scenario.themeColor))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(scenario.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(scenario.isEnabled ? "启用" : "已停用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if scenario.isPinnedToMenuBar {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.58) : Color.white.opacity(0.16), lineWidth: 1)
                )
        }
    }

    private var appSettingsPanel: some View {
        LiquidPanel {
            VStack(alignment: .leading, spacing: 16) {
                PanelTitle(title: "应用设置", symbol: "switch.2")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                    Toggle("开机自启", isOn: $viewModel.launchAtLogin)
                    Toggle("打卡成功提示", isOn: $viewModel.showIncrementFeedback)
                    Toggle("达到每日目标时提醒", isOn: $viewModel.notifyWhenGoalReached)
                    Toggle("打卡动效", isOn: $viewModel.checkInAnimationEnabled)
                    Toggle("达标小庆祝", isOn: $viewModel.goalCelebrationEnabled)
                }

                Picker("菜单栏显示", selection: $viewModel.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("场景展示", selection: $viewModel.scenarioDisplayMode) {
                    ForEach(ScenarioDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if let shortcutWarning = viewModel.shortcutWarning {
                    WarningText(shortcutWarning)
                }
                if let notificationWarning = viewModel.notificationWarning {
                    WarningText(notificationWarning)
                }
            }
        }
    }

    private var scenarioEditorPanel: some View {
        LiquidPanel {
            VStack(alignment: .leading, spacing: 18) {
                PanelTitle(title: "场景设置", symbol: viewModel.iconStyle.symbolName)

                VStack(alignment: .leading, spacing: 6) {
                    Text("场景名称")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("场景名称", text: $viewModel.itemName)
                        .textFieldStyle(.roundedBorder)
                    if let validationMessage = viewModel.itemNameValidationMessage {
                        WarningText(validationMessage)
                    }
                }

                HStack(spacing: 18) {
                    Stepper("每日目标次数：\(viewModel.dailyTarget)", value: $viewModel.dailyTarget, in: 1...99)
                    Stepper("今日初始次数：\(viewModel.initialCount)", value: $viewModel.initialCount, in: 0...99)
                }

                Toggle("保存后应用到今日次数", isOn: $viewModel.applyInitialCountToToday)

                iconPicker
                colorPicker

                HStack(spacing: 18) {
                    Toggle("启用场景", isOn: $viewModel.isEnabled)
                    Toggle("固定到菜单栏", isOn: $viewModel.isPinnedToMenuBar)
                }

                reminderPanel

                HStack {
                    Button("停用场景") {
                        viewModel.deactivateSelectedScenario()
                    }
                    .disabled(viewModel.selectedScenario == nil || viewModel.selectedScenario?.isEnabled == false)
                    Spacer()
                }
            }
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("场景图标")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 7), spacing: 8) {
                ForEach(IconStyle.allCases, id: \.self) { style in
                    Button {
                        viewModel.iconStyle = style
                    } label: {
                        Image(systemName: style.symbolName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(viewModel.iconStyle == style ? Color.white : accentColor)
                            .frame(width: 40, height: 36)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(viewModel.iconStyle == style ? accentColor : Color.white.opacity(0.16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(viewModel.iconStyle == style ? 0.62 : 0.2), lineWidth: 1)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .help(style.displayName)
                }
            }
        }
    }

    private var colorPicker: some View {
        Picker("主题色", selection: $viewModel.themeColor) {
            ForEach(ThemeColor.allCases, id: \.self) { color in
                Text(color.displayName).tag(color)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var reminderPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("提醒")
                .font(.headline)
            Picker("提醒方式", selection: $viewModel.reminderMode) {
                ForEach(ReminderMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch viewModel.reminderMode {
            case .none:
                EmptyView()
            case .interval:
                numericInputRow(
                    title: "间隔分钟",
                    value: $viewModel.reminderIntervalMinutes,
                    range: 15...240,
                    suffix: "分钟"
                )
            case .fixedTime:
                HStack {
                    numericInputRow(
                        title: "小时",
                        value: $viewModel.reminderFixedHour,
                        range: 0...23,
                        suffix: "时"
                    )
                    numericInputRow(
                        title: "分钟",
                        value: $viewModel.reminderFixedMinute,
                        range: 0...59,
                        suffix: "分"
                    )
                }
            }

            Toggle("菜单栏轻提示", isOn: $viewModel.reminderMenuBarHintEnabled)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
    }

    private func numericInputRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        suffix: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 66)
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
                }
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if let message = viewModel.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(messageColor)
                    .lineLimit(2)
                    .transition(.opacity)
            }

            Spacer()

            Button {
                viewModel.addScenario()
            } label: {
                Label("新增场景", systemImage: "plus")
            }

            Button {
                viewModel.save()
            } label: {
                Label("保存", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )
        }
    }

    private var accentColor: Color {
        themeColor(viewModel.themeColor)
    }

    private var messageColor: Color {
        switch viewModel.messageKind {
        case .success:
            .secondary
        case .warning:
            .orange
        case .error:
            .red
        }
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

private struct LiquidBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.20),
                    Color.white.opacity(0.10),
                    Color.cyan.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.34), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

private struct LiquidPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.52), Color.white.opacity(0.14)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
            }
    }
}

private struct PanelTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

private struct LiquidMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct WarningText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.orange)
    }
}
