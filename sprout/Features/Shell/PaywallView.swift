import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var selectedPlanIndex: Int = 1
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var selectedProduct: Product? {
        guard PaywallContent.isPurchaseEnabled else { return nil }
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
                    if PaywallContent.isPurchaseEnabled {
                        planSelector
                        subscribeButton
                    }
                    footer
                }
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                .padding(.bottom, 40)
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
        }
        .alert(
            L10n.text("paywall.error.title", en: "Purchase needs attention", zh: "购买需要稍后再试"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(L10n.text("common.ok", en: "OK", zh: "好"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
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
            if PaywallContent.promotedFeatures.isEmpty {
                availabilityNotice
            } else {
                ForEach(PaywallContent.promotedFeatures) { feature in
                    PaywallFeatureRow(
                        iconName: feature.iconName,
                        title: L10n.text(feature.titleKey, en: feature.titleEN, zh: feature.titleZH),
                        detail: L10n.text(feature.detailKey, en: feature.detailEN, zh: feature.detailZH)
                    )
                }
            }
        }
    }

    private var availabilityNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("paywall.readiness.title", en: "Pro is not for sale yet", zh: "Pro 暂不开放购买"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("paywall.readiness.detail", en: "We will only open subscriptions after the promised Pro capabilities pass release checks. Your local records remain available.", zh: "只有在承诺的 Pro 能力通过发布验收后，订阅才会开放。本地记录会照常可用。"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
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
                Link(L10n.text("paywall.terms", en: "Terms of Service", zh: "服务条款"), destination: PaywallContent.termsURL)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)

                Link(L10n.text("paywall.privacy", en: "Privacy Policy", zh: "隐私政策"), destination: PaywallContent.privacyURL)
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
                errorMessage = L10n.text(
                    "paywall.purchase.failed",
                    en: "The purchase could not be completed. Please try again later.",
                    zh: "这次购买没有完成，请稍后再试。"
                )
            }
            isPurchasing = false
        }
    }

    private func performRestore() {
        Task {
            do {
                try await subscriptionManager.restorePurchases()
            } catch {
                errorMessage = L10n.text(
                    "paywall.restore.failed",
                    en: "Purchases could not be restored right now. Please try again later.",
                    zh: "现在暂时无法恢复购买，请稍后再试。"
                )
            }
        }
    }
}
