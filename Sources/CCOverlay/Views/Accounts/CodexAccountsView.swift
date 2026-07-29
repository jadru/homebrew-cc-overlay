import SwiftUI

struct CodexAccountsSettingsView: View {
    let profileStore: CodexAccountProfileStore
    let monitor: CodexAccountMonitor
    @Bindable var settings: AppSettings
    let onSelectionChange: () -> Void

    @State private var showingAddProfile = false
    @State private var newProfileName = ""
    @State private var newProfilePath = ""
    @State private var actionError: String?

    var body: some View {
        Form {
            Section("Codex account profiles") {
                ForEach(profileStore.profiles) { profile in
                    profileRow(profile)
                }

                Button {
                    newProfileName = ""
                    newProfilePath = profileStore.suggestedProfilePath
                    showingAddProfile = true
                } label: {
                    Label("Add Codex account", systemImage: "plus.circle")
                }

                Text("Each profile uses an isolated CODEX_HOME. Account credentials remain owned by Codex.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Refresh policy") {
                LabeledContent("Selected account") {
                    Text("Every \(Int(max(settings.refreshInterval, 15)))s")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Other accounts") {
                    Text("Every 5 min")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Maximum concurrency") {
                    Text("3 accounts")
                        .foregroundStyle(.secondary)
                }

                Button("Refresh all accounts") {
                    Task { await monitor.refreshAll(force: true) }
                }
                .disabled(!monitor.refreshingProfileIDs.isEmpty)
            }

            if let actionError {
                Section {
                    Label(actionError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddProfile) {
            addProfileSheet
        }
    }

    private func profileRow(_ profile: CodexAccountProfile) -> some View {
        let snapshot = monitor.snapshot(for: profile.id)
        let isSelected = profile.id == profileStore.selectedProfileID
        let isRefreshing = monitor.refreshingProfileIDs.contains(profile.id)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    do {
                        try profileStore.select(profile.id)
                        actionError = nil
                        onSelectionChange()
                        Task { await monitor.refresh(profile.id) }
                    } catch {
                        actionError = error.localizedDescription
                    }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!profile.isEnabled)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(profile.codexHome)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: { profile.isEnabled },
                        set: { value in
                            do {
                                try profileStore.setEnabled(value, for: profile.id)
                                actionError = nil
                                onSelectionChange()
                                Task { await monitor.refreshAll(force: true) }
                            } catch {
                                actionError = error.localizedDescription
                            }
                        }
                    )
                )
                .labelsHidden()
            }

            HStack(spacing: 12) {
                if let snapshot {
                    Label(
                        "\(NumberFormatting.formatPercentage(snapshot.headroom)) left",
                        systemImage: "gauge.with.dots.needle.50percent"
                    )
                    Label(
                        "\(NumberFormatting.formatTokenCount(snapshot.tokenActivity.tokens(on: .now))) tokens today",
                        systemImage: "number"
                    )
                } else if let error = monitor.errors[profile.id] {
                    Text(error)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text("Waiting for usage data")
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("Sign in") {
                    launchLogin(for: profile)
                }
                Button {
                    do {
                        try profileStore.remove(profile.id)
                        actionError = nil
                        onSelectionChange()
                        Task { await monitor.refreshAll(force: true) }
                    } catch {
                        actionError = error.localizedDescription
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove the profile from CC-Overlay. Its CODEX_HOME is not deleted.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private var addProfileSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Codex account")
                .font(.title2.bold())

            TextField("Account name", text: $newProfileName)
            TextField("CODEX_HOME", text: $newProfilePath)

            Text("After adding the profile, use Sign in to authenticate it in an isolated terminal session.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { showingAddProfile = false }
                Button("Add") {
                    do {
                        let profile = try profileStore.addProfile(
                            displayName: newProfileName,
                            codexHome: newProfilePath
                        )
                        actionError = nil
                        showingAddProfile = false
                        onSelectionChange()
                        launchLogin(for: profile)
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || newProfilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func launchLogin(for profile: CodexAccountProfile) {
        do {
            try TerminalLauncher.launch(
                command: TerminalLauncher.codexLoginCommand(codexHome: profile.codexHome),
                workingDirectory: FileManager.default.homeDirectoryForCurrentUser,
                terminal: settings.preferredTerminal
            )
            actionError = nil
        } catch {
            actionError = error.localizedDescription
        }
    }
}

struct CodexAccountsMenuView: View {
    let profileStore: CodexAccountProfileStore
    let monitor: CodexAccountMonitor
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Codex account", systemImage: "person.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(profileStore.enabledProfiles) { profile in
                        Button {
                            onSelect(profile.id)
                        } label: {
                            if profile.id == profileStore.selectedProfileID {
                                Label(profile.displayName, systemImage: "checkmark")
                            } else {
                                Text(profile.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(profileStore.selectedProfile?.displayName ?? "No account")
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if let snapshot = monitor.selectedSnapshot {
                HStack(spacing: 14) {
                    metric(
                        title: "Headroom",
                        value: NumberFormatting.formatPercentage(snapshot.headroom)
                    )
                    metric(
                        title: "Tokens today",
                        value: NumberFormatting.formatTokenCount(snapshot.tokenActivity.tokens(on: .now))
                    )
                    metric(
                        title: "Tokens · 7d",
                        value: NumberFormatting.formatTokenCount(snapshot.tokenActivity.tokens(inLastDays: 7))
                    )
                }
            } else if let selectedID = profileStore.selectedProfileID,
                      let error = monitor.errors[selectedID] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else if profileStore.selectedProfile != nil {
                ProgressView("Reading account usage...")
                    .controlSize(.small)
                    .font(.caption)
            } else {
                Text("Add or enable a Codex account in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let recommended = monitor.recommendedProfile,
               recommended.id != profileStore.selectedProfileID,
               let snapshot = monitor.snapshot(for: recommended.id) {
                HStack(spacing: 6) {
                    Text("Best: \(recommended.displayName) · \(NumberFormatting.formatPercentage(snapshot.headroom)) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Use") { onSelect(recommended.id) }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(10)
        .cardBackground(useGlass: true, cornerRadius: 12)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
