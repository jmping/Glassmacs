import ApplicationServices
import Foundation

private let checkboxTitle = "Apply this choice to all remaining modified documents"

struct Element: Encodable {
    let role: String?
    let title: String?
    let description: String?
    let value: String?
    let childrenStatus: String
    let children: [Element]
}

struct TreeReport: Encodable {
    let trusted: Bool
    let pid: Int32
    let windowsStatus: String
    let checkboxQuerySucceeded: Bool
    let checkboxMatches: [Element]
    let windows: [Element]
}

struct ActionReport: Encodable {
    let trusted: Bool
    let pid: Int32
    let operation: String
    let found: Bool
    let role: String?
    let title: String?
    let value: String?
    let performed: Bool
    let error: String?
}

struct AttributeReport: Encodable {
    let status: String
    let value: String?
}

struct MenuElement: Encodable {
    let role: String?
    let title: String?
    let description: String?
    let value: String?
    let childrenStatus: String
    let shortcutAttributes: [String: AttributeReport]
    let children: [MenuElement]
}

struct MenuReport: Encodable {
    let trusted: Bool
    let pid: Int32
    let menuBarStatus: String
    let menuBar: MenuElement?
    let fileMenuFound: Bool
    let fileMenu: MenuElement?
    let newDocumentFound: Bool
    let newDocument: MenuElement?
}

func attribute(_ element: AXUIElement, _ name: CFString) -> (AXError, CFTypeRef?) {
    var raw: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, name, &raw)
    return (status, raw)
}

func stringAttribute(_ element: AXUIElement, _ name: CFString) -> String? {
    let (status, raw) = attribute(element, name)
    guard status == .success, let raw else { return nil }
    if let value = raw as? String { return value }
    return String(describing: raw)
}

func children(_ element: AXUIElement) -> (String, [AXUIElement]) {
    let (status, raw) = attribute(element, kAXChildrenAttribute as CFString)
    guard status == .success else { return ("AXError(\(status.rawValue))", []) }
    return ("success", raw as? [AXUIElement] ?? [])
}

func snapshot(_ element: AXUIElement, depth: Int = 0) -> Element {
    let role = stringAttribute(element, kAXRoleAttribute as CFString)
    let title = stringAttribute(element, kAXTitleAttribute as CFString)
    let description = stringAttribute(element, kAXDescriptionAttribute as CFString)
    let value = stringAttribute(element, kAXValueAttribute as CFString)
    guard depth < 8 else {
        return Element(role: role, title: title, description: description,
                       value: value, childrenStatus: "depth-limit", children: [])
    }
    let (status, descendants) = children(element)
    return Element(role: role, title: title, description: description,
                   value: value, childrenStatus: status,
                   children: descendants.map { snapshot($0, depth: depth + 1) })
}

private let shortcutAttributeNames = [
    "AXMenuItemCmdChar", "AXMenuItemCmdModifiers",
    "AXMenuItemCmdGlyph", "AXMenuItemCmdVirtualKey"
]

func menuSnapshot(_ element: AXUIElement, depth: Int = 0) -> MenuElement {
    let shortcuts = Dictionary(uniqueKeysWithValues: shortcutAttributeNames.map { name in
        let (status, raw) = attribute(element, name as CFString)
        let value: String?
        if status == .success, let raw {
            value = (raw as? String) ?? String(describing: raw)
        } else {
            value = nil
        }
        return (name, AttributeReport(status: status == .success
            ? "success" : "AXError(\(status.rawValue))", value: value))
    })
    guard depth < 8 else {
        return MenuElement(role: stringAttribute(element, kAXRoleAttribute as CFString),
                           title: stringAttribute(element, kAXTitleAttribute as CFString),
                           description: stringAttribute(element, kAXDescriptionAttribute as CFString),
                           value: stringAttribute(element, kAXValueAttribute as CFString),
                           childrenStatus: "depth-limit", shortcutAttributes: shortcuts,
                           children: [])
    }
    let (childrenStatus, descendants) = children(element)
    return MenuElement(role: stringAttribute(element, kAXRoleAttribute as CFString),
                       title: stringAttribute(element, kAXTitleAttribute as CFString),
                       description: stringAttribute(element, kAXDescriptionAttribute as CFString),
                       value: stringAttribute(element, kAXValueAttribute as CFString),
                       childrenStatus: childrenStatus, shortcutAttributes: shortcuts,
                       children: descendants.map { menuSnapshot($0, depth: depth + 1) })
}

func findFileMenu(_ element: MenuElement) -> MenuElement? {
    if element.role == "AXMenuBarItem" && element.title == "File" { return element }
    for child in element.children {
        if let found = findFileMenu(child) { return found }
    }
    return nil
}

func findNewDocument(_ element: MenuElement) -> MenuElement? {
    if element.role == "AXMenuItem" && element.title == "New Document" { return element }
    for child in element.children {
        if let found = findNewDocument(child) { return found }
    }
    return nil
}

func menuReport(pid: Int32, app: AXUIElement) {
    let (status, raw) = attribute(app, kAXMenuBarAttribute as CFString)
    guard status == .success, let raw else {
        emit(MenuReport(trusted: AXIsProcessTrusted(), pid: pid,
                        menuBarStatus: "AXError(\(status.rawValue))",
                        menuBar: nil, fileMenuFound: false, fileMenu: nil,
                        newDocumentFound: false, newDocument: nil))
        return
    }
    let menuBar = raw as! AXUIElement
    let tree = menuSnapshot(menuBar)
    let fileMenu = findFileMenu(tree)
    let newDocument = fileMenu.flatMap(findNewDocument)
    emit(MenuReport(trusted: AXIsProcessTrusted(), pid: pid,
                    menuBarStatus: "success", menuBar: tree,
                    fileMenuFound: fileMenu != nil, fileMenu: fileMenu,
                    newDocumentFound: newDocument != nil, newDocument: newDocument))
}

