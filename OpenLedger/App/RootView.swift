import SwiftData
import SwiftUI

struct RootView: View {
    @State private var appLock = AppLockService()
    @Environment(\.scenePhase) private var scenePhase
    @Query private var records: [PaymentRecordModel]

    var body: some View {
        TabView {
            Tab("记账", systemImage: "plus.circle.fill") {
                CaptureView()
            }

            Tab("账单", systemImage: "list.bullet.rectangle") {
                LedgerView()
            }

            Tab("设置", systemImage: "gearshape.fill") {
                SettingsView(appLock: appLock)
            }
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
    }
}
