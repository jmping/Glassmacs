#if os(macOS)
import AppKit
import GlassmacsLauncherCore

@MainActor
final class LauncherDelegate: NSObject, NSApplicationDelegate {
    private let defaults = UserDefaults.standard
    private var emacsProcess: Process?
    private var serverAvailable = false
    private var pendingFiles: [URL] = []
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ _notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.launchEmacsIfNeeded()
        }
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        open(filenames.map { URL(fileURLWithPath: $0) })
        application.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        open(urls.filter(\.isFileURL))
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if emacsProcess?.isRunning == true {
            showError("Glassmacs is still running in Emacs. Quit from Emacs so its unsaved-document prompts are honored.")
            return .terminateCancel
        }
        return .terminateNow
    }

    private func open(_ files: [URL]) {
        guard !files.isEmpty else { return }
        guard let process = emacsProcess else {
            if serverAvailable {
                forward(files, attemptsRemaining: 20)
            } else {
                pendingFiles.append(contentsOf: files)
                launchEmacsIfNeeded()
            }
            return
        }
        guard process.isRunning else {
            emacsProcess = nil
            pendingFiles.append(contentsOf: files)
            launchEmacsIfNeeded()
            return
        }
        forward(files, attemptsRemaining: 20)
    }

    private func launchEmacsIfNeeded() {
        guard emacsProcess == nil else { return }
        do {
            let configuration = try loadConfiguration()
            guard FileManager.default.isExecutableFile(atPath: configuration.emacsExecutable) else {
                throw LauncherError.invalidExecutable(configuration.emacsExecutable)
            }
            guard FileManager.default.fileExists(atPath: configuration.initFilePath) else {
                throw LauncherError.invalidCheckout(configuration.checkoutPath)
            }
            if forwardToExistingServer(configuration, files: pendingFiles) {
                serverAvailable = true
                pendingFiles.removeAll()
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: configuration.emacsExecutable)
            let initialFiles = pendingFiles
            process.arguments = configuration.emacsArguments(opening: [])
            process.currentDirectoryURL = URL(fileURLWithPath: configuration.checkoutPath)
            var childEnvironment = ProcessInfo.processInfo.environment
            childEnvironment["GLASSMACS_LAUNCHER_SERVER"] = "1"
            if let home = configuration.homePath, !home.isEmpty {
                childEnvironment["GLASSMACS_HOME"] = home
            }
            process.environment = childEnvironment
            process.terminationHandler = { [weak self] terminatedProcess in
                Task { @MainActor in
                    if terminatedProcess.terminationStatus != 0 {
                        self?.showError("Emacs exited with status \(terminatedProcess.terminationStatus). Check the selected executable and Glassmacs configuration.")
                    }
                    self?.emacsProcess = nil
                    self?.serverAvailable = false
                    NSApp.terminate(nil)
                }
            }
            try process.run()
            emacsProcess = process
            pendingFiles.removeAll()
            if !initialFiles.isEmpty {
                forward(initialFiles, attemptsRemaining: 20)
            }
        } catch {
            showError(error.localizedDescription, offerPreferences: true)
        }
    }

    private func makeClientProcess(
        _ configuration: LaunchConfiguration,
        arguments: [String]
    ) throws -> Process {
        let client = configuration.emacsClientExecutable
        let executable = client.flatMap { $0.hasPrefix("/") ? $0 : nil } ?? "/usr/bin/env"
        let command = client.flatMap { $0.hasPrefix("/") ? nil : $0 } ?? "emacsclient"
        guard executable == "/usr/bin/env" || FileManager.default.isExecutableFile(atPath: executable) else {
            throw LauncherError.invalidExecutable(executable)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = (executable == "/usr/bin/env" ? [command] : []) + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GLASSMACS_LAUNCHER_SERVER"] = "1"
        if let home = configuration.homePath, !home.isEmpty {
            environment["GLASSMACS_HOME"] = home
        }
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
    }

    private func forwardToExistingServer(_ configuration: LaunchConfiguration, files: [URL]) -> Bool {
        do {
            let clientProcess = try makeClientProcess(
                configuration,
                arguments: files.isEmpty
                    ? configuration.emacsServerProbeArguments
                    : configuration.emacsClientArguments(opening: files)
            )
            try clientProcess.run()
            clientProcess.waitUntilExit()
            return clientProcess.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func forward(_ files: [URL], attemptsRemaining: Int) {
        do {
            let configuration = try loadConfiguration()
            let clientProcess = try makeClientProcess(
                configuration,
                arguments: configuration.emacsClientArguments(opening: files)
            )
            clientProcess.terminationHandler = { [weak self] client in
                guard client.terminationStatus != 0, attemptsRemaining > 0 else {
                    if client.terminationStatus != 0 {
                        Task { @MainActor in
                            self?.showError("Could not forward files to the running Emacs. Check the configured emacsclient and Glassmacs home; no second Emacs instance was launched.")
                        }
                    }
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.forward(files, attemptsRemaining: attemptsRemaining - 1)
                }
            }
            try clientProcess.run()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func loadConfiguration() throws -> LaunchConfiguration {
        let environment = ProcessInfo.processInfo.environment
        guard let emacs = environment["GLASSMACS_EMACS"] ?? defaults.string(forKey: "emacsExecutable"),
              !emacs.isEmpty else {
            throw LauncherError.missingSetting("Set the upstream Cocoa Emacs executable in Glassmacs Launcher Preferences.")
        }
        guard let checkout = environment["GLASSMACS_ROOT"] ?? defaults.string(forKey: "checkoutPath"),
              !checkout.isEmpty else {
            throw LauncherError.missingSetting("Set the Glassmacs checkout path in Glassmacs Launcher Preferences.")
        }
        return LaunchConfiguration(
            emacsExecutable: (emacs as NSString).expandingTildeInPath,
            checkoutPath: (checkout as NSString).expandingTildeInPath,
            homePath: (environment["GLASSMACS_HOME"] ?? defaults.string(forKey: "homePath"))
                .map { ($0 as NSString).expandingTildeInPath },
            emacsClientExecutable: (environment["GLASSMACS_EMACSCLIENT"] ?? defaults.string(forKey: "emacsClientExecutable"))
                .flatMap { $0.isEmpty ? nil : ($0 as NSString).expandingTildeInPath }
        )
    }

    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Glassmacs"
        let menu = NSMenu()
        let preferences = menu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Launcher", action: #selector(quitLauncher), keyEquivalent: "q")
        quit.target = self
        item.menu = menu
        statusItem = item
    }

    @objc private func showPreferences() {
        let alert = NSAlert()
        alert.messageText = "Glassmacs Launcher"
        alert.informativeText = "Configure upstream Cocoa Emacs and the Glassmacs checkout. Glassmacs Lisp remains the settings authority."

        let fields = [
            ("emacsExecutable", "Emacs executable", defaults.string(forKey: "emacsExecutable") ?? "/Applications/Emacs.app/Contents/MacOS/Emacs"),
            ("checkoutPath", "Glassmacs checkout", defaults.string(forKey: "checkoutPath") ?? ""),
            ("homePath", "Glassmacs home (optional)", defaults.string(forKey: "homePath") ?? ""),
            ("emacsClientExecutable", "emacsclient (optional)", defaults.string(forKey: "emacsClientExecutable") ?? "")
        ]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        var controls: [(String, NSTextField)] = []
        for (key, label, value) in fields {
            let row = NSStackView()
            row.orientation = .vertical
            row.alignment = .leading
            row.spacing = 3
            let title = NSTextField(labelWithString: label)
            let field = NSTextField(string: value)
            field.placeholderString = label
            field.frame.size.width = 420
            row.addArrangedSubview(title)
            row.addArrangedSubview(field)
            stack.addArrangedSubview(row)
            controls.append((key, field))
        }
        stack.frame = NSRect(x: 0, y: 0, width: 440, height: 280)
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for (key, field) in controls {
            if field.stringValue.isEmpty {
                defaults.removeObject(forKey: key)
            } else {
                defaults.set(field.stringValue, forKey: key)
            }
        }
        launchEmacsIfNeeded()
    }

    @objc private func quitLauncher() {
        if emacsProcess?.isRunning == true {
            showError("Quit Glassmacs from Emacs to preserve its save and shutdown behavior.")
        } else {
            NSApp.terminate(nil)
        }
    }

    private func showError(_ message: String, offerPreferences: Bool = false) {
        let alert = NSAlert()
        alert.messageText = "Glassmacs could not continue"
        alert.informativeText = message
        if offerPreferences {
            alert.addButton(withTitle: "Preferences…")
            alert.addButton(withTitle: "Quit")
            if alert.runModal() == .alertFirstButtonReturn {
                showPreferences()
            } else {
                NSApp.terminate(nil)
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

enum LauncherError: LocalizedError {
    case missingSetting(String)
    case invalidExecutable(String)
    case invalidCheckout(String)

    var errorDescription: String? {
        switch self {
        case .missingSetting(let message): return message
        case .invalidExecutable(let path): return "Emacs executable is not executable: \(path)"
        case .invalidCheckout(let path): return "No init.el was found in the Glassmacs checkout: \(path)"
        }
    }
}

@main
enum GlassmacsLauncherMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = LauncherDelegate()
        application.delegate = delegate
        application.run()
    }
}
#else
@main
enum GlassmacsLauncherMain {
    static func main() {
        print("Glassmacs Launcher is a macOS AppKit application; use scripts/glassmacs on this platform.")
    }
}
#endif
