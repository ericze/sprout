import Observation
import SwiftUI

@MainActor
@Observable
final class CloudSyncStatusStore {
    enum Phase: Equatable {
        case idle
        case syncing
        case error(String)
    }

    var phase: Phase = .idle
    var lastSyncAt: Date?
    var lastAttemptAt: Date?
    var pendingChangeCount = 0
    var pendingDeletionCount = 0

    @ObservationIgnored private var syncEngine: SyncEngine?

    func configure(syncEngine: SyncEngine?) {
        self.syncEngine = syncEngine
        refreshFromEngine()
    }

    func syncIfEligible(authState: AuthState, reason: SyncReason) async {
        guard case .authenticated = authState else {
            refreshFromEngine()
            return
        }
        guard phase != .syncing else { return }
        guard let syncEngine else {
            phase = .error(
                L10n.text(
                    "cloud_sync.status.error.unavailable",
                    en: "Cloud Sync is not ready on this device yet.",
                    zh: "这台设备上的云端同步暂时还未准备好。"
                )
            )
            return
        }

        lastAttemptAt = .now
        phase = .syncing
        await syncEngine.performFullSync(reason: reason)
        refreshFromEngine()
    }

    func refreshFromEngine() {
        guard let syncEngine else {
            phase = .idle
            lastSyncAt = nil
            pendingChangeCount = 0
            pendingDeletionCount = 0
            return
        }

        let state = syncEngine.syncUIState
        lastSyncAt = state.lastCompletedAt
        pendingChangeCount = state.pendingUpsertCount
        pendingDeletionCount = state.pendingDeletionCount
        phase = Self.phase(for: state.phase)
    }

    private static func phase(for syncPhase: SyncUIPhase) -> Phase {
        switch syncPhase {
        case .idle, .scheduled:
            .idle
        case .pushing:
            .syncing
        case let .error(message):
            .error(presentableMessage(for: SyncStatusError(message: message)))
        }
    }

    private static func presentableMessage(for error: Error) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            return L10n.text(
                "cloud_sync.status.error.fallback",
                en: "Cloud Sync needs a little more setup before it can finish.",
                zh: "云端同步还需要一点配置才能完成。"
            )
        }

        return description
    }
}

private struct SyncStatusError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

