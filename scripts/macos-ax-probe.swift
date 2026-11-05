import ApplicationServices
import Foundation

struct Element: Encodable {
    let role: String?
    let title: String?
    let description: String?
    let value: String?
    let childrenStatus: String
    let children: [Element]
}

struct Report: Encodable {
    let trusted: Bool
    let pid: Int32
    let windowsStatus: String
    let checkboxQuerySucceeded: Bool
    let checkboxMatches: [Element]
    let windows: [Element]
}

func attribute(_ element: AXUIElement, _ name: CFString) -> (String, String) {
    var raw: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, name, &raw)
    guard status == .success, let raw else { return ("AXError(\(status.rawValue))", "") }
    return ("success", String(describing: raw))
}

func children(_ element: AXUIElement) -> (String, [AXUIElement]) {
    var raw: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &raw)
    guard status == .success else { return ("AXError(\(status.rawValue))", []) }
    return ("success", raw as? [AXUIElement] ?? [])
}

func snapshot(_ element: AXUIElement, depth: Int = 0) -> Element {
    let role = attribute(element, kAXRoleAttribute as CFString)
    let title = attribute(element, kAXTitleAttribute as CFString)
    let description = attribute(element, kAXDescriptionAttribute as CFString)
    let value = attribute(element, kAXValueAttribute as CFString)
    guard depth < 8 else {
        return Element(role: role.1, title: title.1, description: description.1,
                       value: value.1, childrenStatus: "depth-limit", children: [])
    }
    let (status, descendants) = children(element)
    return Element(role: role.1, title: title.1, description: description.1,
                   value: value.1, childrenStatus: status,
                   children: descendants.map { snapshot($0, depth: depth + 1) })
}

func flatten(_ element: Element) -> [Element] {
    [element] + element.children.flatMap(flatten)
}

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    fputs("usage: macos-ax-probe PID\n", stderr)
    exit(2)
}

let app = AXUIElementCreateApplication(pid)
let (windowsStatus, rawWindows) = children(app)
let windows = rawWindows.map { snapshot($0) }
let label = "Apply this choice to all remaining modified documents"
let all = windows.flatMap(flatten)
let matches = all.filter {
    $0.role == kAXCheckBoxRole as String &&
    [$0.title, $0.description].compactMap { $0 }.contains { $0.contains(label) }
}
let report = Report(trusted: AXIsProcessTrusted(), pid: pid,
                    windowsStatus: windowsStatus,
                    checkboxQuerySucceeded: !matches.isEmpty,
                    checkboxMatches: matches, windows: windows)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
do {
    let data = try encoder.encode(report)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    fputs("could not encode AX report: \(error)\n", stderr)
    exit(1)
}
