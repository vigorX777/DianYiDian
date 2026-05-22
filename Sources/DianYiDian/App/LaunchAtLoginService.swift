import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else {
                    return
                }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else {
                    return
                }
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
