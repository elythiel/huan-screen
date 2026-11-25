import Foundation
import IOKit.hid

struct HIDRequest: Sendable {
    let target: UInt8
    let length: UInt8
    let group: UInt8
    let command: UInt8
    var parameters: [UInt8] = []
}

final class HIDChannel: @unchecked Sendable {
    private static let reportLength = 64
    private static let parametersOffset = 6
    private static let successStatus: UInt8 = 0xA1
    private static let maxAttempts = 3

    private let device: IOHIDDevice
    private let queue = DispatchQueue(label: "io.github.elythiel.huan-screen.hid")

    init(device: IOHIDDevice) {
        self.device = device
    }

    func send(_ request: HIDRequest, delay: useconds_t) -> [UInt8]? {
        queue.sync {
            for _ in 0..<Self.maxAttempts {
                if let payload = transact(request, delay: delay) { return payload }
            }
            return nil
        }
    }

    private func transact(_ request: HIDRequest, delay: useconds_t) -> [UInt8]? {
        var report = [UInt8](repeating: 0, count: Self.reportLength)
        report[2] = request.target
        report[3] = request.length
        report[4] = request.group
        report[5] = request.command
        report.replaceSubrange(Self.parametersOffset..<Self.parametersOffset + request.parameters.count, with: request.parameters)
        guard IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, 0, report, report.count) == kIOReturnSuccess else { return nil }

        usleep(delay)

        var response = [UInt8](repeating: 0, count: Self.reportLength)
        var length = CFIndex(response.count)
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0, &response, &length) == kIOReturnSuccess,
              length == Self.reportLength,
              response[0] == Self.successStatus,
              response[2] == request.target,
              response[5] == request.command
        else { return nil }
        return Array(response[Self.parametersOffset...])
    }
}
