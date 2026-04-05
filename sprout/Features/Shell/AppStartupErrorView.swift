//
//  AppStartupErrorView.swift
//  sprout
//

import SwiftUI

struct AppStartupErrorView: View {
    let errorMessage: String

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.section) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                VStack(spacing: 8) {
                    Text(L10n.text("startup_error.title", en: "Unable to Start", zh: "无法启动"))
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)

                    Text(L10n.text("startup_error.message", en: "The app encountered a problem and cannot start. Please restart the app or reinstall if the issue persists.", zh: "应用遇到了问题，无法正常启动。请尝试重启应用，若问题持续，可能需要重新安装。"))
                        .font(AppTheme.Typography.cardBody)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
            }
            .padding(AppTheme.Spacing.section)
        }
    }
}

// MARK: - Preview

#Preview {
    AppStartupErrorView(errorMessage: "Test error")
}
