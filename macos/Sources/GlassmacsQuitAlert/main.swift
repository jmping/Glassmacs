import AppKit
import Darwin
import Foundation

@main
@MainActor
enum GlassmacsQuitAlert {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2 else {
            fail("Expected a response-file path and document name")
        }

        let application = NSApplication.shared
        if application.activationPolicy() != .regular &&
            !application.setActivationPolicy(.regular) {
            fail("Could not switch to the regular activation policy")
        }

        let delegate = QuitAlertDelegate(
            application: application,
            documentName: arguments[1],
            responseURL: URL(fileURLWithPath: arguments[0])
        )
        application.delegate = delegate
        application.run()
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("GlassmacsQuitAlert: \(message)\n".utf8))
        exit(EXIT_FAILURE)
    }
}

@MainActor
private final class QuitAlertDelegate: NSObject, NSApplicationDelegate {
    private let application: NSApplication
    private let panel: NSPanel
    private let applyToAll: NSButton
    private let responseURL: URL
    private let saveButton: NSButton
    private let discardButton: NSButton
    private let cancelButton: NSButton

    init(application: NSApplication, documentName: String, responseURL: URL) {
        self.application = application
        self.responseURL = responseURL

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 190),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "Glassmacs"
        panel.level = .modalPanel
        panel.isFloatingPanel = true
        panel.center()
        self.panel = panel

        let message = NSTextField(wrappingLabelWithString:
            "Save changes to \(documentName)?\nChoose what to do before quitting Glassmacs.")
        message.font = .systemFont(ofSize: NSFont.systemFontSize)
        message.maximumNumberOfLines = 0

        let applyToAll = NSButton(
            checkboxWithTitle: "Apply this choice to all remaining modified documents",
            target: nil,
            action: nil
        )
        applyToAll.state = .off
        self.applyToAll = applyToAll

        let saveButton = NSButton(title: "Save", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        self.saveButton = saveButton
        let discardButton = NSButton(title: "Don't Save", target: nil, action: nil)
        discardButton.bezelStyle = .rounded
        self.discardButton = discardButton
        let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
        cancelButton.bezelStyle = .rounded
        self.cancelButton = cancelButton

        let buttons = NSStackView(views: [saveButton, discardButton, cancelButton])
        buttons.orientation = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 8

        let content = NSView(frame: panel.contentView?.bounds ?? .zero)
        content.autoresizingMask = [.width, .height]
        let stack = NSStackView(views: [message, applyToAll, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        panel.contentView = content

        super.init()
        saveButton.target = self
        saveButton.action = #selector(saveChoice(_:))
        discardButton.target = self
        discardButton.action = #selector(discardChoice(_:))
        cancelButton.target = self
        cancelButton.action = #selector(cancelChoice(_:))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 14.0, *) {
            application.activate()
        } else {
            application.activate(ignoringOtherApps: true)
        }

        DispatchQueue.main.async { [self] in
            writeResponse([
                "phase": "presenting",
                "activationPolicy": application.activationPolicy() == .regular ? "regular" : "other",
                "applicationActive": application.isActive,
                "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                "applicationWindowCount": application.windows.count,
                "applicationVisibleWindowCount": application.windows.filter { $0.isVisible }.count
            ], to: responseURL)

            let modalResponse = application.runModal(for: panel)
            panel.orderOut(nil)
            let action: String
            switch modalResponse {
            case .alertFirstButtonReturn:
                action = "save"
            case .alertSecondButtonReturn:
                action = "discard"
            default:
                action = "cancel"
            }

            writeResponse(["action": action, "all": applyToAll.state == .on], to: responseURL)
            application.terminate(nil)
        }
    }

    @objc private func saveChoice(_ sender: NSButton) {
        application.stopModal(withCode: .alertFirstButtonReturn)
    }

    @objc private func discardChoice(_ sender: NSButton) {
        application.stopModal(withCode: .alertSecondButtonReturn)
    }

    @objc private func cancelChoice(_ sender: NSButton) {
        application.stopModal(withCode: .alertThirdButtonReturn)
    }
}

private func writeResponse(_ response: [String: Any], to url: URL) {
    do {
        let data = try JSONSerialization.data(withJSONObject: response)
        try data.write(to: url, options: .atomic)
    } catch {
        FileHandle.standardError.write(
            Data("GlassmacsQuitAlert: Could not write response: \(error.localizedDescription)\n".utf8)
        )
    }
}
