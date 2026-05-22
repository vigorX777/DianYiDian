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
                }

                Section("事项设置") {
                    TextField("事项名称", text: $viewModel.itemName)
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
                        .foregroundStyle(message == "已保存" ? Color.secondary : Color.orange)
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
}
