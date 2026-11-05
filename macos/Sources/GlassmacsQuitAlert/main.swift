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
        if application.activationPolicy() != .regular &&
            !application.setActivationPolicy(.regular) {
            fail("Could not switch to the regular activation policy")
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

        if #available(macOS 14.0, *) {
            application.activate()
        } else {
            application.activate(ignoringOtherApps: true)
        }
        let activationDeadline = Date().addingTimeInterval(2)
        while !application.isActive && Date() < activationDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        writeResponse([
            "phase": "presenting",
            "activationPolicy": application.activationPolicy() == .regular ? "regular" : "other",
            "applicationActive": application.isActive,
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "applicationWindowCount": application.windows.count,
            "applicationVisibleWindowCount": application.windows.filter { $0.isVisible }.count
        ], to: responseURL)
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

        let result: [String: Any] = ["action": action, "all": applyToAll.state == .on]
        writeResponse(result, to: responseURL)
    }

    private static func writeResponse(_ response: [String: Any], to url: URL) {
        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            try data.write(to: url, options: .atomic)
        } catch {
            FileHandle.standardError.write(
                Data("GlassmacsQuitAlert: Could not write response: \(error.localizedDescription)\n".utf8)
            )
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("GlassmacsQuitAlert: \(message)\n".utf8))
        exit(EXIT_FAILURE)
    }
}
