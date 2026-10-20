import Foundation
import XCTest
@testable import GlassmacsLauncherCore

final class LaunchConfigurationTests: XCTestCase {
    func testEmacsArgumentsPreservePathsAsSeparateArguments() {
        let configuration = LaunchConfiguration(
            emacsExecutable: "/Applications/Emacs.app/Contents/MacOS/Emacs",
            checkoutPath: "/Users/test/Glass macs"
        )
        let files = [
            URL(fileURLWithPath: "/Users/test/Research folder/analysis.R"),
            URL(fileURLWithPath: "/Users/test/Research folder/plot's data.R")
        ]

        XCTAssertEqual(
            configuration.emacsArguments(opening: files),
            [
                "-Q", "--load", "/Users/test/Glass macs/init.el", "--",
                "/Users/test/Research folder/analysis.R",
                "/Users/test/Research folder/plot's data.R"
            ]
        )
    }

    func testClientArgumentsUseSocketAndKeepEachFileWhole() {
        let configuration = LaunchConfiguration(
            emacsExecutable: "/Applications/Emacs.app/Contents/MacOS/Emacs",
            checkoutPath: "/tmp/Glassmacs",
            homePath: "/Users/test/.config/glass macs"
        )
        let file = URL(fileURLWithPath: "/tmp/source with spaces.R")
        XCTAssertEqual(
            configuration.emacsClientArguments(opening: [file]),
            [
                "--socket-name=/Users/test/.config/glass macs/server-sockets/glassmacs",
                "--no-wait",
                "--eval",
                "(glassmacs-open-files-from-client (mapcar (lambda (path) (decode-coding-string (base64-decode-string path) 'utf-8)) '(\"L3RtcC9zb3VyY2Ugd2l0aCBzcGFjZXMuUg==\")))"
            ]
        )
    }

    func testClientEncodesMetacharactersInsteadOfBuildingExecutableCodeFromPath() {
        let configuration = LaunchConfiguration(
            emacsExecutable: "/Applications/Emacs.app/Contents/MacOS/Emacs",
            checkoutPath: "/tmp/Glassmacs",
            homePath: "/tmp/glassmacs-home"
        )
        let file = URL(fileURLWithPath: "/tmp/a\") (delete-file \"/tmp/x\").R")
        let arguments = configuration.emacsClientArguments(opening: [file])
        XCTAssertEqual(arguments.count, 4)
        XCTAssertFalse(arguments[3].contains(file.path))
        XCTAssertTrue(arguments[3].hasPrefix("(glassmacs-open-files-from-client "))
    }

    func testExistingServerProbeIsBoundedAndUsesGlassmacsSocket() {
        let configuration = LaunchConfiguration(
            emacsExecutable: "/Applications/Emacs.app/Contents/MacOS/Emacs",
            checkoutPath: "/tmp/Glassmacs",
            homePath: "/Users/test/.config/glassmacs"
        )
        XCTAssertEqual(
            configuration.emacsServerProbeArguments,
            [
                "--socket-name=/Users/test/.config/glassmacs/server-sockets/glassmacs",
                "--timeout=1", "--eval", "(emacs-pid)"
            ]
        )
    }
}
