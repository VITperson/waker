import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            permissionSection
            controlsSection
            mouseSection
            windowsSection
            statusSection
        }
        .padding(16)
        .frame(width: 380)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Waker")
                .font(.title3.weight(.semibold))

            Text("Switch focus between selected windows on a repeating timer.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var permissionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    state.accessibilityGranted ? "Accessibility access is enabled" : "Accessibility access is required",
                    systemImage: state.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(state.accessibilityGranted ? .green : .orange)

                if !state.accessibilityGranted {
                    Text("macOS must allow Waker to control other apps before it can raise windows. After enabling access, click Refresh Access. If macOS still keeps it locked, use Relaunch Waker.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Request Access") {
                        state.requestAccessibilityAccess()
                    }

                    Button("Open Settings") {
                        state.openAccessibilitySettings()
                    }

                    Button("Refresh Access") {
                        state.refreshAccessibilityStatus()
                    }
                }

                if !state.accessibilityGranted && state.shouldSuggestAccessibilityRelaunch {
                    HStack {
                        Button("Relaunch Waker") {
                            state.relaunchApplication()
                        }
                    }
                }
            }
        } label: {
            Text("Permissions")
        }
    }

    private var controlsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Interval")
                    Spacer()
                    Text("\(state.intervalSeconds) sec")
                        .monospacedDigit()

                    Stepper("", value: intervalBinding, in: 1...3_600)
                    .labelsHidden()
                }

                HStack {
                    Button("Refresh Windows") {
                        state.refreshWindows()
                    }
                    .disabled(!state.accessibilityGranted)

                    Spacer()

                    Button(state.isRunning ? "Stop" : "Start") {
                        state.toggleRunning()
                    }
                    .tint(state.isRunning ? .red : .accentColor)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.accessibilityGranted || !state.hasRunnableAutomation)
                }

                HStack {
                    Text("\(state.selectedWindowCount) selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Select All") {
                        state.selectAllWindows()
                    }
                    .disabled(state.windows.isEmpty)

                    Button("Clear") {
                        state.clearSelection()
                    }
                    .disabled(state.selectedWindowCount == 0)
                }
            }
        } label: {
            Text("Loop")
        }
    }

    private var mouseSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Simulate mouse movement", isOn: mouseJiggleEnabledBinding)
                    .toggleStyle(.switch)

                if state.mouseJiggleEnabled {
                    HStack {
                        Text("Jiggle Every")
                        Spacer()
                        Text("\(state.mouseJiggleIntervalSeconds) sec")
                            .monospacedDigit()

                        Stepper("", value: mouseJiggleIntervalBinding, in: 1...3_600)
                            .labelsHidden()
                    }

                    Text("Moves the cursor a tiny amount and immediately returns it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text("Mouse")
        }
    }

    private var windowsSection: some View {
        GroupBox {
            if state.windows.isEmpty {
                Text("No windows available yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(state.windows) { window in
                            Toggle(isOn: selectionBinding(for: window.id)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(window.displayTitle)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)

                                    Text(window.appName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
            }
        } label: {
            Text("Windows")
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(state.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let currentWindowLabel = state.currentWindowLabel, state.isRunning {
                Label("Now focusing: \(currentWindowLabel)", systemImage: "arrow.trianglehead.clockwise")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            HStack {
                Spacer()

                Button("Quit Waker") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { state.intervalSeconds },
            set: { newValue in
                state.intervalSeconds = newValue
                state.intervalDidChange()
            }
        )
    }

    private var mouseJiggleEnabledBinding: Binding<Bool> {
        Binding(
            get: { state.mouseJiggleEnabled },
            set: { newValue in
                state.mouseJiggleEnabled = newValue
                state.mouseJiggleDidChange()
            }
        )
    }

    private var mouseJiggleIntervalBinding: Binding<Int> {
        Binding(
            get: { state.mouseJiggleIntervalSeconds },
            set: { newValue in
                state.mouseJiggleIntervalSeconds = newValue
                state.mouseJiggleDidChange()
            }
        )
    }

    private func selectionBinding(for windowID: String) -> Binding<Bool> {
        Binding(
            get: { state.selectedWindowIDs.contains(windowID) },
            set: { isSelected in
                state.toggleSelection(for: windowID, isSelected: isSelected)
            }
        )
    }
}
