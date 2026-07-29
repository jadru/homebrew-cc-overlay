import Foundation
import Observation

@Observable
@MainActor
final class CodexAccountProfileStore {
    enum StoreError: LocalizedError, Equatable {
        case duplicatePath
        case emptyName
        case emptyPath
        case profileNotFound

        var errorDescription: String? {
            switch self {
            case .duplicatePath: return "A Codex account already uses this CODEX_HOME."
            case .emptyName: return "Enter an account name."
            case .emptyPath: return "Enter a CODEX_HOME path."
            case .profileNotFound: return "The Codex account profile no longer exists."
            }
        }
    }

    private enum Key {
        static let profiles = "codexAccountProfiles.v1"
        static let selectedProfileID = "selectedCodexAccountProfileID.v1"
    }

    private let defaults: UserDefaults
    private let userHome: String
    private(set) var profiles: [CodexAccountProfile]
    private(set) var selectedProfileID: UUID?

    init(
        defaults: UserDefaults = .standard,
        userHome: String = FileManager.default.homeDirectoryForCurrentUser.path,
        createsDefaultProfile: Bool = true
    ) {
        self.defaults = defaults
        self.userHome = userHome

        let storedData = defaults.data(forKey: Key.profiles)
        let decoded: [CodexAccountProfile]
        if let data = storedData,
           let stored = try? JSONDecoder().decode([CodexAccountProfile].self, from: data) {
            decoded = stored
        } else {
            decoded = []
        }

        if storedData == nil && createsDefaultProfile {
            let defaultProfile = CodexAccountProfile(
                displayName: "Default",
                codexHome: CodexAccountProfile.normalizedCodexHome("~/.codex", userHome: userHome)
            )
            profiles = [defaultProfile]
            selectedProfileID = defaultProfile.id
        } else {
            profiles = Self.sorted(decoded)
            selectedProfileID = defaults.string(forKey: Key.selectedProfileID).flatMap(UUID.init(uuidString:))
                ?? profiles.first(where: \.isEnabled)?.id
        }

        repairSelection()
        persist()
    }

    var enabledProfiles: [CodexAccountProfile] {
        profiles.filter(\.isEnabled)
    }

    var selectedProfile: CodexAccountProfile? {
        guard let selectedProfileID else { return enabledProfiles.first }
        return profiles.first { $0.id == selectedProfileID && $0.isEnabled } ?? enabledProfiles.first
    }

    var suggestedProfilePath: String {
        var nextIndex = 1
        while profiles.contains(where: {
            $0.codexHome == "\(userHome)/.codex-accounts/account-\(nextIndex)"
        }) {
            nextIndex += 1
        }
        return "\(userHome)/.codex-accounts/account-\(nextIndex)"
    }

    @discardableResult
    func addProfile(displayName: String, codexHome: String) throws -> CodexAccountProfile {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw StoreError.emptyName }
        guard !codexHome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError.emptyPath
        }

        let normalized = CodexAccountProfile.normalizedCodexHome(codexHome, userHome: userHome)
        guard !profiles.contains(where: { $0.codexHome == normalized }) else {
            throw StoreError.duplicatePath
        }

        let profile = CodexAccountProfile(
            displayName: name,
            codexHome: normalized,
            sortOrder: profiles.count
        )
        profiles.append(profile)
        selectedProfileID = profile.id
        persist()
        return profile
    }

    func select(_ profileID: UUID) throws {
        guard profiles.contains(where: { $0.id == profileID && $0.isEnabled }) else {
            throw StoreError.profileNotFound
        }
        selectedProfileID = profileID
        persist()
    }

    func setEnabled(_ isEnabled: Bool, for profileID: UUID) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            throw StoreError.profileNotFound
        }
        profiles[index].isEnabled = isEnabled
        repairSelection()
        persist()
    }

    func rename(_ profileID: UUID, to displayName: String) throws {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw StoreError.emptyName }
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            throw StoreError.profileNotFound
        }
        profiles[index].displayName = name
        persist()
    }

    func remove(_ profileID: UUID) throws {
        guard profiles.contains(where: { $0.id == profileID }) else {
            throw StoreError.profileNotFound
        }
        profiles.removeAll { $0.id == profileID }
        for index in profiles.indices {
            profiles[index].sortOrder = index
        }
        repairSelection()
        persist()
    }

    private func repairSelection() {
        if let selectedProfileID,
           profiles.contains(where: { $0.id == selectedProfileID && $0.isEnabled }) {
            return
        }
        selectedProfileID = enabledProfiles.first?.id
    }

    private func persist() {
        profiles = Self.sorted(profiles)
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Key.profiles)
        }
        defaults.set(selectedProfileID?.uuidString, forKey: Key.selectedProfileID)
    }

    nonisolated private static func sorted(_ profiles: [CodexAccountProfile]) -> [CodexAccountProfile] {
        profiles.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }
}
