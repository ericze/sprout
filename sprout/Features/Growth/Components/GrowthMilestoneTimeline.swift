import SwiftUI

struct GrowthMilestoneTimeline: View {
    let milestones: [GrowthMilestoneEntry]
    let onAdd: () -> Void
    let onEdit: (GrowthMilestoneEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            if milestones.isEmpty {
                emptyState
            } else {
                milestoneCards
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text(L10n.text(
                "growth.milestone.section_title",
                en: "Milestones",
                zh: "里程碑"
            ))
            .font(AppTheme.Typography.cardTitle)
            .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.background.opacity(0.8))
                    .overlay {
                        Circle()
                            .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text(
                "growth.milestone.add",
                en: "Add milestone",
                zh: "添加里程碑"
            ))
        }
    }

    private var emptyState: some View {
        Button(action: onAdd) {
            VStack(spacing: 10) {
                Image(systemName: "star")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Text(L10n.text(
                    "growth.milestone.empty",
                    en: "Record your baby's first milestones",
                    zh: "记录宝宝的第一个里程碑"
                ))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
        }
        .buttonStyle(.plain)
    }

    private var milestoneCards: some View {
        VStack(spacing: AppTheme.Spacing.cardGap) {
            ForEach(milestones, id: \.id) { entry in
                Button { onEdit(entry) } label: {
                    milestoneCard(for: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func milestoneCard(for entry: GrowthMilestoneEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            categoryBadge(for: entry)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(AppTheme.Typography.cardBody)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)

                Text(entry.occurredAt, style: .date)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }

    private func categoryBadge(for entry: GrowthMilestoneEntry) -> some View {
        let category = GrowthMilestoneCategory(rawValue: entry.category) ?? .motor
        let icon: String = {
            switch category {
            case .motor: "figure.walk"
            case .language: "text.bubble"
            case .social: "heart"
            case .cognitive: "brain"
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(width: 36, height: 36)
            .background(AppTheme.Colors.iconBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
    }
}
