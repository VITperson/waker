import AppKit
import ApplicationServices
import Foundation

struct ManagedWindow: Identifiable {
    let id: String
    let pid: pid_t
    let appName: String
    let title: String
    let axWindow: AXUIElement

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Window" : trimmedTitle
    }

    var displayLabel: String {
        "\(appName) - \(displayTitle)"
    }
}

final class WindowManager {
    private let windowNumberAttribute = "AXWindowNumber" as CFString

    func checkAccessibility(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func fetchSwitchableWindows() -> [ManagedWindow] {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSWorkspace.shared.runningApplications
            .filter {
                $0.processIdentifier != currentPID &&
                !$0.isTerminated &&
                $0.activationPolicy == .regular
            }
            .sorted {
                ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending
            }

        var discoveredWindows: [ManagedWindow] = []
        var seenIdentifiers = Set<String>()

        for app in runningApps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = copyAttributeValue(appElement, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement] else {
                continue
            }

            let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"

            for (index, window) in windows.enumerated() {
                guard isSwitchable(window) else {
                    continue
                }

                let title = stringAttribute(window, attribute: kAXTitleAttribute as CFString) ?? ""
                let identifier = makeIdentifier(
                    pid: app.processIdentifier,
                    window: window,
                    fallbackIndex: index,
                    title: title
                )

                guard seenIdentifiers.insert(identifier).inserted else {
                    continue
                }

                discoveredWindows.append(
                    ManagedWindow(
                        id: identifier,
                        pid: app.processIdentifier,
                        appName: appName,
                        title: title,
                        axWindow: window
                    )
                )
            }
        }

        return discoveredWindows.sorted { lhs, rhs in
            if lhs.appName.caseInsensitiveCompare(rhs.appName) == .orderedSame {
                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            }

            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }
    }

    func focus(window: ManagedWindow) -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == window.pid }) else {
            return false
        }

        let appElement = AXUIElementCreateApplication(window.pid)
        let activationOptions: NSApplication.ActivationOptions = [.activateAllWindows, .activateIgnoringOtherApps]
        let activated = app.activate(options: activationOptions)

        let setMainResult = AXUIElementSetAttributeValue(window.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        let setFocusedResult = AXUIElementSetAttributeValue(window.axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        let setFocusedWindowResult = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window.axWindow)
        let raiseResult = AXUIElementPerformAction(window.axWindow, kAXRaiseAction as CFString)

        return activated || [setMainResult, setFocusedResult, setFocusedWindowResult, raiseResult].contains(.success)
    }

    private func isSwitchable(_ window: AXUIElement) -> Bool {
        if let role = stringAttribute(window, attribute: kAXRoleAttribute as CFString),
           role != (kAXWindowRole as String) {
            return false
        }

        if let subrole = stringAttribute(window, attribute: kAXSubroleAttribute as CFString) {
            let allowedSubroles = [
                kAXStandardWindowSubrole as String,
                kAXDialogSubrole as String,
            ]

            if !allowedSubroles.contains(subrole) {
                return false
            }
        }

        if let minimized = boolAttribute(window, attribute: kAXMinimizedAttribute as CFString),
           minimized {
            return false
        }

        return true
    }

    private func makeIdentifier(pid: pid_t, window: AXUIElement, fallbackIndex: Int, title: String) -> String {
        if let windowNumber = intAttribute(window, attribute: windowNumberAttribute) {
            return "\(pid)-\(windowNumber)"
        }

        return "\(pid)-\(fallbackIndex)-\(title.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func copyAttributeValue(_ element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        return value
    }

    private func stringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        copyAttributeValue(element, attribute: attribute) as? String
    }

    private func boolAttribute(_ element: AXUIElement, attribute: CFString) -> Bool? {
        if let number = copyAttributeValue(element, attribute: attribute) as? NSNumber {
            return number.boolValue
        }

        return copyAttributeValue(element, attribute: attribute) as? Bool
    }

    private func intAttribute(_ element: AXUIElement, attribute: CFString) -> Int? {
        if let number = copyAttributeValue(element, attribute: attribute) as? NSNumber {
            return number.intValue
        }

        return copyAttributeValue(element, attribute: attribute) as? Int
    }
}
