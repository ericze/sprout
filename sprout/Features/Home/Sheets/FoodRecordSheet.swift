import Observation
import os
import PhotosUI
import SwiftUI
import UIKit

struct FoodRecordSheet: View {
    @Bindable var store: HomeStore

    @State private var customTagText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingPhotoSourcePicker = false
    @State private var isShowingLibraryPicker = false
    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?

    private let tagColumns = [GridItem(.adaptive(minimum: 88), spacing: 10)]

    var body: some View {
        BaseRecordSheet(title: store.foodSheetTitle, onClose: { store.requestFoodDismiss() }) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    FoodTagComposerSection(
                        text: $customTagText,
                        customTags: store.customFoodTags,
                        suggestions: store.foodTagSuggestions(for: customTagText),
                        columns: tagColumns,
                        onAdd: addCustomTag,
                        onSelectSuggestion: addSuggestedTag,
                        onRemove: store.toggleFoodTag
                    )

                    if let firstTasteHint = store.foodFirstTasteHint {
                        FoodFirstTasteHintCard(hint: firstTasteHint)
                    }

                    if !store.foodDraft.selectedTags.isEmpty {
                        FoodTagSection(
                            title: L10n.text("home.sheet.food.selected.title", en: "Selected", zh: "已选食材"),
                            tags: store.foodDraft.selectedTags,
                            selectedTags: store.foodDraft.selectedTags,
                            columns: tagColumns,
                            onToggle: store.toggleFoodTag
                        )
                    }

                    if !store.recentFoodTags.isEmpty {
                        FoodTagSection(
                            title: String(localized: "home.sheet.food.recent"),
                            tags: store.recentFoodTags,
                            selectedTags: store.foodDraft.selectedTags,
                            columns: tagColumns,
                            onToggle: store.toggleFoodTag
                        )
                    }

                    FoodTagSection(
                        title: String(localized: "home.sheet.food.common"),
                        tags: store.suggestedFoodTags,
                        selectedTags: store.foodDraft.selectedTags,
                        columns: tagColumns,
                        onToggle: store.toggleFoodTag
                    )

                    FoodNoteEditor(note: Binding(
                        get: { store.foodDraft.note },
                        set: { store.updateFoodNote($0) }
                    ))

                    FoodRecordTimeSection(
                        timestamp: Binding(
                            get: { store.foodDraftTimestamp },
                            set: { store.updateFoodTimestamp($0) }
                        )
                    )

                    FoodPhotoPickerSection(
                        imagePath: store.foodDraft.selectedImagePath,
                        onAddPhoto: {
                            isShowingPhotoSourcePicker = true
                        },
                        onRemovePhoto: store.removeFoodImage
                    )

                    if store.foodDraft.selectedImagePath != nil {
                        FoodAIAssistSection(store: store)
                    }
                }
                .padding(.bottom, 12)
            }
        } footer: {
            SheetPrimaryButton(title: store.foodPrimaryActionTitle, isEnabled: store.isFoodSaveEnabled) {
                store.handle(store.isEditingFoodRecord ? .saveRecordEdits : .saveFood)
            }
        }
        .confirmationDialog(String(localized: "home.sheet.food.dialog.add_photo"), isPresented: $isShowingPhotoSourcePicker) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(String(localized: "home.sheet.food.dialog.take_photo")) {
                    isShowingCamera = true
                }
            }

            Button(String(localized: "home.sheet.food.dialog.choose_library")) {
                isShowingLibraryPicker = true
            }
        }
        .confirmationDialog(String(localized: "home.sheet.food.dialog.discard_title"), isPresented: Binding(
            get: { store.isShowingFoodDiscardConfirmation },
            set: { _ in }
        )) {
            Button(String(localized: "home.sheet.food.dialog.continue_editing")) {
                store.keepEditingFoodDraft()
            }

            Button(String(localized: "home.sheet.food.dialog.discard"), role: .destructive) {
                store.discardFoodDraft()
            }
        }
        .photosPicker(
            isPresented: $isShowingLibraryPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .sheet(isPresented: $isShowingCamera) {
            SystemImagePicker(image: $capturedImage, sourceType: .camera)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await persistPhotoItem(newItem)
                selectedPhotoItem = nil
            }
        }
        .onChange(of: capturedImage) { _, newImage in
            guard let newImage else { return }
            do {
                let imagePath = try FoodPhotoStorage.storeImage(newImage)
                store.setFoodImagePath(imagePath)
                capturedImage = nil
                AppHaptics.lightImpact()
            } catch {
                AppLogger.persistence.error("Camera image store failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    @MainActor
    private func persistPhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let imagePath = try FoodPhotoStorage.storeImageData(data)
            store.setFoodImagePath(imagePath)
            AppHaptics.lightImpact()
        } catch {
            AppLogger.persistence.error("Photo library import failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func addCustomTag() {
        guard store.addFoodTag(customTagText) else { return }
        customTagText = ""
    }

    private func addSuggestedTag(_ tag: String) {
        guard store.addFoodTag(tag) else { return }
        customTagText = ""
    }
}

private struct FoodRecordTimeSection: View {
    @Binding var timestamp: Date

    var body: some View {
        RecordEditorDateField(
            title: L10n.text("home.sheet.food.time.title", en: "Time", zh: "时间"),
            date: $timestamp
        )
    }
}

private struct FoodFirstTasteHintCard: View {
    let hint: FoodFirstTasteHint

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "leaf")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accent)
                .padding(.top, 2)

            Text(hint.message)
                .font(AppTheme.Typography.meta)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

private struct FoodNoteEditor: View {
    @Binding var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "home.sheet.food.note.title"))
                .font(AppTheme.Typography.meta)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(AppTheme.Colors.cardBackground)

                TextEditor(text: $note)
                    .font(AppTheme.Typography.sheetBody)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .frame(minHeight: 120)

                if note.trimmed.isEmpty {
                    Text(String(localized: "home.sheet.food.note.placeholder"))
                        .font(AppTheme.Typography.sheetBody)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 22)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 120)
        }
    }
}

