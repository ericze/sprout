import SwiftUI

struct AccountView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(CloudSyncStatusStore.self) private var syncStatusStore

    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showingSignOutConfirmation = false
    @State private var showingAccountSwitchConfirmation = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.cardGap) {
                heroCard

                if let message = currentErrorMessage {
                    statusMessageCard(message)
                }

                contentCard
            }
            .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
            .padding(.vertical, 24)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(L10n.text("account.title", en: "Account", zh: "账号"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            L10n.text("account.sign_out.confirmation.title", en: "Sign out from this device?", zh: "要在这台设备退出登录吗？"),
            isPresented: $showingSignOutConfirmation
        ) {
            Button(L10n.text("account.sign_out.confirmation.cancel", en: "Cancel", zh: "取消"), role: .cancel) {}
            Button(L10n.text("account.sign_out.confirmation.confirm", en: "Sign Out", zh: "退出登录"), role: .destructive) {
                performSignOut()
            }
        } message: {
            Text(L10n.text("account.sign_out.confirmation.message", en: "Local records stay on this device. Cloud backup will pause until you sign in again.", zh: "本地记录会继续保留在这台设备上，云端备份会暂停，直到你再次登录。"))
        }
        .alert(
            L10n.text("account.switch.confirmation.title", en: "Switch this device to the new account?", zh: "要把这台设备切换到新账号吗？"),
            isPresented: $showingAccountSwitchConfirmation
        ) {
            Button(L10n.text("account.switch.confirmation.cancel", en: "Cancel", zh: "取消"), role: .cancel) {}
            Button(L10n.text("account.switch.confirmation.confirm", en: "Switch Account", zh: "切换账号")) {
                performAccountSwitch()
            }
        } message: {
            Text(L10n.text("account.switch.confirmation.message", en: "Local records stay on this device. Future backup will use the account you just signed in with.", zh: "本地记录会继续保留在这台设备上。之后的云端备份会使用刚刚登录的新账号。"))
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: heroIconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .background(AppTheme.Colors.iconBackground)
                .clipShape(Circle())

            Text(heroTitle)
                .font(AppTheme.Typography.sheetTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(heroDetail)
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .shellCardStyle()
    }

    @ViewBuilder
    private var contentCard: some View {
        switch authManager.authState {
        case .authenticated:
            authenticatedCard
        case .blockedByAccountBinding:
            bindingConflictCard
        case .authenticating:
            loadingCard
        case .unauthenticated, .error:
            unauthenticatedCard
        }
    }

    private var unauthenticatedCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("account.form.title", en: "Sign in quietly when you need backup", zh: "需要备份时，再安静地登录"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            VStack(spacing: 14) {
                textField(
                    title: L10n.text("account.email", en: "Email", zh: "邮箱"),
                    text: $email,
                    autocapitalization: .never
                )

                secureField(
                    title: L10n.text("account.password", en: "Password", zh: "密码"),
                    text: $password
                )
            }

            Button(action: performSignIn) {
                actionLabel(
                    title: L10n.text("account.sign_in", en: "Sign In", zh: "登录")
                )
            }
            .buttonStyle(.plain)
            .disabled(isSubmitDisabled)

            Button(action: performSignUp) {
                Text(L10n.text("account.sign_up", en: "Sign Up", zh: "注册"))
                    .font(AppTheme.Typography.primaryButton)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitDisabled)

            Button(action: performPasswordReset) {
                Text(L10n.text("account.forgot_password", en: "Forgot Password?", zh: "忘记密码？"))
                    .font(AppTheme.Typography.meta)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .disabled(isPasswordResetDisabled)
        }
        .shellCardStyle()
    }

    private var authenticatedCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("account.current.title", en: "Signed in on this device", zh: "这台设备已登录"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            metaRow(
                title: L10n.text("account.email", en: "Email", zh: "邮箱"),
                value: authManager.currentUser?.email ?? L10n.text("account.email.empty", en: "Not available", zh: "暂无")
            )

            metaRow(
                title: L10n.text("account.sync_status", en: "Sync status", zh: "同步状态"),
                value: syncStatusLabel
            )

            metaRow(
                title: L10n.text("account.pending_changes", en: "Pending changes", zh: "待同步变更"),
                value: String(syncStatusStore.pendingChangeCount)
            )

            metaRow(
                title: L10n.text("account.last_sync", en: "Last sync", zh: "最近同步"),
                value: lastSyncText
            )

            Button(action: performManualSync) {
                actionLabel(
                    title: L10n.text("account.sync_now", en: "Sync Now", zh: "立即同步")
                )
            }
            .buttonStyle(.plain)
            .disabled(syncStatusStore.phase == .syncing)

            Button(action: { showingSignOutConfirmation = true }) {
                Text(L10n.text("account.sign_out", en: "Sign Out", zh: "退出登录"))
                    .font(AppTheme.Typography.primaryButton)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.highlight.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .shellCardStyle()
    }

    private var bindingConflictCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("account.conflict.title", en: "This device is already linked", zh: "这台设备已经绑定过账号"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("account.conflict.detail", en: "To protect existing records, this device can only continue with the account that was linked earlier. Use the original account, or sign out and review before trying again.", zh: "为了保护已有记录，这台设备只能继续使用之前绑定过的账号。请改用原账号登录，或先退出后再确认。"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            metaRow(
                title: L10n.text("account.conflict.current_email", en: "Incoming account", zh: "当前尝试账号"),
                value: authManager.currentUser?.email ?? L10n.text("account.email.empty", en: "Not available", zh: "暂无")
            )

            metaRow(
                title: L10n.text("account.conflict.linked_id", en: "Linked account ID", zh: "已绑定账号 ID"),
                value: authManager.linkedUserID?.uuidString ?? L10n.text("account.conflict.linked_id.empty", en: "Not recorded", zh: "暂无记录")
            )

            Button(action: { showingSignOutConfirmation = true }) {
                Text(L10n.text("account.conflict.use_original", en: "Use Original Account", zh: "改用原账号"))
                    .font(AppTheme.Typography.primaryButton)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: { showingAccountSwitchConfirmation = true }) {
                actionLabel(
                    title: L10n.text("account.conflict.switch", en: "Switch to This Account", zh: "切换到这个账号")
                )
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
        .shellCardStyle()
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView()
                .tint(AppTheme.Colors.accent)

            Text(L10n.text("account.loading.title", en: "Checking account state", zh: "正在检查账号状态"))
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(L10n.text("account.loading.detail", en: "This takes only a moment. Local records stay available while we restore the session.", zh: "这只需要片刻时间。在恢复会话时，本地记录仍然可用。"))
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .shellCardStyle()
    }

    private func metaRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
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

    private func textField(
        title: String,
        text: Binding<String>,
        autocapitalization: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Typography.meta)
                .foregroundStyle(AppTheme.Colors.tertiaryText)

            TextField("", text: text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func secureField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Typography.meta)
                .foregroundStyle(AppTheme.Colors.tertiaryText)

            SecureField("", text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(AppTheme.Typography.cardBody)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func statusMessageCard(_ message: String) -> some View {
        Text(message)
            .font(AppTheme.Typography.meta)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.highlight.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionLabel(title: String) -> some View {
        HStack(spacing: 10) {
            if isWorking || syncStatusStore.phase == .syncing {
                ProgressView()
                    .tint(.white)
            }

            Text(title)
                .font(AppTheme.Typography.primaryButton)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.accent)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous))
    }

    private func performSignIn() {
        runAuthAction {
            try await authManager.signIn(
                email: normalizedEmail,
                password: password
            )
        }
    }

    private func performSignUp() {
        runAuthAction {
            try await authManager.signUp(
                email: normalizedEmail,
                password: password
            )
        }
    }

    private func performSignOut() {
        Task {
            isWorking = true
            defer { isWorking = false }

            do {
                try await authManager.signOut()
                errorMessage = nil
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performPasswordReset() {
        Task {
            isWorking = true
            errorMessage = nil
            defer { isWorking = false }

            do {
                try await authManager.resetPassword(email: normalizedEmail)
                errorMessage = L10n.text(
                    "account.forgot_password.sent",
                    en: "If an account exists for this email, a password reset message has been sent.",
                    zh: "如果这个邮箱已注册，找回密码邮件已经发送。"
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performAccountSwitch() {
        Task {
            isWorking = true
            errorMessage = nil
            defer { isWorking = false }

            do {
                try await authManager.switchBindingToCurrentUser()
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performManualSync() {
        Task {
            await syncStatusStore.syncIfEligible(authState: authManager.authState, reason: .manual)
        }
    }

    private func runAuthAction(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            isWorking = true
            errorMessage = nil
            defer { isWorking = false }

            do {
                try await operation()
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var currentErrorMessage: String? {
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }

        if case let .error(message) = authManager.authState, !message.isEmpty {
            return message
        }

        return nil
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSubmitDisabled: Bool {
        isWorking || normalizedEmail.isEmpty || password.isEmpty
    }

    private var isPasswordResetDisabled: Bool {
        isWorking || normalizedEmail.isEmpty
    }

    private var syncStatusLabel: String {
        switch syncStatusStore.phase {
        case .idle:
            return L10n.text("account.sync_status.idle", en: "Ready", zh: "已就绪")
        case .syncing:
            return L10n.text("account.sync_status.syncing", en: "Syncing quietly", zh: "正在安静同步")
        case .error:
            return L10n.text("account.sync_status.error", en: "Needs attention", zh: "需要留意")
        }
    }

    private var lastSyncText: String {
        guard let lastSyncAt = syncStatusStore.lastSyncAt else {
            return L10n.text("account.last_sync.empty", en: "Not yet", zh: "尚未同步")
        }

        return lastSyncAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var heroIconName: String {
        switch authManager.authState {
        case .authenticated:
            return "person.crop.circle.badge.checkmark"
        case .blockedByAccountBinding:
            return "person.crop.circle.badge.exclamationmark"
        case .authenticating:
            return "person.crop.circle.badge.clock"
        case .unauthenticated, .error:
            return "person.crop.circle"
        }
    }

    private var heroTitle: String {
        switch authManager.authState {
        case .authenticated:
            return L10n.text("account.hero.signed_in.title", en: "Account is connected", zh: "账号已连接")
        case .blockedByAccountBinding:
            return L10n.text("account.hero.conflict.title", en: "Account needs confirmation", zh: "账号需要再次确认")
        case .authenticating:
            return L10n.text("account.hero.loading.title", en: "Restoring your session", zh: "正在恢复你的会话")
        case .unauthenticated, .error:
            return L10n.text("account.hero.signed_out.title", en: "Use backup only when it helps", zh: "只在需要时，再启用备份")
        }
    }

    private var heroDetail: String {
        switch authManager.authState {
        case .authenticated:
            return L10n.text("account.hero.signed_in.detail", en: "This device is already linked. You can keep backup manual for now, or let automatic sync catch up later.", zh: "这台设备已经完成绑定。现在可以先手动备份，之后再承接自动同步。")
        case .blockedByAccountBinding:
            return L10n.text("account.hero.conflict.detail", en: "A different account tried to sign in on a device that already has linked local records.", zh: "已有本地记录的设备上，刚刚尝试登录了另一个账号。")
        case .authenticating:
            return L10n.text("account.hero.loading.detail", en: "We are checking whether this device already has a saved session.", zh: "系统正在检查这台设备上是否已有保存过的会话。")
        case .unauthenticated, .error:
            return L10n.text("account.hero.signed_out.detail", en: "Logging in is optional. Keep daily recording local until backup becomes useful to you.", zh: "登录并不是必需步骤。你可以继续把日常记录留在本地，等真正需要备份时再连接账号。")
        }
    }
}

private extension View {
    func shellCardStyle() -> some View {
        padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .shadow(color: AppTheme.Shadow.color, radius: AppTheme.Shadow.radius, y: AppTheme.Shadow.y)
    }
}
