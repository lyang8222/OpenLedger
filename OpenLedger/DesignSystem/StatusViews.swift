import SwiftUI

/// 玻璃质感空状态（Liquid Glass）。
struct GlassEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular, in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }

                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.tint)
            }

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// 玻璃质感内联错误卡片，可带重试。
struct InlineErrorCard: View {
    let title: String
    let message: String
    var retryTitle: String?
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let retryTitle, let retry {
                    Button(retryTitle, action: retry)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 首页漏记提醒横幅。
struct ReminderBanner: View {
    let count: Int
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("平台账单中有 \(count) 笔未记账")
                    .font(.subheadline.weight(.semibold))
                Text("导入账单对账后，可一键补记")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("去处理", action: onAction)
                .buttonStyle(.bordered)
                .controlSize(.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 截图后回前台时的导入询问横幅。
struct ScreenshotPromptBanner: View {
    let onImport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("检测到你刚截了支付截图")
                    .font(.subheadline.weight(.semibold))
                Text("要导入记账吗？截图仅在本机识别")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("导入", action: onImport)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