func findElement(_ element: AXUIElement, role: String, title: String,
                 depth: Int = 0) -> AXUIElement? {
    guard depth < 12 else { return nil }
    let elementRole = stringAttribute(element, kAXRoleAttribute as CFString)
    let elementTitle = stringAttribute(element, kAXTitleAttribute as CFString) ?? ""
    let description = stringAttribute(element, kAXDescriptionAttribute as CFString) ?? ""
    if elementRole == role && (elementTitle == title || description == title) {
        return element
    }
    let (_, descendants) = children(element)
    for child in descendants {
        if let found = findElement(child, role: role, title: title, depth: depth + 1) {
            return found
        }
    }
    return nil
}

func windows(for app: AXUIElement) -> (String, [AXUIElement]) {
    let (status, elements) = children(app)
    return (status, elements.filter {
        stringAttribute($0, kAXRoleAttribute as CFString) == (kAXWindowRole as String)
    })
}

func emit<T: Encodable>(_ value: T) {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(value))
        FileHandle.standardOutput.write(Data("\n".utf8))
    } catch {
        fputs("could not encode AX report: \(error)\n", stderr)
        exit(1)
    }
}

func treeReport(pid: Int32, app: AXUIElement) {
    let (windowsStatus, rawWindows) = windows(for: app)
    let snapshots = rawWindows.map { snapshot($0) }
    let all = snapshots.flatMap { [$0] + $0.children.flatMap(flatten) }
    let matches = all.filter {
        $0.role == (kAXCheckBoxRole as String) &&
        [$0.title, $0.description].compactMap { $0 }.contains { $0.contains(checkboxTitle) }
    }
    emit(TreeReport(trusted: AXIsProcessTrusted(), pid: pid,
                    windowsStatus: windowsStatus,
                    checkboxQuerySucceeded: !matches.isEmpty,
                    checkboxMatches: matches, windows: snapshots))
}

func flatten(_ element: Element) -> [Element] {
    [element] + element.children.flatMap(flatten)
}

func operate(pid: Int32, app: AXUIElement, operation: String, target: String?) {
    let (windowStatus, appWindows) = windows(for: app)
    let role: String
    let title: String
    let element: AXUIElement?
    switch operation {
    case "checkbox":
        role = kAXCheckBoxRole as String
        title = checkboxTitle
        element = appWindows.lazy.compactMap {
            findElement($0, role: role, title: title)
        }.first
    case "button":
        role = kAXButtonRole as String
        title = target ?? ""
        element = appWindows.lazy.compactMap {
            findElement($0, role: role, title: title)
        }.first
    case "close":
        role = "AXCloseButton"
        title = "Close"
        element = appWindows.lazy.compactMap { window -> AXUIElement? in
            let (status, raw) = attribute(window, kAXCloseButtonAttribute as CFString)
            if status == .success, let raw {
                return (raw as! AXUIElement)
            }
            return findElement(window, role: role, title: title)
        }.first
    default:
        role = ""
        title = ""
        element = nil
    }

    guard let element else {
        emit(ActionReport(trusted: AXIsProcessTrusted(), pid: pid,
                          operation: operation, found: false, role: role,
                          title: title, value: nil, performed: false,
                          error: windowStatus == "success"
                            ? "matching Accessibility element not found" : windowStatus))
        exit(1)
    }

    let valueBefore = stringAttribute(element, kAXValueAttribute as CFString)
    if operation == "checkbox" && (target == nil || target == "read") {
        emit(ActionReport(trusted: AXIsProcessTrusted(), pid: pid,
                          operation: "checkbox-read", found: true, role: role,
                          title: title, value: valueBefore, performed: true, error: nil))
        return
    }

    let status = AXUIElementPerformAction(element, kAXPressAction as CFString)
    let success = status == .success
    emit(ActionReport(trusted: AXIsProcessTrusted(), pid: pid,
                      operation: operation, found: true, role: role, title: title,
                      value: stringAttribute(element, kAXValueAttribute as CFString),
                      performed: success,
                      error: success ? nil : "AXError(\(status.rawValue))"))
    if !success { exit(1) }
}

guard CommandLine.arguments.count >= 2,
      let pid = Int32(CommandLine.arguments[1]) else {
    fputs("usage: macos-ax-probe PID [tree|menu|checkbox read|toggle|button TITLE|close]\n", stderr)
    exit(2)
}

let app = AXUIElementCreateApplication(pid)
if CommandLine.arguments.count == 2 || CommandLine.arguments[2] == "tree" {
    treeReport(pid: pid, app: app)
} else if CommandLine.arguments[2] == "menu" {
    menuReport(pid: pid, app: app)
} else if CommandLine.arguments.count >= 3 {
    let operation = CommandLine.arguments[2]
    let target = CommandLine.arguments.count >= 4 ? CommandLine.arguments[3] : nil
    operate(pid: pid, app: app, operation: operation, target: target)
} else {
    fputs("invalid AX operation\n", stderr)
    exit(2)
}
