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
    private var accessibilityGroup: NSAccessibilityElement?

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
        }
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
        // The native views remain the interactive controls. Retained
        // NSAccessibilityElement proxies provide a stable AX hierarchy for
        // System Events and assistive technologies.
        for view in [message, applyToAll, saveButton, discardButton, cancelButton] {
            view.setAccessibilityElement(false)
        }
        let group = QuitAlertAXGroup(panel: panel)
        group.setAccessibilityChildren([
            QuitAlertAXStaticText(
                label: "Quit review message",
                value: message.stringValue,
                view: message,
                parent: group
            ),
            QuitAlertAXCheckBox(
                label: "Apply this choice to all remaining modified documents",
                button: applyToAll,
                parent: group
            ),
            QuitAlertAXButton(label: "Save", button: saveButton, parent: group),
            QuitAlertAXButton(label: "Don't Save", button: discardButton, parent: group),
            QuitAlertAXButton(label: "Cancel", button: cancelButton, parent: group)
        ])
        panel.setAccessibilityChildren([group])
        accessibilityGroup = group
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
                "panelAXChildren": (panel.accessibilityChildren() ?? []).count,
                "checkboxAXElement": applyToAll.isAccessibilityElement(),
                "checkboxAXRole": String(describing: applyToAll.accessibilityRole()),
                "contentAXChildren": (panel.contentView?.accessibilityChildren() ?? []).count,
                "contentAXParentIsPanel": (panel.contentView?.accessibilityParent() as? NSPanel) === panel,
                "checkboxAXParentIsContent":
                    (applyToAll.accessibilityParent() as? NSView) === panel.contentView,
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

private struct AccessibilityValueBox: @unchecked Sendable {
    let value: Any?
}

@MainActor
private final class WeakViewReference: @unchecked Sendable {
    weak var view: NSView?

    init(_ view: NSView?) {
        self.view = view
    }
}

@MainActor
private final class WeakPanelReference: @unchecked Sendable {
    weak var panel: NSPanel?

    init(_ panel: NSPanel) {
        self.panel = panel
    }
}

@MainActor
private final class WeakButtonReference: @unchecked Sendable {
    weak var button: NSButton?

    init(_ button: NSButton) {
        self.button = button
    }
}

@MainActor
private final class WeakAccessibilityElementReference: @unchecked Sendable {
    weak var element: NSAccessibilityElement?

    init(_ element: NSAccessibilityElement) {
        self.element = element
    }
}

private func onMainAppKitThread<T: Sendable>(_ operation: @MainActor () -> T) -> T {
    if Thread.isMainThread {
        return MainActor.assumeIsolated(operation)
    }
    return DispatchQueue.main.sync {
        MainActor.assumeIsolated(operation)
    }
}

private class QuitAlertAXElement: NSAccessibilityElement, @unchecked Sendable {
    let labelText: String
    private let viewReference: WeakViewReference?

    @MainActor
    init(role: NSAccessibility.Role, label: String, view: NSView?, parent: Any?) {
        labelText = label
        viewReference = view.map(WeakViewReference.init)
        super.init()
        setAccessibilityRole(role)
        setAccessibilityLabel(label)
        setAccessibilityParent(parent)
        let topLevel = parent as? NSWindow ??
            (parent as? NSAccessibilityElement)?.accessibilityTopLevelUIElement()
        setAccessibilityTopLevelUIElement(topLevel)
        if let view {
            setAccessibilityFrameInParentSpace(view.frame)
        }
    }

    override func accessibilityLabel() -> String? {
        labelText
    }

    override func accessibilityIdentifier() -> String {
        labelText
    }

    override func accessibilityFrame() -> NSRect {
        let viewReference = viewReference
        return onMainAppKitThread {
            guard let view = viewReference?.view, let window = view.window else { return NSRect.zero }
            return window.convertToScreen(view.convert(view.bounds, to: nil))
        }
    }
}

private final class QuitAlertAXGroup: QuitAlertAXElement, NSAccessibilityGroup, @unchecked Sendable {
    private let panelReference: WeakPanelReference

    @MainActor
    init(panel: NSPanel) {
        panelReference = WeakPanelReference(panel)
        super.init(role: .group, label: "Quit review controls", view: panel.contentView, parent: panel)
    }

    override func accessibilityFrame() -> NSRect {
        let panelReference = panelReference
        return onMainAppKitThread {
            guard let panel = panelReference.panel, let content = panel.contentView else { return NSRect.zero }
            return panel.convertToScreen(content.convert(content.bounds, to: nil))
        }
    }
}

private final class QuitAlertAXStaticText: QuitAlertAXElement, @unchecked Sendable {
    private let textValue: String

    @MainActor
    init(label: String, value: String, view: NSView, parent: Any?) {
        textValue = value
        super.init(role: .staticText, label: label, view: view, parent: parent)
    }

    override func accessibilityValue() -> Any? {
        textValue
    }
}

private class QuitAlertAXButton: QuitAlertAXElement, NSAccessibilityButton, @unchecked Sendable {
    private let buttonReference: WeakButtonReference

    @MainActor
    init(label: String, button: NSButton, parent: Any?) {
        buttonReference = WeakButtonReference(button)
        super.init(role: .button, label: label, view: button, parent: parent)
    }

    override func accessibilityPerformPress() -> Bool {
        let buttonReference = buttonReference
        return onMainAppKitThread {
            guard let button = buttonReference.button else { return false }
            button.performClick(nil)
            return true
        }
    }
}

private final class QuitAlertAXCheckBox: NSObject, NSAccessibilityCheckBox, @unchecked Sendable {
    private let labelText: String
    private let viewReference: WeakViewReference
    private let checkboxReference: WeakButtonReference
    private let parentReference: WeakAccessibilityElementReference

    @MainActor
    init(label: String, button: NSButton, parent: NSAccessibilityElement) {
        labelText = label
        viewReference = WeakViewReference(button)
        checkboxReference = WeakButtonReference(button)
        parentReference = WeakAccessibilityElementReference(parent)
        super.init()
    }

    func accessibilityFrame() -> NSRect {
        let viewReference = viewReference
        return onMainAppKitThread {
            guard let view = viewReference.view, let window = view.window else { return NSRect.zero }
            return window.convertToScreen(view.convert(view.bounds, to: nil))
        }
    }

    func accessibilityParent() -> Any? {
        let parentReference = parentReference
        return onMainAppKitThread {
            AccessibilityValueBox(value: parentReference.element)
        }.value
    }

    func accessibilityLabel() -> String? {
        labelText
    }

    func accessibilityIdentifier() -> String {
        labelText
    }

    func accessibilityPerformPress() -> Bool {
        let checkboxReference = checkboxReference
        let element = self
        return onMainAppKitThread {
            guard let checkbox = checkboxReference.button else { return false }
            checkbox.performClick(nil)
            NSAccessibility.post(element: element, notification: .valueChanged)
            return true
        }
    }

    func accessibilityValue() -> NSNumber? {
        let checkboxReference = checkboxReference
        return onMainAppKitThread {
            NSNumber(value: checkboxReference.button?.state == .on)
        }
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
