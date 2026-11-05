import AppKit
import Darwin
import Foundation

// A deliberately small native dialog. AppKit owns the accessibility tree:
// do not hide real controls or replace them with synthetic AX elements.
@main
@MainActor
enum GlassmacsQuitAlert {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2 else {
            FileHandle.standardError.write(Data("GlassmacsQuitAlert: expected response path and document name\n".utf8))
            exit(EXIT_FAILURE)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let controller = QuitDialog(
            app: app,
            documentName: args[1],
            responseURL: URL(fileURLWithPath: args[0])
        )
        app.delegate = controller
        app.run()
    }
}

@MainActor
private final class QuitDialog: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let app: NSApplication
    private let panel: NSPanel
    private let checkbox: NSButton
    private let responseURL: URL
    private var completed = false

    init(app: NSApplication, documentName: String, responseURL: URL) {
        self.app = app
        self.responseURL = responseURL

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Glassmacs — Unsaved Document"
        panel.level = .modalPanel
        panel.center()
        self.panel = panel

        let message = NSTextField(wrappingLabelWithString:
            "Save changes to \(documentName)?\nChoose what to do before quitting Glassmacs.")
        message.font = .systemFont(ofSize: NSFont.systemFontSize)
        message.maximumNumberOfLines = 0

        let checkbox = NSButton(
            checkboxWithTitle: "Apply this choice to all remaining modified documents",
            target: nil, action: nil
        )
        checkbox.state = .off
        self.checkbox = checkbox

        let save = NSButton(title: "Save", target: nil, action: nil)
        let discard = NSButton(title: "Don't Save", target: nil, action: nil)
        let cancel = NSButton(title: "Cancel", target: nil, action: nil)
        for button in [save, discard, cancel] {
            button.bezelStyle = .rounded
        }

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 190))
        for view in [message, checkbox, save, discard, cancel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            message.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            message.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            checkbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -22),
            checkbox.topAnchor.constraint(equalTo: message.bottomAnchor, constant: 14),
            save.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            discard.leadingAnchor.constraint(equalTo: save.trailingAnchor, constant: 8),
            cancel.leadingAnchor.constraint(equalTo: discard.trailingAnchor, constant: 8),
            cancel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            save.widthAnchor.constraint(equalTo: discard.widthAnchor),
            discard.widthAnchor.constraint(equalTo: cancel.widthAnchor),
            save.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 14),
            discard.topAnchor.constraint(equalTo: save.topAnchor),
            cancel.topAnchor.constraint(equalTo: save.topAnchor),
            save.heightAnchor.constraint(equalToConstant: 32),
            discard.heightAnchor.constraint(equalTo: save.heightAnchor),
            cancel.heightAnchor.constraint(equalTo: save.heightAnchor),
            save.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        panel.contentView = content
        panel.setContentSize(NSSize(width: 520, height: 190))

        super.init()
        panel.delegate = self
        save.target = self
        save.action = #selector(saveChoice(_:))
        discard.target = self
        discard.action = #selector(discardChoice(_:))
        cancel.target = self
        cancel.action = #selector(cancelChoice(_:))
        save.keyEquivalent = "\r"
        cancel.keyEquivalent = "\u{1b}"
        panel.defaultButtonCell = save.cell as? NSButtonCell
        panel.initialFirstResponder = save
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(ignoringOtherApps: true)
        }
        DispatchQueue.main.async { [self] in
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.makeKeyAndOrderFront(nil)
            writeResponse(["phase": "presenting",
                           "processIdentifier": ProcessInfo.processInfo.processIdentifier],
                          to: responseURL)
            let result = app.runModal(for: panel)
            panel.orderOut(nil)
            let choice: String
            switch result {
            case .alertFirstButtonReturn: choice = "save"
            case .alertSecondButtonReturn: choice = "discard"
            default: choice = "cancel"
            }
            completed = true
            writeResponse(["action": choice, "all": checkbox.state == .on],
                          to: responseURL)
            app.terminate(nil)
        }
    }

    @objc private func saveChoice(_ sender: NSButton) {
        app.stopModal(withCode: .alertFirstButtonReturn)
    }

    @objc private func discardChoice(_ sender: NSButton) {
        app.stopModal(withCode: .alertSecondButtonReturn)
    }

    @objc private func cancelChoice(_ sender: NSButton) {
        app.stopModal(withCode: .alertThirdButtonReturn)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel && !completed {
            app.stopModal(withCode: .alertThirdButtonReturn)
            return false
        }
        return true
    }
}

private func writeResponse(_ value: [String: Any], to url: URL) {
    do {
        let data = try JSONSerialization.data(withJSONObject: value)
        try data.write(to: url, options: .atomic)
    } catch {
        FileHandle.standardError.write(Data("GlassmacsQuitAlert: response write failed: \(error)\n".utf8))
    }
}
