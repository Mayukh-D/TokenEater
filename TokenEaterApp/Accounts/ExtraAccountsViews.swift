import SwiftUI

// MARK: - Popover

/// One row per extra Claude account under the popover grid. Draws nothing
/// when no extra account is enabled, so single-account users see no change.
struct ExtraAccountsPopoverSection: View {
    @EnvironmentObject private var extraAccounts: ExtraAccountsStore
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        let rows = extraAccounts.enabledAccounts
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Other Claude accounts")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                ForEach(rows) { account in
                    ExtraAccountRow(account: account, usage: extraAccounts.usage[account.service], themeStore: themeStore)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

private struct ExtraAccountRow: View {
    let account: ExtraClaudeAccount
    let usage: ExtraAccountUsage?
    @ObservedObject var themeStore: ThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(account.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text(usage?.email ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            if let error = usage?.error {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange.opacity(0.85))
            } else if let usage {
                HStack(spacing: 10) {
                    meter("5h", usage.fiveHour, resets: usage.fiveHourResetsAt)
                    meter("7d", usage.sevenDay, resets: usage.sevenDayResetsAt)
                }
            } else {
                Text("Loading…")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func meter(_ title: String, _ pct: Double?, resets: Date?) -> some View {
        let value = pct ?? 0
        let color = Color(nsColor: themeStore.menuBarNSColor(for: Int(value.rounded())))
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(.white.opacity(0.5))
                Text(pct.map { "\(Int($0.rounded()))%" } ?? "–").foregroundStyle(.white)
                Spacer(minLength: 0)
                if let resets {
                    Text(resets, style: .relative).foregroundStyle(.white.opacity(0.35))
                }
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(color).frame(width: geo.size.width * min(max(value / 100, 0), 1))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
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
