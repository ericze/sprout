import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

enum TreasureComposeCopy {
    static func title(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.title", service: service, en: "Keep Today", zh: "Keep Today")
    }

    static func close(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.close", service: service, en: "Close", zh: "Close")
    }

    static func save(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.save", service: service, en: "Save", zh: "Save")
    }

    static func photoSourceTitle(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.photo_source.title", service: service, en: "Add a photo", zh: "Add a photo")
    }

    static func photoSourceCamera(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.photo_source.camera", service: service, en: "Take photo", zh: "Take photo")
    }

    static func photoSourceLibrary(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.photo_source.library", service: service, en: "Choose from Library", zh: "Choose from Library")
    }

    static func photoSourceLimit(maxCount: Int, service: LocalizationService = .current) -> String {
        L10n.format(
            "treasure.compose.photo_source.limit",
            service: service,
            en: "Up to %lld photos",
            zh: "Up to %lld photos",
            arguments: [maxCount]
        )
    }

    static func photoSourceLimitMessage(maxCount: Int, service: LocalizationService = .current) -> String {
        L10n.format(
            "treasure.compose.photo_source.limit_message",
            service: service,
            en: "This entry can hold up to %lld photos.",
            zh: "This entry can hold up to %lld photos.",
            arguments: [maxCount]
        )
    }

    static func discardTitle(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.discard.title", service: service, en: "Discard this entry?", zh: "Discard this entry?")
    }

    static func discardMessage(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.discard.message", service: service, en: "Nothing has been saved yet.", zh: "Nothing has been saved yet.")
    }

    static func continueEditing(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.discard.continue_editing", service: service, en: "Continue Editing", zh: "Continue Editing")
    }

    static func discard(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.discard.discard", service: service, en: "Discard", zh: "Discard")
    }

    static func saveFailureTitle(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.save_failure.title", service: service, en: "Couldn't save yet", zh: "Couldn't save yet")
    }

    static func saveFailureMessage(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.save_failure.message", service: service, en: "Please try again.", zh: "Please try again.")
    }

    static func retry(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.save_failure.retry", service: service, en: "Try Again", zh: "Try Again")
    }

    static func backToEdit(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.save_failure.back_to_edit", service: service, en: "Back to Edit", zh: "Back to Edit")
    }

    static func photoSectionTitle(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.photo.section_title", service: service, en: "Photos (optional)", zh: "Photos (optional)")
    }

    static func removePhotoAccessibility(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.photo.delete_accessibility", service: service, en: "Remove current photo", zh: "Remove current photo")
    }

    static func addMore(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.photo.add_more", service: service, en: "Add more", zh: "Add more")
    }

    static func emptyPhotoTitle(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.photo.empty_title", service: service, en: "Leave a set of photos", zh: "Leave a set of photos")
    }

    static func emptyPhotoSubtitle(maxCount: Int, service: LocalizationService = .current) -> String {
        L10n.format(
            "treasure.compose.photo.empty_subtitle",
            service: service,
            en: "Up to %lld photos, in the order you choose.",
            zh: "Up to %lld photos, in the order you choose.",
            arguments: [maxCount]
        )
    }

    static func noteTitle(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.note.title", service: service, en: "A short note", zh: "A short note")
    }

    static func notePlaceholder(service: LocalizationService = .current) -> String {
        L10n.text(
            "treasure.compose.note.placeholder",
            service: service,
            en: "What would you like to remember about today?",
            zh: "What would you like to remember about today?"
        )
    }

    static func milestoneTitle(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.milestone.title", service: service, en: "Mark as milestone", zh: "Mark as milestone")
    }

    static func milestoneAccessibility(service: LocalizationService = .current) -> String {
        L10n.text("treasure.compose.milestone.accessibility", service: service, en: "Mark as milestone", zh: "Mark as milestone")
    }
}

struct TreasureComposeModal: View {
    @Bindable var store: TreasureStore

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isShowingPhotoSourcePicker = false
    @State private var isShowingLibraryPicker = false
    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?
    @State private var focusedPhotoIndex = 0
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                composeHeader
                    .padding(.horizontal, AppTheme.Spacing.navigationHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 18)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        TreasureComposePhotoSection(
                            imagePaths: store.viewState.composeDraft.imageLocalPaths,
                            focusedIndex: $focusedPhotoIndex,
                            isInteractionEnabled: !isNoteFocused,
                            canAddMoreImages: remainingPhotoSlots > 0,
                            onTapAdd: { isShowingPhotoSourcePicker = true },
                            onRemove: removeImage(at:)
                        )

