import Foundation
import GlassmacsLauncherCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main
enum GlassmacsBootstrap {
    static func main() {
        let configuration = LaunchConfiguration(bundleURL: Bundle.main.bundleURL)

        do {
            guard FileManager.default.isExecutableFile(atPath: configuration.emacsExecutable.path) else {
                throw BootstrapError.missingExecutable(configuration.emacsExecutable.path)
            }
            guard FileManager.default.fileExists(atPath: configuration.initFile.path) else {
                throw BootstrapError.missingConfiguration(configuration.initFile.path)
            }

            let home = try configuration.glassmacsHome(
                environment: ProcessInfo.processInfo.environment,
                defaultHome: FileManager.default
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Glassmacs", isDirectory: true)
            )
            try FileManager.default.createDirectory(
                at: home,
                withIntermediateDirectories: true
            )
            guard setenv("GLASSMACS_HOME", home.path, 1) == 0 else {
                throw BootstrapError.cannotConfigureHome(home.path)
            }

            let arguments = configuration.emacsArguments(
                forwarding: Array(CommandLine.arguments.dropFirst())
            )
            let cArguments: [UnsafeMutablePointer<CChar>?] =
                arguments.map { strdup($0) } + [nil]
            cArguments.withUnsafeBufferPointer { buffer in
                _ = execv(configuration.emacsExecutable.path, buffer.baseAddress!)
            }
            throw BootstrapError.cannotLaunchEmacs(String(cString: strerror(errno)))
        } catch {
            "Glassmacs: \(error.localizedDescription)\n".withCString {
                fputs($0, stderr)
            }
            exit(EXIT_FAILURE)
        }
    }
}

enum BootstrapError: LocalizedError {
    case missingExecutable(String)
    case missingConfiguration(String)
    case cannotConfigureHome(String)
    case cannotLaunchEmacs(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let path):
            return "Bundled Emacs is missing or not executable: \(path)"
        case .missingConfiguration(let path):
            return "Bundled Glassmacs configuration is missing: \(path)"
        case .cannotConfigureHome(let path):
            return "Could not set GLASSMACS_HOME to \(path)"
        case .cannotLaunchEmacs(let reason):
            return "Could not start bundled Emacs: \(reason)"
        }
    }
}
