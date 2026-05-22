import DianYiDianCore
import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Form {
                Section("应用设置") {
                    Toggle("开机自启", isOn: $viewModel.launchAtLogin)
                    Toggle("打卡成功提示", isOn: $viewModel.showIncrementFeedback)
                    Toggle("达到每日目标时提醒", isOn: $viewModel.notifyWhenGoalReached)

                    Picker("菜单栏显示", selection: $viewModel.menuBarDisplayMode) {
                        ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("事项设置") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("事项名称", text: $viewModel.itemName)
                        if let validationMessage = viewModel.itemNameValidationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(Color.orange)
                        }
                    }
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
                    Toggle("保存后应用到今日次数", isOn: $viewModel.applyInitialCountToToday)

                    Picker("图标样式", selection: $viewModel.iconStyle) {
                        ForEach(IconStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
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
                Button("保存") {
                    viewModel.save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 430)
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
}
