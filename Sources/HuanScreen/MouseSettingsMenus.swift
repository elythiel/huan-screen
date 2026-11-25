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
        menus = [dpiMenu(), pollingRateMenu(), liftOffDistanceMenu()]
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
                self?.apply(then: { $0.activeDPIStage = stage }) { receiver, info in
                    await receiver.selectDPIStage(stage, profile: info.profile)
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
                self?.apply(then: { $0.pollingRate = rate }) { receiver, info in
                    await receiver.selectPollingRate(rate, profile: info.profile)
                }
            }
        )
    }

    private func liftOffDistanceMenu() -> SettingMenu {
        SettingMenu(
            name: localized("Lift-off Distance"),
            symbol: "arrow.up.and.down",
            currentValue: { [weak self] in self?.mouseInfo()?.liftOffDistance.map(MouseInfo.format) },
            options: { [weak self] in
                guard let info = self?.mouseInfo() else { return [] }
                return MouseInfo.supportedLiftOffDistances.map { distance in
                    SettingOption(title: MouseInfo.format(liftOffDistance: distance), value: Int(distance * 10), isSelected: info.liftOffDistance == distance)
                }
            },
            onSelect: { [weak self] tenths in
                let distance = Double(tenths) / 10
                self?.apply(then: { $0.liftOffDistance = distance }) { receiver, info in
                    await receiver.selectLiftOffDistance(distance, mode: info.liftOffMode, profile: info.profile)
                }
            }
        )
    }

    private func apply(then change: @escaping (inout MouseInfo) -> Void, _ write: @escaping (Receiver, MouseInfo) async -> Bool) {
        guard let info = mouseInfo() else { return }
        Task {
            guard await write(receiver, info), var latest = mouseInfo() else { return }
            change(&latest)
            onUpdate(latest)
        }
    }
}
