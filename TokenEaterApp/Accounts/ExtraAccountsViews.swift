import SwiftUI

// MARK: - Settings

/// Settings > Providers: one `ProviderCard` per extra Claude login, in the
/// same card language as Claude and Codex above it.
struct ExtraAccountsSettingsCard: View {
    @EnvironmentObject private var extraAccounts: ExtraAccountsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                cardLabel(String(localized: "extraAccounts.title"))
                Spacer()
                Button(extraAccounts.isRefreshing ? String(localized: "extraAccounts.refreshing") : String(localized: "extraAccounts.scan")) {
                    extraAccounts.discover()
                    Task { await extraAccounts.refresh() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.Palette.textTertiary)
                .disabled(extraAccounts.isRefreshing)
            }
            .padding(.top, DS.Spacing.xs)

            if extraAccounts.accounts.isEmpty {
                Text("extraAccounts.empty")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.xs)
            } else {
                ForEach(extraAccounts.accounts) { account in
                    ExtraAccountProviderCard(account: account)
                }
            }
        }
    }
}

private struct ExtraAccountProviderCard: View {
    let account: ExtraClaudeAccount
    @EnvironmentObject private var extraAccounts: ExtraAccountsStore

    @State private var enabled = true
    @State private var label = ""
    @State private var isChecking = false

    private var usage: ExtraAccountUsage? { extraAccounts.usage[account.service] }

    /// The account's own store when it is the work account, which knows the
    /// plan and organization; nil for any further account.
    private var store: UsageStore? {
        extraAccounts.enabledAccounts.first?.service == account.service ? extraAccounts.workUsageStore : nil
    }

    private var isLive: Bool {
        guard account.enabled else { return false }
        if let store { return store.hasConfig && store.errorState == .none }
        return usage?.error == nil && usage?.fiveHour != nil
    }

    /// Same "lead · chip · chip" shape `ProviderCard` splits, as for Claude.
    private var status: String {
        if let error = usage?.error, store == nil { return error }
        if let store, !store.hasConfig {
            return String(localized: "settings.providers.claude.connecting")
        }
        var parts = [String(localized: "settings.providers.claude.connected")]
        if let store, store.planType != .unknown { parts.append(store.planType.displayLabel) }
        if let email = usage?.email { parts.append(email) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ProviderCard(
            provider: .claude,
            name: "Claude · \(account.label)",
            isEnabled: account.enabled,
            isLive: isLive,
            status: status,
            enabled: $enabled
        ) {
            HStack(spacing: 6) {
                TextField(String(localized: "extraAccounts.label"), text: $label)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .onSubmit { extraAccounts.setLabel(label, for: account.service) }
                    .onChange(of: label) { _, new in
                        if new.count > 6 { label = String(new.prefix(6)) }
                    }
                    .help(String(localized: "extraAccounts.label"))

                Button {
                    isChecking = true
                    Task {
                        if let store { await store.refresh(force: true) }
                        await extraAccounts.refresh()
                        isChecking = false
                    }
                } label: {
                    Text(isChecking ? String(localized: "extraAccounts.refreshing") : String(localized: "extraAccounts.check"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Palette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.white.opacity(0.06))
                                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isChecking)

                Button {
                    extraAccounts.remove(account.service)
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Palette.textTertiary)
                .help(String(localized: "extraAccounts.forget"))
            }
        }
        .onAppear {
            enabled = account.enabled
            label = account.label
        }
        .onChange(of: enabled) { _, new in
            if new != account.enabled { extraAccounts.setEnabled(new, for: account.service) }
        }
        .onDisappear { extraAccounts.setLabel(label, for: account.service) }
    }
}
