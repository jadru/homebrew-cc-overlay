import SwiftUI

/// Displays active Claude sessions with project name, model, duration, and optional metadata.
struct SessionCardView: View {
    let sessions: [ActiveSession]
    var size: ComponentSize = .standard

    private let maxVisibleSessions = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(
                title: "Active Sessions",
                iconName: "terminal",
                size: size
            )

            ForEach(Array(sessions.prefix(maxVisibleSessions)), id: \.id) { session in
                sessionRow(session)
            }

            if sessions.count > maxVisibleSessions {
                Text("+ \(sessions.count - maxVisibleSessions) more")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active Claude sessions: \(sessions.count)")
    }

    @ViewBuilder
    private func sessionRow(_ session: ActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack {
                if let model = session.model {
                    Text(model)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(formatDuration(session.duration))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(session.displayName), model \(session.model ?? "unknown"), live for \(formatDuration(session.duration))"
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))s"
        }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes < 60 {
            return "\(minutes)m \(seconds)s"
        }

        let hours = minutes / 60
        let remainderMinutes = minutes % 60
        return "\(hours)h \(remainderMinutes)m"
    }
}