private struct FoodPhotoPickerSection: View {
    let imagePath: String?
    let onAddPhoto: () -> Void
    let onRemovePhoto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "home.sheet.food.photo.title"))
                .font(AppTheme.Typography.meta)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            if let imagePath {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        if let image = UIImage(contentsOfFile: imagePath) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "photo")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)

                                Text(L10n.text("home.sheet.food.photo.selected", en: "Selected photo", zh: "已选图片"))
                                    .font(AppTheme.Typography.sheetBody)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .background(AppTheme.Colors.cardBackground)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.image, style: .continuous))

                    HStack(spacing: 18) {
                        Button(action: onAddPhoto) {
                            Text(L10n.text("home.sheet.food.photo.replace", en: "Choose another photo", zh: "重选图片"))
                                .font(AppTheme.Typography.meta)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)

                        Button(action: onRemovePhoto) {
                            Text(L10n.text("home.sheet.food.photo.remove", en: "Remove photo", zh: "删除图片"))
                                .font(AppTheme.Typography.meta)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "home.sheet.food.photo.delete_accessibility"))
                    }
                }
            } else {
                Button(action: onAddPhoto) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text(String(localized: "home.sheet.food.photo.add"))
                            .font(AppTheme.Typography.sheetBody)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FoodAIAssistSection: View {
    @Bindable var store: HomeStore

    private let tagColumns = [GridItem(.adaptive(minimum: 88), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.viewState.foodAIState {
            case .idle:
                Button {
                    store.handle(.tapFoodAISuggest)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .medium))
                        Text(L10n.text("food.ai.suggest_button", en: "AI Suggest", zh: "AI 辅助识别"))
                            .font(AppTheme.Typography.meta)
                    }
                    .foregroundStyle(AppTheme.Colors.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.text("food.ai.loading", en: "Analyzing...", zh: "识别中..."))
                        .font(AppTheme.Typography.meta)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .padding(.vertical, 4)

            case let .suggestion(result):
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("food.ai.apply", en: "Apply Suggestions", zh: "应用建议"))
                        .font(AppTheme.Typography.meta)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    if !result.candidateTags.isEmpty {
                        LazyVGrid(columns: tagColumns, alignment: .leading, spacing: 10) {
                            ForEach(result.candidateTags, id: \.tag) { candidate in
                                Button {
                                    store.handle(.applyFoodAISuggestion)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 14))
                                        Text(candidate.tag)
                                            .font(AppTheme.Typography.meta)
                                    }
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.Colors.accent)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            store.handle(.applyFoodAISuggestion)
                        } label: {
                            Text(L10n.text("food.ai.apply", en: "Apply Suggestions", zh: "应用建议"))
                                .font(AppTheme.Typography.meta)
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.handle(.dismissFoodAISuggestion)
                        } label: {
                            Text(L10n.text("common.cancel", en: "Cancel", zh: "取消"))
                                .font(AppTheme.Typography.meta)
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }

            case let .failed(message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(AppTheme.Typography.meta)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    Button {
                        store.handle(.retryFoodAISuggestion)
                    } label: {
                        Text(L10n.text("food.ai.retry", en: "Retry", zh: "重试"))
                            .font(AppTheme.Typography.meta)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
