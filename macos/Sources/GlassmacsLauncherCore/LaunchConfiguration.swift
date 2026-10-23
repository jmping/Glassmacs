import Foundation

public struct LaunchConfiguration: Equatable, Sendable {
    public static let minimumMacOSVersion = "13.0"

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
        [
            "-Q",
            "--eval",
            Self.nativeCompilationPolicy,
            "--load",
            initFile.path
        ] + arguments
    }

    static let nativeCompilationPolicy = """
    (progn
      (when (boundp 'native-comp-jit-compilation)
        (setq native-comp-jit-compilation nil))
      (when (boundp 'native-comp-enable-subr-trampolines)
        (setq native-comp-enable-subr-trampolines nil))
      (when (boundp 'native-comp-eln-load-path)
        (setq native-comp-eln-load-path
              (let* ((contents (expand-file-name "../../" data-directory))
                     (native-lisp
                      (expand-file-name "Frameworks/native-lisp/" contents)))
                (if (and (eq system-type 'darwin)
                         (file-readable-p (expand-file-name "Info.plist" contents))
                         (file-directory-p native-lisp))
                    (list (file-name-as-directory
                           (file-truename native-lisp)))
                  nil))))
    )
    """

    public func emacsEnvironment(environment: [String: String]) -> [String: String] {
        var result = environment
        if !Self.isSupportedDeploymentTarget(result["MACOSX_DEPLOYMENT_TARGET"]) {
            result["MACOSX_DEPLOYMENT_TARGET"] = Self.minimumMacOSVersion
        }
        return result
    }

    private static func isSupportedDeploymentTarget(_ value: String?) -> Bool {
        guard let value else { return false }
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(components.count),
              components.allSatisfy({
                  !$0.isEmpty && $0.allSatisfy { $0 >= "0" && $0 <= "9" }
              }),
              let major = Int(components[0])
        else {
            return false
        }
        return (13...15).contains(major) || major >= 26
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
