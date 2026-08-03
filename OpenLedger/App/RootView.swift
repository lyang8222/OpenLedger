import SwiftData
import SwiftUI

struct RootView: View {
    private enum AppTab: String, Hashable {
        case capture
        case ledger
        case settings
    }

    @State private var appLock = AppLockService()
    @State private var selectedTab: AppTab = .capture
    @State private var floatingAmount: Decimal?
    @State private var floatingVisible = false
    @State private var floatingDrop = false
    @State private var highlightRecordID: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @Query private var records: [PaymentRecordModel]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("记账", systemImage: "plus.circle.fill", value: AppTab.capture) {
                CaptureView(onSaved: handleSaved)
            }

            Tab("账单", systemImage: "list.bullet.rectangle", value: AppTab.ledger) {
                LedgerView(highlightRecordID: highlightRecordID)
            }

            Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(appLock: appLock)
            }
        }
        .overlay {
            if appLock.isLocked {
                LockScreenView(service: appLock)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .center) {
            if let floatingAmount, floatingVisible {
                FloatingAmountBadge(amount: floatingAmount)
                    .allowsHitTesting(false)
                    .offset(y: floatingDrop ? 300 : 0)
                    .scaleEffect(floatingDrop ? 0.45 : 1)
                    .opacity(floatingDrop ? 0.25 : 1)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                appLock.lockIfEnabled()
            }
        }
        .task {
            if appLock.isEnabled {
                appLock.lockIfEnabled()
            }
            await ReminderService.refreshSummaries(records: records)
        }
        .onChange(of: records.count) { _, _ in
            Task {
                await ReminderService.refreshSummaries(records: records)
            }
        }
    }

    private func handleSaved(amount: Decimal, recordID: UUID) {
        floatingAmount = amount
        Task {
            // 等确认页 sheet 完全收起后再开始动画
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                floatingVisible = true
            }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeInOut(duration: 0.55)) {
                floatingDrop = true
            }
            try? await Task.sleep(for: .milliseconds(480))
            withAnimation(.easeOut(duration: 0.25)) {
                floatingVisible = false
            }
            selectedTab = .ledger
            highlightRecordID = recordID
            floatingAmount = nil
            floatingDrop = false

            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) {
                highlightRecordID = nil
            }
        }
    }
}

private struct FloatingAmountBadge: View {
    let amount: Decimal

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
            Text(LedgerFormatters.string(from: amount))
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.4), lineWidth: 1)
        }
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }
}
