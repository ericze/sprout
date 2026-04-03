import SwiftUI

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
