import SwiftData
import SwiftUI

struct RootView: View {
    @State private var appLock = AppLockService()
    @Environment(\.scenePhase) private var scenePhase
    @Query private var records: [PaymentRecordModel]

    var body: some View {
        TabView {
            CaptureView()
                .tabItem { Label("记账", systemImage: "plus.circle.fill") }

            LedgerView()
                .tabItem { Label("账单", systemImage: "list.bullet.rectangle") }

            SettingsView(appLock: appLock)
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .overlay {
            if appLock.isLocked {
                LockScreenView(service: appLock)
                    .transition(.opacity)
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
        // TODO(M4): iOS 26 的 Liquid Glass 标签栏为系统默认效果，后续统一打磨
    }
}
