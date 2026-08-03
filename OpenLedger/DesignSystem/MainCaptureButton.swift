import SwiftUI

/// 首页主按钮：当前用材质圆钮占位。
/// TODO(M4)：替换为 iOS 26 Liquid Glass `.glassEffect()` + 动态光泽与按压反馈。
struct MainCaptureButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 180, height: 180)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("导入支付截图")
    }
}
