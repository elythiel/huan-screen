import AppKit

@main
@MainActor
enum HuanScreenApp {
    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        guard let command = arguments.first else { return runMenuBarApp() }
        exit(CommandLineInterface.run(command))
    }

    private static func runMenuBarApp() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let controller = StatusBarController(receiver: Receiver())
        withExtendedLifetime(controller) { app.run() }
    }
}
