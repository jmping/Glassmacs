import Foundation

public struct LaunchConfiguration: Equatable, Sendable {
    public let emacsExecutable: String
    public let checkoutPath: String
    public let homePath: String?
    public let emacsClientExecutable: String?

    public init(
        emacsExecutable: String,
        checkoutPath: String,
        homePath: String? = nil,
        emacsClientExecutable: String? = nil
    ) {
        self.emacsExecutable = emacsExecutable
        self.checkoutPath = checkoutPath
        self.homePath = homePath
        self.emacsClientExecutable = emacsClientExecutable
    }

    public var initFilePath: String {
        URL(fileURLWithPath: checkoutPath, isDirectory: true)
            .appendingPathComponent("init.el")
            .path
    }

    public var emacsServerSocketPath: String {
        let home = homePath ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/glassmacs", isDirectory: true).path
        return URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("server-sockets/glassmacs")
            .standardizedFileURL.path
    }

    public func emacsArguments(opening files: [URL]) -> [String] {
        ["-Q", "--load", initFilePath]
            + (files.isEmpty ? [] : ["--"] + files.map(\.path))
    }

    public func emacsClientArguments(opening files: [URL]) -> [String] {
        let encodedPaths = files.map { Data($0.path.utf8).base64EncodedString() }
            .map { "\"\($0)\"" }
            .joined(separator: " ")
        let expression = """
        (glassmacs-open-files-from-client (mapcar (lambda (path) (decode-coding-string (base64-decode-string path) 'utf-8)) '(\(encodedPaths))))
        """
        return [
            "--socket-name=\(emacsServerSocketPath)",
            "--no-wait",
            "--eval",
            expression
        ]
    }

    public var emacsServerProbeArguments: [String] {
        ["--socket-name=\(emacsServerSocketPath)", "--timeout=1", "--eval", "(emacs-pid)"]
    }
}
