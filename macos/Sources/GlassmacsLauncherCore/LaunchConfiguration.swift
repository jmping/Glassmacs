import Foundation

public struct LaunchConfiguration: Equatable, Sendable {
    public let bundleURL: URL

    public init(bundleURL: URL) {
        self.bundleURL = bundleURL.standardizedFileURL
    }

    public var emacsExecutable: URL {
        bundleURL.appendingPathComponent("Contents/MacOS/Emacs")
    }

    public var initFile: URL {
        bundleURL
            .appendingPathComponent("Contents/Resources/Glassmacs", isDirectory: true)
            .appendingPathComponent("init.el")
    }

    public func glassmacsHome(
        environment: [String: String],
        defaultHome: URL
    ) throws -> URL {
        let configuredHome = environment["GLASSMACS_HOME"]
        let path = configuredHome.flatMap { $0.isEmpty ? nil : $0 }
            .map { ($0 as NSString).expandingTildeInPath }
            ?? defaultHome.path
        guard path.hasPrefix("/") else {
            throw LaunchConfigurationError.homeMustBeAbsolute(path)
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    public func emacsArguments(forwarding arguments: [String]) -> [String] {
        ["-Q", "--load", initFile.path] + arguments
    }
}

public enum LaunchConfigurationError: LocalizedError {
    case homeMustBeAbsolute(String)

    public var errorDescription: String? {
        switch self {
        case .homeMustBeAbsolute(let path):
            return "GLASSMACS_HOME must be an absolute path: \(path)"
        }
    }
}
