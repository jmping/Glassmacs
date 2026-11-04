import AppKit
import Darwin
import Foundation

@main
enum GlassmacsQuitAlert {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2 else {
            fail("Expected a response-file path and document name")
        }

        let responseURL = URL(fileURLWithPath: arguments[0])
        let documentName = arguments[1]
        let application = NSApplication.shared
        if application.activationPolicy() == .prohibited &&
            !application.setActivationPolicy(.accessory) {
            fail("Could not switch to the accessory activation policy")
        }
        guard application.activationPolicy() == .accessory else {
            fail("The Glassmacs quit alert is not running as an accessory app")
        }

        let alert = NSAlert()
        alert.messageText = "Save changes to \(documentName)?"
        alert.informativeText = "Choose what to do before quitting Glassmacs."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        let applyToAll = NSButton(
            checkboxWithTitle: "Apply this choice to all remaining modified documents",
            target: nil,
            action: nil
        )
        applyToAll.state = .off
        alert.accessoryView = applyToAll

        application.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        let action: String
        switch response {
        case .alertFirstButtonReturn:
            action = "save"
        case .alertSecondButtonReturn:
            action = "discard"
        default:
            action = "cancel"
        }

        do {
            let result: [String: Any] = ["action": action, "all": applyToAll.state == .on]
            let data = try JSONSerialization.data(withJSONObject: result)
            try data.write(to: responseURL, options: .atomic)
        } catch {
            fail("Could not return the quit decision: \(error.localizedDescription)")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("GlassmacsQuitAlert: \(message)\n".utf8))
        exit(EXIT_FAILURE)
    }
}
