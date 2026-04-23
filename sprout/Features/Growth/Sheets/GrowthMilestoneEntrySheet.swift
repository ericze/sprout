import SwiftUI

struct GrowthMilestoneEntrySheet: View {
    @Bindable var store: GrowthStore

    private var draft: GrowthMilestoneDraft {
        store.viewState.milestoneDraft
    }

    private var isEditing: Bool {
        if case .edit = store.viewState.milestoneSheetState {
            return true
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    templateSelector
                    datePickerSection
                    noteSection
                }
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                .padding(.bottom, 36)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(isEditing
                ? L10n.text("growth.milestone.edit", en: "Edit Milestone", zh: "编辑里程碑")
                : L10n.text("growth.milestone.add", en: "Add Milestone", zh: "添加里程碑")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("common.cancel", en: "Cancel", zh: "取消")) {
                        store.handle(.dismissMilestoneSheet)
                    }
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("common.save", en: "Save", zh: "保存")) {
                        store.handle(.saveMilestone)
                    }
                    .font(AppTheme.Typography.primaryButton)
                    .foregroundStyle(isSaveEnabled ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
                    .disabled(!isSaveEnabled)
                }
            }
        }
    }

    private var isSaveEnabled: Bool {
        if draft.isCustom {
            return !draft.customTitle.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return draft.templateKey != nil
    }

    // MARK: - Template Selector

    private var templateSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(
                "growth.milestone.template.title",
                en: "Choose a milestone",
                zh: "选择里程碑"
            ))
            .font(AppTheme.Typography.meta)
            .foregroundStyle(AppTheme.Colors.secondaryText)

            customToggle

            if draft.isCustom {
                customTitleField
            } else {
                templateGrid
            }
        }
    }

    private var customToggle: some View {
        HStack(spacing: 10) {
            Image(systemName: draft.isCustom ? "pencil.line" : "list.bullet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(L10n.text(
                "growth.milestone.custom_toggle",
                en: "Custom milestone",
                zh: "自定义里程碑"
            ))
            .font(AppTheme.Typography.cardBody)
            .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer()

            Toggle("", isOn: Binding(
                get: { draft.isCustom },
                set: { newValue in
                    var updated = draft
                    updated.isCustom = newValue
                    if !newValue {
                        updated.customTitle = ""
                    }
                    store.handle(.updateMilestoneDraft(updated))
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(AppTheme.Colors.accent)
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sheetCard, style: .continuous))
    }

    private var customTitleField: some View {
        TextField(
            L10n.text(
                "growth.milestone.custom_placeholder",
                en: "e.g. First swim lesson",
                zh: "例如：第一次游泳课"
            ),
            text: Binding(
                get: { draft.customTitle },
                set: { newValue in
                    var updated = draft
                    updated.customTitle = newValue
                    store.handle(.updateMilestoneDraft(updated))
                }
            )
        )
        .font(AppTheme.Typography.sheetBody)
        .foregroundStyle(AppTheme.Colors.primaryText)
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sheetCard, style: .continuous))
    }

    private var templateGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(GrowthMilestoneTemplate.allCases, id: \.rawValue) { template in
                Button {
                    var updated = draft
                    updated.templateKey = template.rawValue
                    updated.category = template.category
                    updated.isCustom = false
                    store.handle(.updateMilestoneDraft(updated))
                } label: {
                    templateCell(for: template)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func templateCell(for template: GrowthMilestoneTemplate) -> some View {
        let isSelected = draft.templateKey == template.rawValue

        return VStack(alignment: .leading, spacing: 6) {
            Text(templateTitle(for: template))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(categoryLabel(for: template.category))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AppTheme.Colors.accent.opacity(0.12) : AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous)
                .stroke(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.divider, lineWidth: isSelected ? 1.5 : 1)
        }
    }

    // MARK: - Date Picker

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(
                "growth.milestone.date",
                en: "Date",
                zh: "日期"
            ))
            .font(AppTheme.Typography.meta)
            .foregroundStyle(AppTheme.Colors.secondaryText)

            DatePicker(
                "",
                selection: Binding(
                    get: { draft.occurredAt },
                    set: { newValue in
                        var updated = draft
                        updated.occurredAt = newValue
                        store.handle(.updateMilestoneDraft(updated))
                    }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .font(AppTheme.Typography.sheetBody)
        }
    }

    // MARK: - Note

    @State private var noteText: String = ""

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(
                "growth.milestone.note",
                en: "Note (optional)",
                zh: "备注（可选）"
            ))
            .font(AppTheme.Typography.meta)
            .foregroundStyle(AppTheme.Colors.secondaryText)

            TextField(
                L10n.text(
                    "growth.milestone.note_placeholder",
                    en: "Add a note...",
                    zh: "添加备注..."
                ),
                text: Binding(
                    get: { draft.note },
                    set: { newValue in
                        var updated = draft
                        updated.note = newValue
                        store.handle(.updateMilestoneDraft(updated))
                    }
                ),
                axis: .vertical
            )
            .lineLimit(2...4)
            .font(AppTheme.Typography.sheetBody)
            .foregroundStyle(AppTheme.Colors.primaryText)
            .padding(16)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sheetCard, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func templateTitle(for template: GrowthMilestoneTemplate) -> String {
        switch template {
        case .firstSmile:
            return L10n.text("growth.milestone.template.first_smile", en: "First smile", zh: "第一次微笑")
        case .firstLaugh:
            return L10n.text("growth.milestone.template.first_laugh", en: "First laugh", zh: "第一次大笑")
        case .firstRoll:
            return L10n.text("growth.milestone.template.first_roll", en: "First roll", zh: "第一次翻身")
        case .firstSit:
            return L10n.text("growth.milestone.template.first_sit", en: "First sit", zh: "第一次坐起")
        case .firstCrawl:
            return L10n.text("growth.milestone.template.first_crawl", en: "First crawl", zh: "第一次爬行")
        case .firstStand:
            return L10n.text("growth.milestone.template.first_stand", en: "First stand", zh: "第一次站立")
        case .firstStep:
            return L10n.text("growth.milestone.template.first_step", en: "First step", zh: "第一步")
        case .firstWord:
            return L10n.text("growth.milestone.template.first_word", en: "First word", zh: "第一个词")
        case .firstTooth:
            return L10n.text("growth.milestone.template.first_tooth", en: "First tooth", zh: "第一颗牙")
        }
    }

    private func categoryLabel(for category: GrowthMilestoneCategory) -> String {
        switch category {
        case .motor:
            return L10n.text("growth.milestone.category.motor", en: "Motor", zh: "运动")
        case .language:
            return L10n.text("growth.milestone.category.language", en: "Language", zh: "语言")
        case .social:
            return L10n.text("growth.milestone.category.social", en: "Social", zh: "社交")
        case .cognitive:
            return L10n.text("growth.milestone.category.cognitive", en: "Cognitive", zh: "认知")
        }
    }
}
