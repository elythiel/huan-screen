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

    var mode: ScreenMode? {
        sendScreenCommand(0x8A).map { $0 == 0 ? .cat : .status }
    }

    var mouseInfo: MouseInfo? {
        channel.flatMap(MouseInfo.read)
    }

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

    @discardableResult
    func setMode(_ mode: ScreenMode) -> Bool {
        sendScreenCommand(0x0A, value: mode == .status ? 1 : 0) != nil
    }

    func readMouseInfo() async -> MouseInfo? {
        guard let channel else { return nil }
        return await Task.detached { MouseInfo.read(from: channel) }.value
    }

    private func sendScreenCommand(_ command: UInt8, value: UInt8 = 0) -> UInt8? {
        let request = HIDRequest(target: Self.dongle, length: 1, group: 5, command: command, parameters: [value])
        return channel?.send(request, delay: Self.screenDelay)?[0]
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
