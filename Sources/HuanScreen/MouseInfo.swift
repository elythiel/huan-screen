import Foundation

struct MouseInfo: Sendable, Equatable {
    let batteryLevel: Int
    let isCharging: Bool
    let profile: UInt8
    let dpiStages: [Int]
    var activeDPIStage: Int?
    var pollingRate: Int?
    let liftOffDistance: Double?

    var dpi: Int? {
        guard let activeDPIStage, dpiStages.indices.contains(activeDPIStage - 1) else { return nil }
        return dpiStages[activeDPIStage - 1]
    }

    var specsDescription: String {
        [
            dpi.map { "\($0) DPI" },
            pollingRate.map { "\($0) Hz" },
            liftOffDistance.map { "LOD \($0.formatted(.number.precision(.fractionLength(0...1)))) mm" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

extension MouseInfo {
    static let mouse: UInt8 = 0x02
    static let delay: useconds_t = 60_000
    private static let defaultProfile: UInt8 = 1
    private static let maxDPIStages: UInt8 = 6
    private static let bytesPerDPIStage = 4
    static let supportedPollingRates = [125, 250, 500, 1000, 2000, 4000, 8000]
    static let pollingRateCodes: [Int: UInt8] = [125: 8, 250: 4, 500: 2, 1000: 1, 2000: 32, 4000: 64, 8000: 128]
    private static let pollingRates: [UInt8: Int] = [8: 125, 4: 250, 2: 500, 1: 1000, 16: 1000, 32: 2000, 64: 4000, 128: 8000]

    static func read(from channel: HIDChannel) -> MouseInfo? {
        guard let battery = channel.send(HIDRequest(target: mouse, length: 2, group: 0, command: 0x83), delay: delay) else { return nil }
        let profile = channel.send(HIDRequest(target: mouse, length: 1, group: 0, command: 0x85), delay: delay)?[0] ?? defaultProfile

        return MouseInfo(
            batteryLevel: Int(battery[1]),
            isCharging: battery[0] == 1,
            profile: profile,
            dpiStages: readDPIStages(from: channel, profile: profile),
            activeDPIStage: readSetting(0x82, length: 2, from: channel, profile: profile).map(Int.init),
            pollingRate: readSetting(0x80, length: 2, from: channel, profile: profile).flatMap { pollingRates[$0] },
            liftOffDistance: readSetting(0x88, length: 3, from: channel, profile: profile).map(decodeLiftOffDistance)
        )
    }

    private static func readSetting(_ command: UInt8, length: UInt8, from channel: HIDChannel, profile: UInt8) -> UInt8? {
        channel.send(HIDRequest(target: mouse, length: length, group: 1, command: command, parameters: [profile]), delay: delay)?[1]
    }

    private static func readDPIStages(from channel: HIDChannel, profile: UInt8) -> [Int] {
        guard let response = channel.send(HIDRequest(target: mouse, length: 10, group: 1, command: 0x81, parameters: [profile, maxDPIStages]), delay: delay) else { return [] }
        let count = min(Int(response[1]), Int(maxDPIStages))
        return (0..<count).map { index in
            let offset = 2 + index * bytesPerDPIStage
            return Int(response[offset]) << 8 | Int(response[offset + 1])
        }
    }

    private static func decodeLiftOffDistance(_ value: UInt8) -> Double {
        if value >= 0x80 { return Double(value - 0x80) / 10 }
        if value == 1 || value == 2 { return Double(value) }
        return Double(Int(value >> 4) * 10 + Int(value & 0x0F)) / 10
    }
}
