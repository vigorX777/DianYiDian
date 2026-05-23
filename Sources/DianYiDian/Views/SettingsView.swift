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
                            developerSettingsPanel
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

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        settingRow("开机自启") {
                            Toggle("", isOn: $viewModel.launchAtLogin).labelsHidden()
                        }
                        settingRow("打卡提示") {
                            Toggle("", isOn: $viewModel.showIncrementFeedback).labelsHidden()
                        }
                    }
                    GridRow {
                        settingRow("达标提醒") {
                            Toggle("", isOn: $viewModel.notifyWhenGoalReached).labelsHidden()
                        }
                        settingRow("打卡动效") {
                            Toggle("", isOn: $viewModel.checkInAnimationEnabled).labelsHidden()
                        }
                    }
                    GridRow {
                        settingRow("达标庆祝") {
                            Toggle("", isOn: $viewModel.goalCelebrationEnabled).labelsHidden()
                        }
                        settingRow("系统通知") {
                            Toggle("", isOn: $viewModel.reminderSystemNotificationEnabled).labelsHidden()
                        }
                    }
                    GridRow {
                        settingRow("菜单气泡") {
                            Toggle("", isOn: $viewModel.reminderMenuBarBubbleEnabled).labelsHidden()
                        }
                        Color.clear.frame(height: 1)
                    }
                }

                settingRow("菜单栏显示", labelWidth: 96) {
                    Picker("", selection: $viewModel.menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                settingRow("场景展示", labelWidth: 96) {
                    Picker("", selection: $viewModel.scenarioDisplayMode) {
                        ForEach(ScenarioDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                if let shortcutWarning = viewModel.shortcutWarning {
                    WarningText(shortcutWarning)
                }
                if let notificationWarning = viewModel.notificationWarning {
                    WarningText(notificationWarning)
                }
            }
        }
    }

    private var developerSettingsPanel: some View {
        LiquidPanel {
            VStack(alignment: .leading, spacing: 14) {
                PanelTitle(title: "开发者配置", symbol: "hammer")

                settingRow("气泡时长") {
                    HStack(spacing: 8) {
                        TextField("", value: $viewModel.developerReminderBubbleDurationSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .onChange(of: viewModel.developerReminderBubbleDurationSeconds) { _, newValue in
                                viewModel.developerReminderBubbleDurationSeconds = min(max(newValue, 0.5), 10)
                            }
                        Text("秒")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }

                Text("用于菜单栏轻提醒的展示时长，仅供开发和调试使用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scenarioEditorPanel: some View {
        LiquidPanel {
            VStack(alignment: .leading, spacing: 18) {
                PanelTitle(title: "场景设置", symbol: viewModel.iconStyle.symbolName)

                settingRow("场景名称") {
                    TextField("场景名称", text: $viewModel.itemName)
                        .textFieldStyle(.roundedBorder)
                }
                if let validationMessage = viewModel.itemNameValidationMessage {
                    settingRow("") {
                        WarningText(validationMessage)
                    }
                }

                HStack(spacing: 18) {
                    settingRow("每日目标") {
                        Stepper("\(viewModel.dailyTarget)", value: $viewModel.dailyTarget, in: 1...99)
                    }
                    settingRow("今日初始") {
                        Stepper("\(viewModel.initialCount)", value: $viewModel.initialCount, in: 0...99)
                    }
                }

                settingRow("应用到今日") {
                    Toggle("", isOn: $viewModel.applyInitialCountToToday).labelsHidden()
                }

                settingRow("场景图标", alignment: .top) {
                    iconPicker
                }

                settingRow("主题色") {
                    colorPicker
                }

                HStack(spacing: 18) {
                    settingRow("启用场景") {
                        Toggle("", isOn: $viewModel.isEnabled).labelsHidden()
                    }
                    settingRow("固定菜单栏") {
                        Toggle("", isOn: $viewModel.isPinnedToMenuBar).labelsHidden()
                    }
                }

                settingRow("提醒", alignment: .top) {
                    reminderPanel
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
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    minimum: 1,
                    suffix: "分钟"
                )
            case .fixedTime:
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.reminderFixedTimes.indices, id: \.self) { index in
                        fixedReminderTimeRow(index: index)
                    }

                    Button {
                        viewModel.addFixedReminderTime()
                    } label: {
                        Label("增加时间", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
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
        minimum: Int,
        maximum: Int? = nil,
        suffix: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 66)
                .onChange(of: value.wrappedValue) { _, newValue in
                    let lowerBounded = max(newValue, minimum)
                    value.wrappedValue = maximum.map { min(lowerBounded, $0) } ?? lowerBounded
                }
            Text(suffix)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func fixedReminderTimeRow(index: Int) -> some View {
        HStack(spacing: 8) {
            Text("时间 \(index + 1)")
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            TextField("", value: $viewModel.reminderFixedTimes[index].hour, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .onChange(of: viewModel.reminderFixedTimes[index].hour) { _, newValue in
                    viewModel.reminderFixedTimes[index].hour = min(max(newValue, 0), 23)
                }
            Text("时")
                .foregroundStyle(.secondary)
            TextField("", value: $viewModel.reminderFixedTimes[index].minute, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .onChange(of: viewModel.reminderFixedTimes[index].minute) { _, newValue in
                    viewModel.reminderFixedTimes[index].minute = min(max(newValue, 0), 59)
                }
            Text("分")
                .foregroundStyle(.secondary)
            Button {
                viewModel.removeFixedReminderTime(at: index)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.reminderFixedTimes.count <= 1)
            Spacer(minLength: 0)
        }
    }

    private func settingRow<Content: View>(
        _ title: String,
        labelWidth: CGFloat = 104,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: alignment, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
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
