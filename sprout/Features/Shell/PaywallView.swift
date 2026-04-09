import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var selectedPlanIndex: Int = 1
    @State private var isPurchasing = false

    private var selectedProduct: Product? {
        guard !subscriptionManager.products.isEmpty else { return nil }
        let sorted = subscriptionManager.products.sorted { $0.price < $1.price }
        guard selectedPlanIndex < sorted.count else { return nil }
        return sorted[selectedPlanIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.section) {
                    closeButton
                    heroSection
                    featureList
                    planSelector
                    subscribeButton
                    footer
                }
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                .padding(.bottom, 40)
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
        }
    }

    private var closeButton: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(Circle())
            }
            Spacer()
        }
    }

    private var heroSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(L10n.text("paywall.title", en: "Sprout Pro", zh: "初长 Pro"))
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("paywall.subtitle", en: "Unlock all premium features", zh: "解锁全部高级功能"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .padding(.top, 8)
    }

    private var featureList: some View {
        VStack(spacing: 16) {
            PaywallFeatureRow(
                iconName: "figure.2.and.child",
                title: L10n.text("paywall.feature.multibaby.title", en: "Multi-Baby", zh: "多宝宝管理"),
                detail: L10n.text("paywall.feature.multibaby.detail", en: "Track multiple babies", zh: "记录多个宝宝的成长")
            )
            PaywallFeatureRow(
                iconName: "person.2",
                title: L10n.text("paywall.feature.family.title", en: "Family Group", zh: "家庭组"),
                detail: L10n.text("paywall.feature.family.detail", en: "Invite family to co-record", zh: "邀请家人共同记录")
            )
            PaywallFeatureRow(
                iconName: "cloud",
                title: L10n.text("paywall.feature.cloud.title", en: "Cloud Sync", zh: "云端同步"),
                detail: L10n.text("paywall.feature.cloud.detail", en: "Secure data backup", zh: "数据安全备份")
            )
            PaywallFeatureRow(
                iconName: "brain",
                title: L10n.text("paywall.feature.ai.title", en: "AI Assistant", zh: "AI 智能助手"),
                detail: L10n.text("paywall.feature.ai.detail", en: "Food advice, analysis & reports", zh: "辅食建议、分析、周报")
            )
        }
    }

    private var planSelector: some View {
        let products = subscriptionManager.products.sorted { $0.price < $1.price }

        return HStack(spacing: 12) {
            ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                let isYearly = product.id == ProductID.yearly
                planCard(
                    index: index,
                    title: isYearly
                        ? L10n.text("paywall.plan.yearly", en: "Yearly", zh: "年付")
                        : L10n.text("paywall.plan.monthly", en: "Monthly", zh: "月付"),
                    price: product.displayPrice,
                    showsBadge: isYearly
                )
            }
        }
    }

    private func planCard(index: Int, title: String, price: String, showsBadge: Bool) -> some View {
        let isSelected = selectedPlanIndex == index

        return Button(action: { selectedPlanIndex = index }) {
            VStack(spacing: 6) {
                if showsBadge {
                    Text(L10n.text("paywall.yearly.badge", en: "Save 40%", zh: "省 40%"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.accent)
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text(price)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? AppTheme.Colors.accent.opacity(0.12) : AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.divider, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var subscribeButton: some View {
        Button(action: performPurchase) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                }
                Text(L10n.text("paywall.subscribe", en: "Subscribe", zh: "订阅"))
                    .font(AppTheme.Typography.primaryButton)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
        }
        .disabled(isPurchasing || selectedProduct == nil)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: performRestore) {
                Text(L10n.text("paywall.restore", en: "Restore Purchases", zh: "恢复购买"))
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            HStack(spacing: 16) {
                Link(L10n.text("paywall.terms", en: "Terms of Service", zh: "服务条款"), destination: URL(string: "https://example.com/terms")!)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)

                Link(L10n.text("paywall.privacy", en: "Privacy Policy", zh: "隐私政策"), destination: URL(string: "https://example.com/privacy")!)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }

    private func performPurchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        Task {
            do {
                _ = try await subscriptionManager.purchase(product)
                dismiss()
            } catch {
                // User cancelled or system error — no-op for cancellation
            }
            isPurchasing = false
        }
    }

    private func performRestore() {
        Task {
            await subscriptionManager.restorePurchases()
        }
    }
}
