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
    private static let receiverProductID = 0xA863
    private static let wiredMouseProductIDs: Set<Int> = [0xA864, 0xA859]
    private static let vendorUsagePage = 0xFFFF
    private static let dongle: UInt8 = 0x00
    private static let screenDelay: useconds_t = 30_000

    var onConnectionChange: (() -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var receiverDevice: IOHIDDevice?
    private var receiverChannel: HIDChannel?
    private var wiredMouseDevice: IOHIDDevice?
    private var wiredMouseChannel: HIDChannel?

    var isConnected: Bool { receiverChannel != nil }
    var isMouseWired: Bool { wiredMouseChannel != nil }
    private var mouseChannel: HIDChannel? { wiredMouseChannel ?? receiverChannel }

    init() {
        let productIDs = [Self.receiverProductID] + Self.wiredMouseProductIDs.sorted()
        let matching = productIDs.map { productID in
            [kIOHIDVendorIDKey: Self.vendorID, kIOHIDProductIDKey: productID, kIOHIDPrimaryUsagePageKey: Self.vendorUsagePage]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        attachAvailableDevices()
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
        await perform(on: mouseChannel, MouseInfo.read)
    }

    func readFirmware() async -> InstalledFirmware? {
        let receiver = await perform(on: receiverChannel, InstalledFirmware.readReceiver)
        let mouse = await perform(on: mouseChannel, InstalledFirmware.readMouse)
        guard receiver != nil || mouse != nil else { return nil }
        return InstalledFirmware(
            mouse: mouse?.mouse,
            mousePID: mouse?.mousePID,
            receiver: receiver?.receiver,
            receiverPID: receiver?.receiverPID
        )
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
        let delay = Self.screenDelay
        return await perform(on: receiverChannel) { $0.send(request, delay: delay) }?[0]
    }

    private func send(_ request: HIDRequest, delay: useconds_t) async -> [UInt8]? {
        await perform(on: mouseChannel) { $0.send(request, delay: delay) }
    }

    private func perform<T: Sendable>(on channel: HIDChannel?, _ work: @escaping @Sendable (HIDTransport) -> T?) async -> T? {
        guard let channel else { return nil }
        return await channel.perform(work)
    }

    private func attachAvailableDevices() {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }
        for device in devices { attach(device) }
    }

    private func attach(_ device: IOHIDDevice) {
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int
        if productID == Self.receiverProductID {
            guard receiverDevice != device else { return }
            receiverDevice = device
            receiverChannel = HIDChannel(device: device)
        } else if let productID, Self.wiredMouseProductIDs.contains(productID) {
            guard wiredMouseDevice != device else { return }
            wiredMouseDevice = device
            wiredMouseChannel = HIDChannel(device: device)
        } else {
            return
        }
        IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        onConnectionChange?()
    }

    private func detach(_ device: IOHIDDevice) {
        if receiverDevice == device {
            receiverDevice = nil
            receiverChannel = nil
        } else if wiredMouseDevice == device {
            wiredMouseDevice = nil
            wiredMouseChannel = nil
        } else {
            return
        }
        onConnectionChange?()
    }
}
