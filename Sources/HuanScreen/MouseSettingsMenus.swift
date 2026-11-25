import AppKit

@MainActor
final class MouseSettingsMenus {
    private let receiver: Receiver
    private let mouseInfo: () -> MouseInfo?
    private let onUpdate: (MouseInfo) -> Void
    private let separator = NSMenuItem.separator()
    private var menus: [SettingMenu] = []

    var items: [NSMenuItem] { menus.map(\.item) + [separator] }

    init(receiver: Receiver, mouseInfo: @escaping () -> MouseInfo?, onUpdate: @escaping (MouseInfo) -> Void) {
        self.receiver = receiver
        self.mouseInfo = mouseInfo
        self.onUpdate = onUpdate
        menus = [dpiMenu(), pollingRateMenu()]
        update()
    }

    func update() {
        for menu in menus { menu.update() }
        separator.isHidden = menus.allSatisfy(\.item.isHidden)
    }

    private func dpiMenu() -> SettingMenu {
        SettingMenu(
            name: "DPI",
            symbol: "scope",
            currentValue: { [weak self] in self?.mouseInfo()?.dpi.map(String.init) },
            options: { [weak self] in
                guard let info = self?.mouseInfo() else { return [] }
                return info.dpiStages.enumerated().map { index, dpi in
                    SettingOption(title: "\(dpi) DPI", value: index + 1, isSelected: info.activeDPIStage == index + 1)
                }
            },
            onSelect: { [weak self] stage in
                self?.apply { info in
                    guard self?.receiver.selectDPIStage(stage, profile: info.profile) == true else { return false }
                    info.activeDPIStage = stage
                    return true
                }
            }
        )
    }

    private func pollingRateMenu() -> SettingMenu {
        SettingMenu(
            name: localized("Polling Rate"),
            symbol: "waveform.path",
            currentValue: { [weak self] in self?.mouseInfo()?.pollingRate.map { "\($0) Hz" } },
            options: { [weak self] in
                guard let info = self?.mouseInfo() else { return [] }
                return MouseInfo.supportedPollingRates.map { rate in
                    SettingOption(title: "\(rate) Hz", value: rate, isSelected: info.pollingRate == rate)
                }
            },
            onSelect: { [weak self] rate in
                self?.apply { info in
                    guard self?.receiver.selectPollingRate(rate, profile: info.profile) == true else { return false }
                    info.pollingRate = rate
                    return true
                }
            }
        )
    }

    private func apply(_ change: (inout MouseInfo) -> Bool) {
        guard var info = mouseInfo(), change(&info) else { return }
        onUpdate(info)
    }
}