                        TreasureComposeNoteSection(
                            note: Binding(
                                get: { store.viewState.composeDraft.note },
                                set: { store.handle(.updateNote($0)) }
                            ),
                            isFocused: $isNoteFocused
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                    .padding(.bottom, 36)
                }
                .scrollDismissesKeyboard(.interactively)
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissNoteFocus()
                        }
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .confirmationDialog(TreasureComposeCopy.photoSourceTitle(), isPresented: $isShowingPhotoSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera), remainingPhotoSlots > 0 {
                    Button(TreasureComposeCopy.photoSourceCamera()) {
                        isShowingCamera = true
                    }
                }

                if remainingPhotoSlots > 0 {
                    Button(TreasureComposeCopy.photoSourceLibrary()) {
                        isShowingLibraryPicker = true
                    }
                } else {
                    Button(TreasureComposeCopy.photoSourceLimit(maxCount: TreasureLimits.maxImagesPerEntry)) {}
                }
            } message: {
                if remainingPhotoSlots == 0 {
                    Text(TreasureComposeCopy.photoSourceLimitMessage(maxCount: TreasureLimits.maxImagesPerEntry))
                }
            }
            .confirmationDialog(TreasureComposeCopy.discardTitle(), isPresented: Binding(
                get: { store.shouldShowDiscardConfirmation },
                set: { _ in }
            )) {
                Button(TreasureComposeCopy.continueEditing()) {
                    store.handle(.cancelDiscard)
                }

                Button(TreasureComposeCopy.discard(), role: .destructive) {
                    store.handle(.confirmDiscard)
                }
            } message: {
                Text(TreasureComposeCopy.discardMessage())
            }
            .alert(TreasureComposeCopy.saveFailureTitle(), isPresented: Binding(
                get: { store.shouldShowComposeFailure },
                set: { isPresented in
                    if !isPresented {
                        store.handle(.dismissComposeError)
                    }
                }
            )) {
                Button(TreasureComposeCopy.retry()) {
                    store.handle(.retrySaveCompose)
                }

                Button(TreasureComposeCopy.backToEdit()) {
                    store.handle(.dismissComposeError)
                }
            } message: {
                Text(TreasureComposeCopy.saveFailureMessage())
            }
            .photosPicker(
                isPresented: $isShowingLibraryPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: remainingPhotoSlots,
                matching: .images
            )
            .sheet(isPresented: $isShowingCamera) {
                SystemImagePicker(image: $capturedImage, sourceType: .camera)
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await persistPhotoItems(newItems)
                    await MainActor.run {
                        selectedPhotoItems = []
                    }
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                guard let newImage else { return }
                persistCapturedImage(newImage)
            }
            .onChange(of: store.viewState.composeDraft.imageLocalPaths) { _, newPaths in
                focusedPhotoIndex = max(0, min(focusedPhotoIndex, max(newPaths.count - 1, 0)))
            }
        }
        .interactiveDismissDisabled(store.viewState.composeDraft.hasAnyUserIntent)
    }

    private var remainingPhotoSlots: Int {
        max(TreasureLimits.maxImagesPerEntry - store.viewState.composeDraft.imageLocalPaths.count, 0)
    }

    private func dismissNoteFocus() {
        guard isNoteFocused else { return }
        isNoteFocused = false
    }

    private var composeHeader: some View {
        HStack {
            Button(TreasureComposeCopy.close()) {
                store.handle(.dismissCompose)
            }
            .font(AppTheme.Typography.meta)
            .foregroundStyle(AppTheme.Colors.secondaryText)

            Spacer()

            Text(TreasureComposeCopy.title())
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer()

            Button(TreasureComposeCopy.save()) {
                store.handle(.saveCompose)
            }
            .font(AppTheme.Typography.primaryButton)
            .foregroundStyle(store.isComposeSaveEnabled ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
            .disabled(!store.isComposeSaveEnabled)
        }
    }

    @MainActor
    private func persistPhotoItems(_ items: [PhotosPickerItem]) async {
        var storedPaths: [String] = []

        for item in items.prefix(remainingPhotoSlots) {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let imagePath = try TreasurePhotoStorage.storeImageData(data)
                storedPaths.append(imagePath)
            } catch {
                assertionFailure("Treasure photo library import failed: \(error)")
            }
        }

        guard !storedPaths.isEmpty else { return }

        store.handle(.appendImagePaths(storedPaths))
        focusedPhotoIndex = max(store.viewState.composeDraft.imageLocalPaths.count - 1, 0)
    }

    private func removeImage(at index: Int) {
        store.handle(.removeImage(at: index))
        focusedPhotoIndex = max(0, min(focusedPhotoIndex, max(store.viewState.composeDraft.imageLocalPaths.count - 1, 0)))
    }

    @MainActor
    private func persistCapturedImage(_ image: UIImage) {
        defer { capturedImage = nil }

        guard remainingPhotoSlots > 0 else { return }

        do {
            let imagePath = try TreasurePhotoStorage.storeImage(image)
            store.handle(.appendImagePaths([imagePath]))
            focusedPhotoIndex = max(store.viewState.composeDraft.imageLocalPaths.count - 1, 0)
        } catch {
            assertionFailure("Treasure camera store failed: \(error)")
        }
    }
}

