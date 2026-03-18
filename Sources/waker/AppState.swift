import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var windows: [ManagedWindow] = []
    @Published var selectedWindowIDs: Set<String> = []
    @Published var intervalSeconds = 30
    @Published var mouseJiggleEnabled = true
    @Published var mouseJiggleIntervalSeconds = 20
    @Published var isRunning = false
    @Published var accessibilityGranted = false
    @Published var shouldSuggestAccessibilityRelaunch = false
    @Published var statusMessage = "Select windows to start the loop."
    @Published var currentWindowLabel: String?

    private let windowManager = WindowManager()
    private let mouseJiggler = MouseJiggler()
    private var focusTimer: Timer?
    private var mouseTimer: Timer?
    private var accessibilityPollTimer: Timer?
    private var nextWindowIndex = 0
    private var lastRefreshDate: Date?
    private var lastAccessibilityPromptDate: Date?

    var selectedWindowCount: Int {
        selectedWindowIDs.count
    }

    var hasSelectedWindows: Bool {
        !selectedWindows.isEmpty
    }

    var hasRunnableAutomation: Bool {
        hasSelectedWindows || mouseJiggleEnabled
    }

    private var selectedWindows: [ManagedWindow] {
        windows.filter { selectedWindowIDs.contains($0.id) }
    }

    init() {
        refreshAccessibility(prompt: false)
        if accessibilityGranted {
            refreshWindows()
        } else {
            statusMessage = "Grant Accessibility access to let Waker control windows and send mouse movement."
            startAccessibilityPolling()
        }
    }

    func handleMenuOpened() {
        refreshAccessibilityStatus()
        guard accessibilityGranted else {
            return
        }

        let shouldRefresh = lastRefreshDate == nil || Date().timeIntervalSince(lastRefreshDate ?? .distantPast) > 5
        if shouldRefresh {
            refreshWindows()
        }
    }

    func refreshWindows() {
        refreshAccessibility(prompt: false)
        guard accessibilityGranted else {
            windows = []
            selectedWindowIDs = []
            stopAutomation(status: "Grant Accessibility access to let Waker control windows and send mouse movement.")
            return
        }

        let previousSelection = selectedWindowIDs
        windows = windowManager.fetchSwitchableWindows()
        lastRefreshDate = Date()

        let availableIDs = Set(windows.map(\.id))
        selectedWindowIDs = previousSelection.intersection(availableIDs)

        if windows.isEmpty {
            currentWindowLabel = nil
            if isRunning && !mouseJiggleEnabled {
                stopAutomation(status: "No regular app windows found. Open a few windows and refresh.")
            } else if isRunning {
                scheduleFocusTimerIfNeeded()
                statusMessage = "No regular app windows found. Mouse jiggle continues."
            } else if mouseJiggleEnabled {
                statusMessage = "No regular app windows found. Mouse jiggle can still run on its own."
            } else {
                statusMessage = "No regular app windows found. Open a few windows and refresh."
            }
        } else if selectedWindowIDs.isEmpty {
            currentWindowLabel = nil
            if isRunning && mouseJiggleEnabled {
                scheduleFocusTimerIfNeeded()
                statusMessage = runningStatusMessage()
            } else {
                statusMessage = idleStatusMessage()
            }
        } else if isRunning {
            scheduleFocusTimerIfNeeded()
            statusMessage = runningStatusMessage()
        } else {
            statusMessage = idleStatusMessage()
        }
    }

    func requestAccessibilityAccess() {
        lastAccessibilityPromptDate = Date()
        shouldSuggestAccessibilityRelaunch = false
        startAccessibilityPolling()
        refreshAccessibility(prompt: true)
        if accessibilityGranted {
            refreshWindows()
        } else {
            statusMessage = "Allow Waker in System Settings > Privacy & Security > Accessibility. Waker will refresh automatically after you come back."
        }
    }

    func openAccessibilitySettings() {
        lastAccessibilityPromptDate = Date()
        shouldSuggestAccessibilityRelaunch = false
        startAccessibilityPolling()
        windowManager.openAccessibilitySettings()
        statusMessage = "Enable Waker in Accessibility settings, then return here. If macOS still doesn't unlock it, use Relaunch Waker."
    }

    func refreshAccessibilityStatus() {
        refreshAccessibility(prompt: false)
        if accessibilityGranted {
            shouldSuggestAccessibilityRelaunch = false
            stopAccessibilityPolling()
            refreshWindows()
        } else if shouldSuggestAccessibilityRelaunch {
            statusMessage = "Accessibility still looks disabled. macOS sometimes needs a relaunch before the new permission takes effect."
        }
    }

    func relaunchApplication() {
        let appURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    self.statusMessage = "Couldn't relaunch Waker: \(error.localizedDescription)"
                    return
                }

                NSApplication.shared.terminate(nil)
            }
        }
    }

    func toggleSelection(for windowID: String, isSelected: Bool) {
        if isSelected {
            selectedWindowIDs.insert(windowID)
        } else {
            selectedWindowIDs.remove(windowID)
        }

        if isRunning && !hasSelectedWindows && !mouseJiggleEnabled {
            stopAutomation(status: "All selected windows were removed from the loop.")
        } else if isRunning {
            scheduleFocusTimerIfNeeded()
            if !hasSelectedWindows {
                currentWindowLabel = nil
            }
            statusMessage = runningStatusMessage()
        } else {
            statusMessage = idleStatusMessage()
        }
    }

    func selectAllWindows() {
        selectedWindowIDs = Set(windows.map(\.id))
        if isRunning {
            scheduleFocusTimerIfNeeded()
            statusMessage = runningStatusMessage()
        } else {
            statusMessage = idleStatusMessage()
        }
    }

    func clearSelection() {
        selectedWindowIDs.removeAll()
        currentWindowLabel = nil
        if isRunning && !mouseJiggleEnabled {
            stopAutomation(status: "Selection cleared. Loop stopped.")
        } else if isRunning {
            scheduleFocusTimerIfNeeded()
            statusMessage = "Window switching stopped. Mouse jiggle continues."
        } else {
            statusMessage = idleStatusMessage()
        }
    }

    func toggleRunning() {
        if isRunning {
            stopAutomation(status: "Loop stopped.")
        } else {
            startAutomation()
        }
    }

    func intervalDidChange() {
        intervalSeconds = max(1, min(intervalSeconds, 3_600))
        guard isRunning else {
            statusMessage = idleStatusMessage()
            return
        }

        scheduleFocusTimerIfNeeded()
        statusMessage = runningStatusMessage()
    }

    func mouseJiggleDidChange() {
        mouseJiggleIntervalSeconds = max(1, min(mouseJiggleIntervalSeconds, 3_600))

        if isRunning && !hasSelectedWindows && !mouseJiggleEnabled {
            stopAutomation(status: "Mouse jiggle disabled. Nothing left to run.")
            return
        }

        if isRunning {
            scheduleMouseTimerIfNeeded()
            statusMessage = runningStatusMessage()
        } else {
            statusMessage = idleStatusMessage()
        }
    }

    private func startAutomation() {
        refreshWindows()
        guard accessibilityGranted else {
            return
        }

        guard hasRunnableAutomation else {
            statusMessage = "Pick at least one window or enable mouse jiggle before starting."
            return
        }

        nextWindowIndex = 0
        isRunning = true
        scheduleFocusTimerIfNeeded()
        scheduleMouseTimerIfNeeded()
        statusMessage = runningStatusMessage()

        if hasSelectedWindows {
            advanceToNextWindow()
        } else if mouseJiggleEnabled {
            jiggleMouse()
        }
    }

    private func scheduleFocusTimerIfNeeded() {
        focusTimer?.invalidate()
        focusTimer = nil

        guard isRunning, !selectedWindows.isEmpty else {
            return
        }

        focusTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceToNextWindow()
            }
        }

        if let focusTimer {
            RunLoop.main.add(focusTimer, forMode: .common)
        }
    }

    private func scheduleMouseTimerIfNeeded() {
        mouseTimer?.invalidate()
        mouseTimer = nil

        guard isRunning, mouseJiggleEnabled else {
            return
        }

        mouseTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(mouseJiggleIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.jiggleMouse()
            }
        }

        if let mouseTimer {
            RunLoop.main.add(mouseTimer, forMode: .common)
        }
    }

    private func stopAutomation(status: String) {
        focusTimer?.invalidate()
        focusTimer = nil
        mouseTimer?.invalidate()
        mouseTimer = nil
        isRunning = false
        currentWindowLabel = nil
        nextWindowIndex = 0
        statusMessage = status
    }

    private func advanceToNextWindow() {
        guard isRunning else {
            return
        }

        let currentSelection = selectedWindows
        guard !currentSelection.isEmpty else {
            currentWindowLabel = nil
            if mouseJiggleEnabled {
                scheduleFocusTimerIfNeeded()
                statusMessage = "No selected windows. Mouse jiggle continues."
            } else {
                stopAutomation(status: "Pick at least one window before starting the loop.")
            }
            return
        }

        if nextWindowIndex >= currentSelection.count {
            nextWindowIndex = 0
        }

        let targetWindow = currentSelection[nextWindowIndex]
        let didFocus = windowManager.focus(window: targetWindow)

        guard didFocus else {
            refreshWindows()
            if selectedWindows.isEmpty {
                if mouseJiggleEnabled {
                    scheduleFocusTimerIfNeeded()
                    statusMessage = "Selected windows are no longer available. Mouse jiggle continues."
                } else {
                    stopAutomation(status: "Selected windows are no longer available.")
                }
            } else {
                statusMessage = "Couldn't focus \(targetWindow.displayLabel). The list was refreshed."
            }
            return
        }

        currentWindowLabel = targetWindow.displayLabel
        nextWindowIndex = (nextWindowIndex + 1) % currentSelection.count
    }

    private func jiggleMouse() {
        guard isRunning, mouseJiggleEnabled else {
            return
        }

        let didJiggle = mouseJiggler.jiggle()
        if !didJiggle {
            statusMessage = "Mouse jiggle failed. Check Accessibility permissions."
        }
    }

    private func idleStatusMessage() -> String {
        if hasSelectedWindows && mouseJiggleEnabled {
            return "Ready to cycle \(selectedWindowCount) window(s) and jiggle the mouse every \(mouseJiggleIntervalSeconds) seconds."
        }

        if hasSelectedWindows {
            return "Ready to cycle \(selectedWindowCount) window(s) every \(intervalSeconds) seconds."
        }

        if mouseJiggleEnabled {
            return "Mouse jiggle is enabled. Press Start to move the cursor every \(mouseJiggleIntervalSeconds) seconds."
        }

        return "Select one or more windows or enable mouse jiggle, then press Start."
    }

    private func runningStatusMessage() -> String {
        if hasSelectedWindows && mouseJiggleEnabled {
            return "Cycling \(selectedWindowCount) window(s) every \(intervalSeconds) seconds and jiggling the mouse every \(mouseJiggleIntervalSeconds) seconds."
        }

        if hasSelectedWindows {
            return "Cycling \(selectedWindowCount) window(s) every \(intervalSeconds) seconds."
        }

        return "Jiggling the mouse every \(mouseJiggleIntervalSeconds) seconds."
    }

    private func refreshAccessibility(prompt: Bool) {
        accessibilityGranted = windowManager.checkAccessibility(prompt: prompt)
        if accessibilityGranted {
            shouldSuggestAccessibilityRelaunch = false
        }
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()

        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollAccessibilityStatus()
            }
        }

        if let accessibilityPollTimer {
            RunLoop.main.add(accessibilityPollTimer, forMode: .common)
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }

    private func pollAccessibilityStatus() {
        refreshAccessibility(prompt: false)

        if accessibilityGranted {
            shouldSuggestAccessibilityRelaunch = false
            stopAccessibilityPolling()
            refreshWindows()
            statusMessage = idleStatusMessage()
            return
        }

        if let lastAccessibilityPromptDate,
           Date().timeIntervalSince(lastAccessibilityPromptDate) > 3 {
            shouldSuggestAccessibilityRelaunch = true
        }
    }
}
