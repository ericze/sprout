import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep: OnboardingStep = .identity
    @State private var draft = OnboardingDraft()
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            switch currentStep {
            case .identity:
                OnboardingIdentityStep(draft: $draft) {
                    saveBabyAndAdvance()
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

            case .permissions:
                OnboardingPermissionsStep {
                    completeOnboarding()
                }
            }
        }
        .animation(.easeInOut(duration: 0.8), value: currentStep)
        .onAppear {
            let repo = BabyRepository(modelContext: modelContext)
            OnboardingMigration.migrateIfNeeded(
                babyRepository: repo,
                defaults: UserDefaults.standard
            )

            withAnimation(.easeInOut(duration: 0.8)) {
                appeared = true
            }
        }
    }

    private func saveBabyAndAdvance() {
        let repo = BabyRepository(modelContext: modelContext)
        repo.createDefaultIfNeeded()
        repo.updateName(draft.trimmedName)
        repo.updateBirthDate(draft.birthDate)

        withAnimation {
            currentStep = .permissions
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.6)) {
            hasCompletedOnboarding = true
        }
    }
}
