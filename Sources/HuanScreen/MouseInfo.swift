import Foundation

struct MouseInfo: Sendable, Equatable {
    let batteryLevel: Int
    let isCharging: Bool
    let profile: UInt8
    let dpiStages: [Int]
    var activeDPIStage: Int?
    var pollingRate: Int?
    var liftOffDistance: Double?
    let liftOffMode: UInt8

    var dpi: Int? {
        guard let activeDPIStage, dpiStages.indices.contains(activeDPIStage - 1) else { return nil }
        return dpiStages[activeDPIStage - 1]
    }

    var specsDescription: String {
        [
            dpi.map { "\($0) DPI" },
            pollingRate.map { "\($0) Hz" },
            liftOffDistance.map { "LOD \(Self.format(liftOffDistance: $0))" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    static func format(liftOffDistance: Double) -> String {
        "\(liftOffDistance.formatted(.number.precision(.fractionLength(0...1)))) mm"
    }
}

extension MouseInfo {
    static let mouse: UInt8 = 0x02
    private static let maxChargingLevel = 99
    static let delay: useconds_t = 60_000
    private static let defaultProfile: UInt8 = 1
    private static let maxDPIStages: UInt8 = 6
    private static let bytesPerDPIStage = 4
    static let supportedPollingRates = [125, 250, 500, 1000, 2000, 4000, 8000]
    static let supportedLiftOffDistances = [0.7, 1, 2]
    static let pollingRateCodes: [Int: UInt8] = [125: 8, 250: 4, 500: 2, 1000: 1, 2000: 32, 4000: 64, 8000: 128]
    private static let pollingRates: [UInt8: Int] = [8: 125, 4: 250, 2: 500, 1: 1000, 16: 1000, 32: 2000, 64: 4000, 128: 8000]

    static func read(from transport: HIDTransport) -> MouseInfo? {
        guard let battery = transport.send(HIDRequest(target: mouse, length: 2, group: 0, command: 0x83), delay: delay) else { return nil }
        let profile = transport.send(HIDRequest(target: mouse, length: 1, group: 0, command: 0x85), delay: delay)?[0] ?? defaultProfile
        let liftOff = transport.send(HIDRequest(target: mouse, length: 3, group: 1, command: 0x88, parameters: [profile]), delay: delay)

        return MouseInfo(
            batteryLevel: battery[0] == 1 ? min(Int(battery[1]), maxChargingLevel) : Int(battery[1]),
            isCharging: battery[0] == 1,
            profile: profile,
            dpiStages: readDPIStages(from: transport, profile: profile),
            activeDPIStage: readSetting(0x82, length: 2, from: transport, profile: profile).map(Int.init),
            pollingRate: readSetting(0x80, length: 2, from: transport, profile: profile).flatMap { pollingRates[$0] },
            liftOffDistance: liftOff.map { decodeLiftOffDistance($0[1]) },
            liftOffMode: liftOff?[2] ?? 0
        )
    }

    private static func readSetting(_ command: UInt8, length: UInt8, from transport: HIDTransport, profile: UInt8) -> UInt8? {
        transport.send(HIDRequest(target: mouse, length: length, group: 1, command: command, parameters: [profile]), delay: delay)?[1]
    }

    private static func readDPIStages(from transport: HIDTransport, profile: UInt8) -> [Int] {
        guard let response = transport.send(HIDRequest(target: mouse, length: 10, group: 1, command: 0x81, parameters: [profile, maxDPIStages]), delay: delay) else { return [] }
        let count = min(Int(response[1]), Int(maxDPIStages))
        return (0..<count).map { index in
            let offset = 2 + index * bytesPerDPIStage
            return Int(response[offset]) << 8 | Int(response[offset + 1])
        }
    }

    static func encodeLiftOffDistance(_ distance: Double) -> UInt8 {
        let tenths = Int((distance * 10).rounded())
        if tenths < 10 { return UInt8(tenths) | 0x80 }
        if tenths % 10 == 0 { return UInt8(tenths / 10) }
        return UInt8(tenths / 10) << 4 | UInt8(tenths % 10)
    }

    private static func decodeLiftOffDistance(_ value: UInt8) -> Double {
        if value >= 0x80 { return Double(value - 0x80) / 10 }
        if value == 1 || value == 2 { return Double(value) }
        return Double(Int(value >> 4) * 10 + Int(value & 0x0F)) / 10
    }
}
