import SwiftData
import SwiftUI
import UserNotifications

@main
struct OpenLedgerApp: App {
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: PaymentRecordModel.self)
        } catch {
            fatalError("无法创建本地数据库：\(error)")
        }
    }()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
