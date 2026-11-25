import Foundation
import IOKit.hid

enum ScreenMode {
    case cat
    case status

    var toggled: ScreenMode { self == .cat ? .status : .cat }
}

@MainActor
final class Receiver {
    private static let vendorID = 0x36A7
    private static let productID = 0xA863
    private static let vendorUsagePage = 0xFFFF
    private static let dongle: UInt8 = 0x00
    private static let screenDelay: useconds_t = 30_000

    var onConnectionChange: (() -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var device: IOHIDDevice?
    private var channel: HIDChannel?

    var isConnected: Bool { channel != nil }

    init() {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDProductIDKey: Self.productID,
            kIOHIDPrimaryUsagePageKey: Self.vendorUsagePage,
        ] as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        attachFirstAvailableDevice()
    }

    func watchConnections() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            let receiver = Unmanaged<Receiver>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { receiver.attach(device) }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let receiver = Unmanaged<Receiver>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { receiver.detach(device) }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    func readMode() async -> ScreenMode? {
        await sendScreenCommand(0x8A).map { $0 == 0 ? .cat : .status }
    }

    func readMouseInfo() async -> MouseInfo? {
        await perform(MouseInfo.read)
    }

    func readFirmware() async -> InstalledFirmware? {
        await perform(InstalledFirmware.read)
    }

    @discardableResult
    func setMode(_ mode: ScreenMode) async -> Bool {
        await sendScreenCommand(0x0A, value: mode == .status ? 1 : 0) != nil
    }

    @discardableResult
    func selectDPIStage(_ stage: Int, profile: UInt8) async -> Bool {
        let request = HIDRequest(target: MouseInfo.mouse, length: 2, group: 1, command: 0x02, parameters: [profile, UInt8(stage)])
        return await send(request, delay: MouseInfo.delay) != nil
    }

    @discardableResult
    func selectPollingRate(_ rate: Int, profile: UInt8) async -> Bool {
        guard let code = MouseInfo.pollingRateCodes[rate] else { return false }
        let request = HIDRequest(target: MouseInfo.mouse, length: 2, group: 1, command: 0x00, parameters: [profile, code])
        return await send(request, delay: MouseInfo.delay) != nil
    }

    @discardableResult
    func selectLiftOffDistance(_ distance: Double, mode: UInt8, profile: UInt8) async -> Bool {
        let value = MouseInfo.encodeLiftOffDistance(distance)
        let request = HIDRequest(target: MouseInfo.mouse, length: 3, group: 1, command: 0x08, parameters: [profile, value, mode])
        return await send(request, delay: MouseInfo.delay) != nil
    }

    private func sendScreenCommand(_ command: UInt8, value: UInt8 = 0) async -> UInt8? {
        let request = HIDRequest(target: Self.dongle, length: 1, group: 5, command: command, parameters: [value])
        return await send(request, delay: Self.screenDelay)?[0]
    }

    private func send(_ request: HIDRequest, delay: useconds_t) async -> [UInt8]? {
        await perform { $0.send(request, delay: delay) }
    }

    private func perform<T: Sendable>(_ work: @escaping @Sendable (HIDTransport) -> T?) async -> T? {
        guard let channel else { return nil }
        return await channel.perform(work)
    }

    private func attachFirstAvailableDevice() {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let first = devices.first else { return }
        attach(first)
    }

    private func attach(_ newDevice: IOHIDDevice) {
        guard device != newDevice else { return }
        IOHIDDeviceOpen(newDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        device = newDevice
        channel = HIDChannel(device: newDevice)
        onConnectionChange?()
    }

    private func detach(_ removedDevice: IOHIDDevice) {
        guard device == removedDevice else { return }
        device = nil
        channel = nil
        onConnectionChange?()
    }
}
