import OpenLedgerCore
import SwiftUI

/// 脱敏分享卡：交易单号打码，只保留展示所需信息。
struct RedactedShareCardView: View {
    let record: PaymentRecordModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "creditcard")
                    .foregroundStyle(.tint)
                Text("OpenLedger 收支记录")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(record.platform.displayName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Text(LedgerFormatters.string(from: record.amount))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(record.amount < 0 ? .primary : Color.green)

            Text(record.merchant ?? "未知商户")
                .font(.title3.weight(.semibold))

            Text(record.paidAt?.formatted(date: .long, time: .shortened) ?? "时间未知")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            Text("交易单号：••••••••")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        }
    }
}

struct RedactedShareSheet: View {
    let record: PaymentRecordModel

    @State private var renderedImage: Image?

    var body: some View {
        VStack(spacing: 24) {
            Text("脱敏分享卡（交易单号已隐藏）")
                .font(.headline)

            RedactedShareCardView(record: record)
                .padding(.horizontal, 20)

            ShareLink(
                item: renderedImage ?? Image(systemName: "photo"),
                preview: SharePreview(
                    "OpenLedger 收支记录",
                    image: renderedImage ?? Image(systemName: "photo")
                )
            ) {
                Label("分享卡片", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(.tint, in: Capsule())
                    .foregroundStyle(.white)
            }
            .disabled(renderedImage == nil)
        }
        .padding(.vertical, 28)
        .task {
            renderedImage = renderCard()
        }
    }

    private func renderCard() -> Image? {
        let card = RedactedShareCardView(record: record)
            .frame(width: 640)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
