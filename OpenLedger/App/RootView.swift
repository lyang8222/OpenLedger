import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            CaptureView()
                .tabItem { Label("记账", systemImage: "plus.circle.fill") }

            LedgerView()
                .tabItem { Label("账单", systemImage: "list.bullet.rectangle") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        // TODO(M4): iOS 26 的 Liquid Glass 标签栏为系统默认效果，后续统一打磨
    }
}
