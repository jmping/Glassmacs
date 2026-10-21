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
            let environment = configuration.emacsEnvironment(
                environment: ProcessInfo.processInfo.environment
            )
            guard let deploymentTarget = environment["MACOSX_DEPLOYMENT_TARGET"],
                  setenv("MACOSX_DEPLOYMENT_TARGET", deploymentTarget, 1) == 0 else {
                throw BootstrapError.cannotConfigureDeploymentTarget
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
            let message = "Glassmacs: \(error.localizedDescription)\n"
            message.withCString {
                _ = write(STDERR_FILENO, $0, strlen($0))
            }
            exit(EXIT_FAILURE)
        }
    }
}

enum BootstrapError: LocalizedError {
    case missingExecutable(String)
    case missingConfiguration(String)
    case cannotConfigureHome(String)
    case cannotConfigureDeploymentTarget
    case cannotLaunchEmacs(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let path):
            return "Bundled Emacs is missing or not executable: \(path)"
        case .missingConfiguration(let path):
            return "Bundled Glassmacs configuration is missing: \(path)"
        case .cannotConfigureHome(let path):
            return "Could not set GLASSMACS_HOME to \(path)"
        case .cannotConfigureDeploymentTarget:
            return "Could not set MACOSX_DEPLOYMENT_TARGET for bundled Emacs"
        case .cannotLaunchEmacs(let reason):
            return "Could not start bundled Emacs: \(reason)"
        }
    }
}
