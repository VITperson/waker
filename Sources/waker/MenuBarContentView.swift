import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            permissionSection
            controlsSection
            mouseSection
            windowsSection
            statusSection
        }
        .padding(14)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Waker")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("Keep selected windows active on a repeating timer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                statusBadge(
                    title: state.isRunning ? "Running" : "Ready",
                    systemImage: state.isRunning ? "bolt.fill" : "pause.fill",
                    tint: state.isRunning ? .green : .secondary
                )

                statusBadge(
                    title: "\(state.selectedWindowCount) selected",
                    systemImage: "checkmark.circle",
                    tint: .secondary
                )
            }
        }
    }

    private var permissionSection: some View {
        sectionCard {
            sectionHeader(
                title: "Permissions",
                subtitle: state.accessibilityGranted
                    ? "Waker is allowed to control other apps."
                    : "Allow Accessibility access so Waker can switch windows and move the cursor.",
                systemImage: "checkmark.shield"
            )

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(state.accessibilityGranted ? .green : .orange)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill((state.accessibilityGranted ? Color.green : Color.orange).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.accessibilityGranted ? "Accessibility access is enabled" : "Accessibility access is required")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !state.accessibilityGranted {
                        Text("After enabling access in System Settings, click Refresh Access. If macOS still keeps it locked, use Relaunch Waker.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
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
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !state.accessibilityGranted && state.shouldSuggestAccessibilityRelaunch {
                HStack {
                    Spacer()

                    Button("Relaunch Waker") {
                        state.relaunchApplication()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
            }
        }
    }

    private var controlsSection: some View {
        sectionCard {
            sectionHeader(
                title: "Loop",
                subtitle: "Choose how often Waker should switch focus.",
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
            )

            configurationRow(title: "Interval", value: "\(state.intervalSeconds) sec") {
                Stepper("", value: intervalBinding, in: 1...3_600)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                Button("Refresh Windows") {
                    state.refreshWindows()
                }
                .disabled(!state.accessibilityGranted)

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
            .buttonStyle(.bordered)
            .controlSize(.small)

            HStack(alignment: .center, spacing: 10) {
                statusBadge(
                    title: "\(state.selectedWindowCount) window\(state.selectedWindowCount == 1 ? "" : "s")",
                    systemImage: "macwindow",
                    tint: .secondary
                )

                Spacer()

                Button(state.isRunning ? "Stop" : "Start") {
                    state.toggleRunning()
                }
                .buttonStyle(.borderedProminent)
                .tint(state.isRunning ? .red : .accentColor)
                .keyboardShortcut(.defaultAction)
                .disabled(!state.accessibilityGranted || !state.hasRunnableAutomation)
            }
        }
    }

    private var mouseSection: some View {
        sectionCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    sectionHeader(
                        title: "Mouse",
                        subtitle: "Optionally reset idle state with a tiny cursor movement.",
                        systemImage: "cursorarrow.motionlines"
                    )
                }

                Spacer(minLength: 12)

                Toggle("", isOn: mouseJiggleEnabledBinding)
                    .labelsHidden()
            }

            if state.mouseJiggleEnabled {
                configurationRow(title: "Jiggle Every", value: "\(state.mouseJiggleIntervalSeconds) sec") {
                    Stepper("", value: mouseJiggleIntervalBinding, in: 1...3_600)
                        .labelsHidden()
                }

                Text("Moves the cursor a tiny amount and immediately returns it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var windowsSection: some View {
        sectionCard {
            HStack(alignment: .top, spacing: 12) {
                sectionHeader(
                    title: "Windows",
                    subtitle: "Choose the windows Waker should rotate through.",
                    systemImage: "macwindow.on.rectangle"
                )

                Spacer(minLength: 12)

                statusBadge(
                    title: "\(state.windows.count) available",
                    systemImage: "list.bullet.rectangle",
                    tint: .secondary
                )
            }

            if state.windows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("No windows available yet", systemImage: "rectangle.on.rectangle.slash")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("Open a few regular app windows, then refresh the list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(rowBackground(isSelected: false))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(state.windows) { window in
                            Toggle(isOn: selectionBinding(for: window.id)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(window.displayTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)

                                    Text(window.appName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(rowBackground(isSelected: state.selectedWindowIDs.contains(window.id)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 240)
            }
        }
    }

    private var statusSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let currentWindowLabel = state.currentWindowLabel, state.isRunning {
                    Label("Now focusing \(currentWindowLabel)", systemImage: "arrow.trianglehead.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            Button("Quit Waker") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
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

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    private func sectionHeader(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func configurationRow<Content: View>(title: String, value: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            control()
        }
    }

    private func statusBadge(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.05),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
    }
}
