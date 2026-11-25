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
    private static let reportLength = 64
    private static let responseDelay: useconds_t = 30_000

    private enum Command: UInt8 {
        case setStatus = 0x0A
        case getStatus = 0x8A
    }

    var onConnectionChange: (() -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var device: IOHIDDevice?

    var isConnected: Bool { device != nil }

    var mode: ScreenMode? {
        transact(.getStatus).map { $0 == 0 ? .cat : .status }
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
        transact(.setStatus, value: mode == .status ? 1 : 0) != nil
    }

    private func attachFirstAvailableDevice() {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let first = devices.first else { return }
        attach(first)
    }

    private func attach(_ newDevice: IOHIDDevice) {
        guard device != newDevice else { return }
        IOHIDDeviceOpen(newDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        device = newDevice
        onConnectionChange?()
    }

    private func detach(_ removedDevice: IOHIDDevice) {
        guard device == removedDevice else { return }
        device = nil
        onConnectionChange?()
    }

    private func transact(_ command: Command, value: UInt8 = 0) -> UInt8? {
        guard let device else { return nil }

        var request = [UInt8](repeating: 0, count: Self.reportLength)
        request[3] = 0x01
        request[4] = 0x05
        request[5] = command.rawValue
        request[6] = value
        guard IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0, request, request.count) == kIOReturnSuccess else { return nil }

        usleep(Self.responseDelay)

        var response = [UInt8](repeating: 0, count: Self.reportLength)
        var length = CFIndex(response.count)
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0, &response, &length) == kIOReturnSuccess,
              length > 6,
              response[5] == command.rawValue
        else { return nil }
        return response[6]
    }
}
