import SwiftUI

/// 首页主按钮：iOS 26 Liquid Glass 圆形玻璃按钮，带旋转光泽与按压反馈。
struct MainCaptureButton: View {
    let action: () -> Void

    @State private var shineRotates = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.blue.opacity(0.16),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 130
                        )
                    )
                    .frame(width: 190, height: 190)
                    .glassEffect(.regular, in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                    }
                    .overlay {
                        Circle()
                            .trim(from: 0, to: 0.22)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.9), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(shineRotates ? 360 : 0))
                            .animation(
                                .linear(duration: 5)
                                    .repeatForever(autoreverses: false),
                                value: shineRotates
                            )
                    }

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 68, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
        }
        .buttonStyle(GlassButtonStyle())
        .onAppear {
            shineRotates = true
        }
        .accessibilityLabel("导入支付截图")
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}
