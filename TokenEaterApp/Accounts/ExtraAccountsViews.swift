import SwiftUI

// MARK: - Account scope

/// In Claude Work mode, hands every view below it the work account's
/// `UsageStore` in place of the main one. All the existing Claude cells,
/// the plan badge, pacing and the dashboard then show that account as-is.
struct ClaudeAccountScope<Content: View>: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var extraAccounts: ExtraAccountsStore
    @ViewBuilder let content: () -> Content

    var body: some View {
        if settingsStore.activeProviderMode == .claudeWork, let work = extraAccounts.workUsageStore {
            content().environmentObject(work)
        } else {
            content()
        }
    }
}

// MARK: - Settings

/// Settings > Providers card: lists the extra logins found in the Keychain,
/// with a label and an on/off switch for each.
struct ExtraAccountsSettingsCard: View {
    @EnvironmentObject private var extraAccounts: ExtraAccountsStore

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                cardLabel("Other Claude accounts")
                Spacer()
                Button(extraAccounts.isRefreshing ? "Refreshing…" : "Scan & refresh") {
                    extraAccounts.discover()
                    Task { await extraAccounts.refresh() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .disabled(extraAccounts.isRefreshing)
            }

            if extraAccounts.accounts.isEmpty {
                Text("No other logins found. Log in to another account with a separate config dir, e.g. CLAUDE_CONFIG_DIR=~/.claude-work claude, then press Scan.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(extraAccounts.accounts) { account in
                    ExtraAccountSettingsRow(account: account, usage: extraAccounts.usage[account.service])
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.04)))
    }
}

private struct ExtraAccountSettingsRow: View {
    let account: ExtraClaudeAccount
    let usage: ExtraAccountUsage?
    @EnvironmentObject private var extraAccounts: ExtraAccountsStore
    @State private var label = ""

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button {
                extraAccounts.setEnabled(!account.enabled, for: account.service)
            } label: {
                Image(systemName: account.enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(account.enabled ? .green : .white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help(account.enabled ? "Shown in the menu bar and popover" : "Hidden")

            TextField("Label", text: $label)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .onSubmit { extraAccounts.setLabel(label, for: account.service) }
                .onChange(of: label) { _, new in
                    if new.count > 6 { label = String(new.prefix(6)) }
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(usage?.email ?? "Not read yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
                if let error = usage?.error {
                    Text(error).font(.system(size: 10)).foregroundStyle(.orange.opacity(0.85))
                }
            }
            Spacer(minLength: 0)

            Button {
                extraAccounts.remove(account.service)
            } label: {
                Image(systemName: "xmark").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.4))
            .help("Forget this account (Scan finds it again)")
        }
        .onAppear { label = account.label }
        .onDisappear { extraAccounts.setLabel(label, for: account.service) }
    }
}
