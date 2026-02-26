import SwiftUI

/// Displays Enterprise spending limits: Individual seat, Seat Tier, and Organization.
struct EnterpriseQuotaCardView: View {
    let quota: EnterpriseQuota
    var size: ComponentSize = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            spendingRow("Your Seat", limit: quota.individualLimit, isPrimary: true)
            if quota.seatTierLimit.capDollars > 0 {
                spendingRow("\(quota.seatTier.displayName) Tier", limit: quota.seatTierLimit)
            }
            if quota.organizationLimit.capDollars > 0 {
                spendingRow("Organization", limit: quota.organizationLimit)
            }
            if let resetsAt = quota.individualLimit.resetsAt, resetsAt > Date() {
                resetFooter(resetsAt)
            }
        }
        .padding(size.padding)
        .frame(maxWidth: .infinity)
        .modifier(CardBackgroundModifier(useGlass: size == .standard, cornerRadius: size.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Enterprise quota: \(NumberFormatting.formatDollarCost(quota.individualLimit.remainingDollars)) remaining on your seat")
    }

    // MARK: - Header

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Enterprise Quota")
                    .font(size.headerFont)
                    .foregroundStyle(.secondary)
                if let orgName = quota.organizationName {
                    Text(orgName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Image(systemName: "building.2")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Spending Row

    @ViewBuilder
    private func spendingRow(_ label: String, limit: SpendingLimit, isPrimary: Bool = false) -> some View {
        let remainPct = 100.0 - limit.utilizationPercentage

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: isPrimary ? 10 : 9, weight: isPrimary ? .semibold : .regular))
                    .foregroundStyle(isPrimary ? .primary : .secondary)
                Spacer()
                Text("\(NumberFormatting.formatDollarCost(limit.remainingDollars)) left")
                    .font(.system(size: isPrimary ? 11 : 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.usageTint(for: remainPct))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.usageTint(for: remainPct))
                        .frame(width: geo.size.width * max(remainPct / 100.0, 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: limit.utilizationPercentage)
                }
            }
            .frame(height: isPrimary ? 6 : 4)

            HStack {
                Text("\(NumberFormatting.formatDollarCost(limit.usedDollars)) / \(NumberFormatting.formatDollarCost(limit.capDollars))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(limit.periodLabel)
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private func resetFooter(_ resetsAt: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 8))
            Text("Resets \(resetsAt, style: .relative)")
                .font(.system(size: 9))
        }
        .foregroundStyle(.tertiary)
    }
}

// MARK: - Previews

#Preview("Full Enterprise Quota") {
    EnterpriseQuotaCardView(
        quota: EnterpriseQuota(
            organizationName: "Acme Corp",
            seatTier: .premium,
            organizationLimit: SpendingLimit(
                capDollars: 50000, usedDollars: 12345,
                periodLabel: "Monthly", resetsAt: Date().addingTimeInterval(86400 * 18)
            ),
            seatTierLimit: SpendingLimit(
                capDollars: 10000, usedDollars: 3456,
                periodLabel: "Monthly", resetsAt: Date().addingTimeInterval(86400 * 18)
            ),
            individualLimit: SpendingLimit(
                capDollars: 2000, usedDollars: 876,
                periodLabel: "Monthly", resetsAt: Date().addingTimeInterval(86400 * 18)
            )
        ),
        size: .standard
    )
    .frame(width: 280)
    .padding()
}

#Preview("Near Limit") {
    EnterpriseQuotaCardView(
        quota: EnterpriseQuota(
            organizationName: "Startup Inc",
            seatTier: .standard,
            organizationLimit: SpendingLimit(
                capDollars: 5000, usedDollars: 4800,
                periodLabel: "Monthly", resetsAt: Date().addingTimeInterval(86400 * 3)
            ),
            seatTierLimit: SpendingLimit(
                capDollars: 1000, usedDollars: 950,
                periodLabel: "Monthly", resetsAt: Date().addingTimeInterval(86400 * 3)
            ),
            individualLimit: SpendingLimit(
                capDollars: 200, usedDollars: 185,
                periodLabel: "Monthly", resetsAt: Date().addingTimeInterval(86400 * 3)
            )
        ),
        size: .standard
    )
    .frame(width: 280)
    .padding()
}

#Preview("Compact Size") {
    EnterpriseQuotaCardView(
        quota: EnterpriseQuota(
            organizationName: "Dev Team",
            seatTier: .premium,
            organizationLimit: SpendingLimit(
                capDollars: 20000, usedDollars: 8000,
                periodLabel: "Monthly", resetsAt: nil
            ),
            seatTierLimit: .zero,
            individualLimit: SpendingLimit(
                capDollars: 3000, usedDollars: 1200,
                periodLabel: "Monthly", resetsAt: nil
            )
        ),
        size: .compact
    )
    .frame(width: 260)
    .padding()
}
