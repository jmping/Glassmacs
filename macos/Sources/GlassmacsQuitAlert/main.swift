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

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 190))
        content.autoresizingMask = [.width, .height]
        for view in [message, applyToAll, saveButton, discardButton, cancelButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            view.setAccessibilityElement(true)
            view.setAccessibilityParent(content)
        }
        message.setAccessibilityRole(.staticText)
        message.setAccessibilityLabel("Quit review message")
        applyToAll.setAccessibilityRole(.checkBox)
        applyToAll.setAccessibilityLabel(
            "Apply this choice to all remaining modified documents"
        )
        saveButton.setAccessibilityRole(.button)
        saveButton.setAccessibilityLabel("Save")
        discardButton.setAccessibilityRole(.button)
        discardButton.setAccessibilityLabel("Don't Save")
        cancelButton.setAccessibilityRole(.button)
        cancelButton.setAccessibilityLabel("Cancel")
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.group)
        content.setAccessibilityLabel("Quit review controls")
        content.setAccessibilityParent(panel)
        content.setAccessibilityChildren([
            message, applyToAll, saveButton, discardButton, cancelButton
        ])
        panel.setAccessibilityChildren([content])
        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            message.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            message.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            applyToAll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            applyToAll.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -22),
            applyToAll.topAnchor.constraint(equalTo: message.bottomAnchor, constant: 14),
            saveButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            discardButton.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(equalTo: discardButton.trailingAnchor, constant: 8),
            cancelButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            discardButton.widthAnchor.constraint(equalTo: saveButton.widthAnchor),
            cancelButton.widthAnchor.constraint(equalTo: saveButton.widthAnchor),
            saveButton.topAnchor.constraint(equalTo: applyToAll.bottomAnchor, constant: 14),
            discardButton.topAnchor.constraint(equalTo: saveButton.topAnchor),
            cancelButton.topAnchor.constraint(equalTo: saveButton.topAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 32),
            discardButton.heightAnchor.constraint(equalTo: saveButton.heightAnchor),
            cancelButton.heightAnchor.constraint(equalTo: saveButton.heightAnchor),
            saveButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        panel.contentView = content
        panel.setContentSize(NSSize(width: 500, height: 190))
        panel.contentView?.layoutSubtreeIfNeeded()

        saveButton.keyEquivalent = "\r"
        saveButton.keyEquivalentModifierMask = []
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.keyEquivalentModifierMask = []
        panel.initialFirstResponder = saveButton
        panel.defaultButtonCell = saveButton.cell as? NSButtonCell

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
            panel.contentView?.layoutSubtreeIfNeeded()
            writeResponse([
                "phase": "presenting",
                "activationPolicy": application.activationPolicy() == .regular ? "regular" : "other",
                "applicationActive": application.isActive,
                "processIdentifier": ProcessInfo.processInfo.processIdentifier,
                "applicationWindowCount": application.windows.count,
                "applicationVisibleWindowCount": application.windows.filter { $0.isVisible }.count,
                "panelFrame": NSStringFromRect(panel.frame),
                "contentFrame": NSStringFromRect(panel.contentView?.frame ?? .zero),
                "checkboxFrame": NSStringFromRect(applyToAll.frame),
                "buttonFrames": [saveButton, discardButton, cancelButton]
                    .map { NSStringFromRect($0.frame) }
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