private struct TreasureComposePhotoSection: View {
    let imagePaths: [String]
    @Binding var focusedIndex: Int
    let isInteractionEnabled: Bool
    let canAddMoreImages: Bool
    let onTapAdd: () -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(TreasureComposeCopy.photoSectionTitle())
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Spacer()

                Text("\(loadedImages.count)/\(TreasureLimits.maxImagesPerEntry)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }

            if let activeImage = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Color.clear
                        .aspectRatio(TreasureTheme.mediaAspectRatio, contentMode: .fit)
                        .overlay {
                            Image(uiImage: activeImage.image)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                    Button(action: { onRemove(activeImage.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.cardBackground.opacity(0.92))
                            .clipShape(Circle())
                            .padding(14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TreasureComposeCopy.removePhotoAccessibility())
                }
                .allowsHitTesting(isInteractionEnabled)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(loadedImages) { item in
                            Button {
                                focusedIndex = item.id
                            } label: {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(
                                                item.id == selectedImage?.id ? TreasureTheme.sageDeep : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        if canAddMoreImages {
                            Button(action: onTapAdd) {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.viewfinder")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(TreasureTheme.sageDeep)

                                    Text(TreasureComposeCopy.addMore())
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                                .frame(width: 90, height: 72)
                                .background(AppTheme.Colors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .allowsHitTesting(isInteractionEnabled)
            } else {
                Button(action: onTapAdd) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text(TreasureComposeCopy.emptyPhotoTitle())
                            .font(AppTheme.Typography.sheetBody)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text(TreasureComposeCopy.emptyPhotoSubtitle(maxCount: TreasureLimits.maxImagesPerEntry))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                }
                .buttonStyle(.plain)
                .allowsHitTesting(isInteractionEnabled)
            }
        }
    }

    private var loadedImages: [LoadedComposeImage] {
        imagePaths.enumerated().compactMap { index, path in
            guard let image = UIImage(contentsOfFile: path) else { return nil }
            return LoadedComposeImage(id: index, image: image)
        }
    }

    private var selectedImage: LoadedComposeImage? {
        loadedImages.first(where: { $0.id == focusedIndex }) ?? loadedImages.first
    }
}

private struct LoadedComposeImage: Identifiable {
    let id: Int
    let image: UIImage
}

private struct TreasureComposeNoteSection: View {
    @Binding var note: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TreasureComposeCopy.noteTitle())
                .font(AppTheme.Typography.meta)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AppTheme.Colors.cardBackground)

                TextEditor(text: $note)
                    .font(AppTheme.Typography.sheetBody)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .scrollContentBackground(.hidden)
                    .focused(isFocused)
                    .padding(18)
                    .frame(minHeight: 180)

                if note.trimmed.isEmpty {
                    Text(TreasureComposeCopy.notePlaceholder())
                        .font(AppTheme.Typography.sheetBody)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 26)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 180)
        }
    }
}

private struct TreasureComposeMilestoneToggle: View {
    let isOn: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isOn ? AppTheme.Colors.highlight : AppTheme.Colors.secondaryText)

                Text(TreasureComposeCopy.milestoneTitle())
                    .font(AppTheme.Typography.sheetBody)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Spacer()

                Capsule()
                    .fill(isOn ? AppTheme.Colors.accent : AppTheme.Colors.divider)
                    .frame(width: 42, height: 26)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .padding(3)
                    }
            }
            .padding(18)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TreasureComposeCopy.milestoneAccessibility())
    }
}