struct CloudSyncView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudSyncStatusStore.self) private var syncStatusStore
    let onOpenAccount: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.cardGap) {
                summaryCard
                detailCard
            }
            .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
            .padding(.vertical, 24)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(L10n.text("cloud_sync.title", en: "Cloud Sync", zh: "云端同步"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: summaryIconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .background(AppTheme.Colors.iconBackground)
                .clipShape(Circle())

            Text(summaryTitle)
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(summaryDetail)
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }

    @ViewBuilder
    private var detailCard: some View {
        if requiresAccount {
            accountPromptCard
        } else {
            syncStatusCard
        }
    }

    private var accountPromptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("cloud_sync.account_required.title", en: "Sign in before syncing", zh: "开始同步前先登录账号"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("cloud_sync.account_required.detail", en: "Your records stay local until you choose an account. Sign in once, then backup can happen quietly in the background.", zh: "在你选择账号前，记录会继续保留在本地。登录一次后，后台备份才会安静地开始。"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onOpenAccount) {
                Text(L10n.text("cloud_sync.account_required.cta", en: "Open Account", zh: "前往账号"))
                    .font(AppTheme.Typography.primaryButton)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private var syncStatusCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            syncStatusHeader

            VStack(spacing: 14) {
                syncMetaRow(
                    title: L10n.text("cloud_sync.meta.last_sync", en: "Last sync", zh: "最近同步"),
                    value: lastSyncText
                )
                syncMetaRow(
                    title: L10n.text("cloud_sync.meta.pending_changes", en: "Local changes waiting", zh: "等待同步的本地变更"),
                    value: String(syncStatusStore.pendingChangeCount)
                )

                if syncStatusStore.pendingDeletionCount > 0 || syncStatusStore.phase == .syncing {
                    syncMetaRow(
                        title: L10n.text("cloud_sync.meta.pending_deletions", en: "Pending remote deletions", zh: "等待处理的远端删除"),
                        value: String(syncStatusStore.pendingDeletionCount)
                    )
                }
            }

            if case let .error(message) = syncStatusStore.phase {
                Text(message)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.highlight.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Button(action: triggerManualSync) {
                HStack(spacing: 10) {
                    if syncStatusStore.phase == .syncing {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(L10n.text("cloud_sync.sync_now", en: "Sync Now", zh: "立即同步"))
                        .font(AppTheme.Typography.primaryButton)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(syncStatusStore.phase == .syncing)
        }
        .cardStyle()
    }

    private var syncStatusHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("cloud_sync.status.title", en: "Backup status", zh: "备份状态"))
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text(statusLabel)
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer()

            if syncStatusStore.phase == .syncing {
                ProgressView()
                    .tint(AppTheme.Colors.accent)
            }
        }
    }

    private func syncMetaRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.meta)
                .foregroundStyle(AppTheme.Colors.tertiaryText)

            Spacer(minLength: 16)

            Text(value)
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func triggerManualSync() {
        Task {
            await syncStatusStore.syncIfEligible(authState: authManager.authState, reason: .manual)
        }
    }

    private var requiresAccount: Bool {
        switch authManager.authState {
        case .authenticated:
            false
        default:
            true
        }
    }

    private var summaryIconName: String {
        switch syncStatusStore.phase {
        case .idle:
            return "cloud"
        case .syncing:
            return "arrow.trianglehead.2.clockwise"
        case .error:
            return "icloud.slash"
        }
    }

    private var summaryTitle: String {
        switch authManager.authState {
        case .authenticated:
            switch syncStatusStore.phase {
            case .idle:
                return L10n.text("cloud_sync.summary.ready.title", en: "Ready to back up local changes", zh: "已准备好备份本地变更")
            case .syncing:
                return L10n.text("cloud_sync.summary.syncing.title", en: "Pushing local changes", zh: "正在推送本地变更")
            case .error:
                return L10n.text("cloud_sync.summary.error.title", en: "Backup needs another try", zh: "备份还需要再试一次")
            }
        default:
            return L10n.text("cloud_sync.summary.account.title", en: "A sign-in is still needed", zh: "还需要完成一次登录")
        }
    }

    private var summaryDetail: String {
        switch authManager.authState {
        case .authenticated:
            switch syncStatusStore.phase {
            case .idle:
                return L10n.text("cloud_sync.summary.ready.detail", en: "Any local changes waiting on this device can be pushed to the cloud whenever you choose.", zh: "这台设备上等待同步的本地变更，已经可以在你需要时推送到云端。")
            case .syncing:
                return L10n.text("cloud_sync.summary.syncing.detail", en: "A quiet pass is uploading pending changes and clearing any queued remote deletions.", zh: "系统正在安静地上传待同步变更，并处理排队中的远端删除。")
            case .error:
                return L10n.text("cloud_sync.summary.error.detail", en: "Nothing local was removed. You can try again after checking the account and network setup.", zh: "本地内容没有被移除。检查账号和网络后，可以再试一次。")
            }
        default:
            return L10n.text("cloud_sync.summary.account.detail", en: "Cloud backup only starts after this device is linked to your account once.", zh: "只有在这台设备完成一次账号绑定后，云端备份才会开始。")
        }
    }

    private var statusLabel: String {
        switch syncStatusStore.phase {
        case .idle:
            return L10n.text("cloud_sync.status.idle", en: "Ready", zh: "已就绪")
        case .syncing:
            return L10n.text("cloud_sync.status.syncing", en: "Syncing quietly", zh: "正在安静同步")
        case .error:
            return L10n.text("cloud_sync.status.error", en: "Needs attention", zh: "需要留意")
        }
    }

    private var lastSyncText: String {
        guard let lastSyncAt = syncStatusStore.lastSyncAt else {
            return L10n.text("cloud_sync.meta.last_sync.empty", en: "Not yet", zh: "尚未同步")
        }

        return lastSyncAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }
}
