import Foundation

@MainActor
enum CommandLineInterface {
    private static let usage = """
        Usage: HuanScreen [command]

        Without a command, starts the menu bar app.

        Commands:
          get       Print the current screen mode
          cat       Switch to cat mode
          status    Switch to status mode
          toggle    Switch to the other mode
        """

    static func run(_ command: String) -> Int32 {
        let receiver = Receiver()
        guard receiver.isConnected else { return fail("HUAN receiver not found") }

        switch command {
        case "get": return printMode(receiver.mode)
        case "cat": return set(.cat, on: receiver)
        case "status": return set(.status, on: receiver)
        case "toggle": return receiver.mode.map { set($0.toggled, on: receiver) } ?? fail("Unable to read the screen mode")
        case "-h", "--help", "help":
            print(usage)
            return EXIT_SUCCESS
        default: return fail("Unknown command: \(command)\n\n\(usage)")
        }
    }

    private static func set(_ mode: ScreenMode, on receiver: Receiver) -> Int32 {
        guard receiver.setMode(mode) else { return fail("Unable to set the screen mode") }
        return printMode(receiver.mode)
    }

    private static func printMode(_ mode: ScreenMode?) -> Int32 {
        guard let mode else { return fail("Unable to read the screen mode") }
        print(mode == .cat ? "cat" : "status")
        return EXIT_SUCCESS
    }

    private static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        return EXIT_FAILURE
    }
}
