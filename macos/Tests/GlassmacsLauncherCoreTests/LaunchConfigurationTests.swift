import Foundation
import XCTest
@testable import GlassmacsLauncherCore

final class LaunchConfigurationTests: XCTestCase {
    func testBundlePathsAndArgumentsUseTheBundledEmacsAndConfiguration() {
        let configuration = LaunchConfiguration(
            bundleURL: URL(fileURLWithPath: "/Applications/Glass macs.app")
        )

        XCTAssertEqual(
            configuration.emacsExecutable.path,
            "/Applications/Glass macs.app/Contents/MacOS/Emacs"
        )
        XCTAssertEqual(
            configuration.initFile.path,
            "/Applications/Glass macs.app/Contents/Resources/Glassmacs/init.el"
        )
        XCTAssertEqual(
            configuration.emacsArguments(
                forwarding: ["/Users/test/Research folder/Δ.R"]
            ),
            [
                "-Q", "--load",
                "/Applications/Glass macs.app/Contents/Resources/Glassmacs/init.el",
                "/Users/test/Research folder/Δ.R"
            ]
        )
    }

    func testApplicationSupportIsDefaultAndEnvironmentCanOverrideIt() throws {
        let configuration = LaunchConfiguration(
            bundleURL: URL(fileURLWithPath: "/Applications/Glassmacs.app")
        )
        let defaultHome = URL(
            fileURLWithPath: "/Users/test/Library/Application Support/Glassmacs",
            isDirectory: true
        )

        XCTAssertEqual(
            try configuration.glassmacsHome(environment: [:], defaultHome: defaultHome),
            defaultHome.standardizedFileURL
        )
        XCTAssertEqual(
            try configuration.glassmacsHome(
                environment: ["GLASSMACS_HOME": "~/Glass macs state/Δ"],
                defaultHome: defaultHome
            ),
            URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Glass macs state/Δ", isDirectory: true)
                .standardizedFileURL
        )
    }

    func testRelativeGlassmacsHomeIsRejected() {
        let configuration = LaunchConfiguration(
            bundleURL: URL(fileURLWithPath: "/Applications/Glassmacs.app")
        )

        XCTAssertThrowsError(
            try configuration.glassmacsHome(
                environment: ["GLASSMACS_HOME": "relative/state"],
                defaultHome: URL(fileURLWithPath: "/Users/test/Library/Application Support/Glassmacs")
            )
        )
    }
}
