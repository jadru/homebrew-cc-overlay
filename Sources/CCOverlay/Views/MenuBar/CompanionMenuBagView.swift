import SwiftUI

/// A compact inventory view.  It intentionally names what an item does rather
/// than repeating the workshop's long-form progression explanation.
struct CompanionMenuBagView: View {
    let progress: PatchProgressStore

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
            Text("Care rewards")
                        .font(.title3.weight(.bold))
                    Text("Permanent gear and care rewards, kept separate from daily feeding.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(progress.unlockedGear.count)/\(PatchGear.allCases.count)", systemImage: "backpack.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Text("Workspace gear")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(PatchGear.allCases) { gear in
                    gearItem(gear)
                }
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.currentPet.map { "\($0.name)'s care rewards" } ?? "Companion care rewards")
                        .font(.subheadline.weight(.semibold))
                    Text(progress.currentPet == nil ? "Adopt a companion to begin care." : "The newest earned reward is equipped automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(progress.currentPet == nil ? "—" : "\(progress.currentCare.feedCount) meals")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(CompanionCareAccessory.allCases) { accessory in
                    accessoryItem(accessory)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func gearItem(_ gear: PatchGear) -> some View {
        let isUnlocked = progress.unlockedGear.contains(gear)

        return HStack(spacing: 8) {
            PatchGearImage(gear: gear, size: 26)
                .opacity(isUnlocked ? 1 : 0.28)
            Text(gear.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(gear.title), \(isUnlocked ? "unlocked" : "locked")")
    }

    private func accessoryItem(_ accessory: CompanionCareAccessory) -> some View {
        let isUnlocked = progress.currentPet != nil && progress.currentCare.unlockedAccessories.contains(accessory)
        let isEquipped = progress.careAccessory == accessory

        return HStack(spacing: 8) {
            CompanionCareAccessoryThumbnail(accessory: accessory, size: 27)
                .opacity(isUnlocked ? 1 : 0.26)
            Text(accessory.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isEquipped {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(accessory.title), \(isEquipped ? "equipped" : (isUnlocked ? "unlocked" : "locked"))")
    }
}
