import DianYiDianCore
import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                Section("应用设置") {
                    Toggle("开机自启", isOn: $viewModel.launchAtLogin)
                    Toggle("打卡成功提示", isOn: $viewModel.showIncrementFeedback)
                    Toggle("达到每日目标时提醒", isOn: $viewModel.notifyWhenGoalReached)
                    Toggle("打卡动效", isOn: $viewModel.checkInAnimationEnabled)
                    Toggle("达标小庆祝", isOn: $viewModel.goalCelebrationEnabled)

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
                        Text(shortcutWarning)
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    }
                    if let notificationWarning = viewModel.notificationWarning {
                        Text(notificationWarning)
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    }
                }

                Section("场景管理") {
                    HStack(alignment: .top, spacing: 14) {
                        scenarioList
                            .frame(width: 240)
                            .frame(minHeight: 320)
                        Divider()
                        scenarioEditor
                            .frame(minWidth: 420)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if let message = viewModel.message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(messageColor)
                        .lineLimit(2)
                }
                Spacer()
                Button("新增场景") {
                    viewModel.addScenario()
                }
                Button("保存") {
                    viewModel.save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 560)
    }

    private var scenarioList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.scenarios) { scenario in
                Button {
                    viewModel.selectedScenarioID = scenario.id
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: scenario.iconStyle.symbolName)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(themeColor(scenario.themeColor))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.name)
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
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.selectedScenarioID == scenario.id ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var scenarioEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("场景名称", text: $viewModel.itemName)
                if let validationMessage = viewModel.itemNameValidationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }

            HStack {
                Stepper(
                    "每日目标次数：\(viewModel.dailyTarget)",
                    value: $viewModel.dailyTarget,
                    in: 1...99
                )
                Stepper(
                    "今日初始次数：\(viewModel.initialCount)",
                    value: $viewModel.initialCount,
                    in: 0...99
                )
            }

            Toggle("保存后应用到今日次数", isOn: $viewModel.applyInitialCountToToday)

            VStack(alignment: .leading, spacing: 8) {
                Text("场景图标")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(42), spacing: 8), count: 7), spacing: 8) {
                    ForEach(IconStyle.allCases, id: \.self) { style in
                        Button {
                            viewModel.iconStyle = style
                        } label: {
                            Image(systemName: style.symbolName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(viewModel.iconStyle == style ? Color.white : themeColor(viewModel.themeColor))
                                .frame(width: 36, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(viewModel.iconStyle == style ? themeColor(viewModel.themeColor) : Color.secondary.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .help(style.displayName)
                    }
                }
            }

            Picker("主题色", selection: $viewModel.themeColor) {
                ForEach(ThemeColor.allCases, id: \.self) { color in
                    Text(color.displayName).tag(color)
                }
            }
            .pickerStyle(.segmented)

            Toggle("启用场景", isOn: $viewModel.isEnabled)
            Toggle("固定到菜单栏", isOn: $viewModel.isPinnedToMenuBar)

            VStack(alignment: .leading, spacing: 8) {
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
                    Stepper(
                        "间隔分钟：\(viewModel.reminderIntervalMinutes)",
                        value: $viewModel.reminderIntervalMinutes,
                        in: 15...240,
                        step: 15
                    )
                case .fixedTime:
                    HStack {
                        Stepper(
                            "小时：\(String(format: "%02d", viewModel.reminderFixedHour))",
                            value: $viewModel.reminderFixedHour,
                            in: 0...23
                        )
                        Stepper(
                            "分钟：\(String(format: "%02d", viewModel.reminderFixedMinute))",
                            value: $viewModel.reminderFixedMinute,
                            in: 0...59
                        )
                    }
                }

                Toggle("菜单栏轻提示", isOn: $viewModel.reminderMenuBarHintEnabled)
            }

            HStack {
                Button("停用场景") {
                    viewModel.deactivateSelectedScenario()
                }
                .disabled(viewModel.selectedScenario == nil || viewModel.selectedScenario?.isEnabled == false)
                Spacer()
            }
        }
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
