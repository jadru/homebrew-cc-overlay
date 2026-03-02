import SwiftUI

struct CardHeader: View {
    let title: String
    let iconName: String
    let size: ComponentSize

    var body: some View {
        HStack {
            Text(title)
                .font(size.headerFont)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

