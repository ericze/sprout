import SwiftUI
import Photos

struct OnboardingIdentityStep: View {
    @Binding var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 120)

            Text(L10n.text("onboarding.greeting", en: "Hello, nice to meet you.", zh: "你好，初次见面。"))
                .font(.system(size: 28, design: .serif))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer().frame(height: 48)

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("onboarding.name_hint", en: "What shall we call the little one?", zh: "我们要记录的小生命，叫什么名字？"))
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                TextField("", text: $draft.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .tint(AppTheme.Colors.sageGreen)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(AppTheme.Colors.primaryText.opacity(0.3))
                            .frame(height: 0.5)
                    }
            }
            .padding(.horizontal, AppTheme.Spacing.screenHorizontal)

            Spacer().frame(height: 36)

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("onboarding.birthday_hint", en: "When did they arrive on Earth?", zh: "ta 是哪一天来到地球的？"))
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                DatePicker("", selection: $draft.birthDate, in: ...Date.now, displayedComponents: [.date])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .padding(.horizontal, AppTheme.Spacing.screenHorizontal)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text(L10n.text("onboarding.continue", en: "Continue", zh: "继续"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.sageGreen)
            }
            .disabled(!draft.isValid)
            .opacity(draft.isValid ? 1.0 : 0.3)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 2: 软性权限请求（V1 仅相册）

struct OnboardingPermissionsStep: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 160)

            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer().frame(height: 32)

            Text(L10n.text("onboarding.photo_title", en: "Amber of Moments", zh: "留住时光的琥珀"))
                .font(.system(size: 22, design: .serif))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Spacer().frame(height: 12)

            Text(L10n.text("onboarding.photo_subtitle", en: "We need photo access to treasure every picture.", zh: "我们需要相册权限，为你珍藏每一张照片。"))
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            Spacer().frame(height: 36)

            Button {
                requestPhotoAccess()
            } label: {
                Text(L10n.text("onboarding.photo_authorize", en: "Grant Photo Access", zh: "授权相册访问"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.sageGreen)
            }

            Spacer().frame(height: 16)

            Button {
                onComplete()
            } label: {
                Text(L10n.text("onboarding.skip", en: "Maybe Later", zh: "以后再说"))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 权限请求

    private func requestPhotoAccess() {
        Task {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            onComplete()
        }
    }
}
