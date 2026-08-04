import OpenLedgerCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

enum HomeReminderStore {
    private static let countKey = "home.missingCount"

    static var missingCount: Int {
        UserDefaults.standard.integer(forKey: countKey)
    }

    static func setMissingCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: countKey)
    }
}

enum ScreenshotPromptService {
    private enum Keys {
        static let lastScreenshot = "screenshot.lastDate"
        static let dismissedScreenshot = "screenshot.dismissedDate"
    }

    static func recordScreenshot() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastScreenshot)
    }

    static func shouldPrompt() -> Bool {
        let defaults = UserDefaults.standard
        guard let last = defaults.object(forKey: Keys.lastScreenshot) as? Date else {
            return false
        }
        let dismissed = defaults.object(forKey: Keys.dismissedScreenshot) as? Date ?? .distantPast
        guard last > dismissed else { return false }
        // 只在截图发生在 60 秒内时提示，避免陈旧时间戳打扰
        return Date().timeIntervalSince(last) < 60
    }

    static func dismiss() {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: Keys.lastScreenshot) as? Date {
            defaults.set(last, forKey: Keys.dismissedScreenshot)
        }
    }
}

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var records: [PaymentRecordModel]

    @State private var showSourceMenu = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showReview = false
    @State private var isProcessing = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var draft: PaymentDraft?
    @State private var errorMessage: String?
    @State private var errorTitle = "识别失败"
    @State private var lastImage: UIImage?
    @State private var showMissingBanner = true
    @State private var showReconciliation = false
    @State private var showScreenshotPrompt = false
    @State private var backgroundAnimate = false
    @State private var showManualEntry = false

    private let pipeline = RecognitionPipeline()
    private let crypto = CryptoService()
    var onSaved: ((Decimal, UUID) -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                GlassEffectContainer {
                    VStack(spacing: 24) {
                        Spacer()

                        MainCaptureButton {
                            showSourceMenu = true
                        }

                        Text("导入支付截图")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("从相册选择或拍摄微信、支付宝等支付截图，自动统计收支，数据全程留在本机")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        if showScreenshotPrompt {
                            ScreenshotPromptBanner(
                                onImport: {
                                    ScreenshotPromptService.dismiss()
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showScreenshotPrompt = false
                                    }
                                    showPhotoPicker = true
                                },
                                onDismiss: {
                                    ScreenshotPromptService.dismiss()
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showScreenshotPrompt = false
                                    }
                                }
                            )
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if showMissingBanner, HomeReminderStore.missingCount > 0 {
                            ReminderBanner(
                                count: HomeReminderStore.missingCount,
                                onAction: {
                                    showReconciliation = true
                                },
                                onDismiss: {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showMissingBanner = false
                                    }
                                }
                            )
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let errorMessage {
                            InlineErrorCard(
                                title: errorTitle,
                                message: errorMessage,
                                retryTitle: lastImage != nil ? "重试" : nil,
                                retry: lastImage != nil ? {
                                    if let image = lastImage {
                                        process(image)
                                    }
                                } : nil
                            )
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Button {
                            showManualEntry = true
                        } label: {
                            Label("识别不了？手动记账", systemImage: "square.and.pencil")
                                .font(.footnote)
                        }
                        .padding(.top, 4)

                        Spacer()
                    }
                }
            }
            .navigationTitle("记账")
            .confirmationDialog("选择截图来源", isPresented: $showSourceMenu, titleVisibility: .visible) {
                Button("从相册选择") { showPhotoPicker = true }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("拍照") { showCamera = true }
                }
                Button("取消", role: .cancel) {}
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    process(image)
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await loadPhoto(newItem)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.userDidTakeScreenshotNotification
                )
            ) { _ in
                ScreenshotPromptService.recordScreenshot()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, ScreenshotPromptService.shouldPrompt() {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showScreenshotPrompt = true
                    }
                }
            }
            .task {
                if ScreenshotPromptService.shouldPrompt() {
                    showScreenshotPrompt = true
                }
            }
            .onAppear {
                backgroundAnimate = !reduceMotion
            }
            .sheet(isPresented: $showReview) {
                if let draft {
                    RecognitionReviewView(draft: draft) { updated in
                        save(updated)
                    }
                }
            }
            .sheet(isPresented: $showReconciliation) {
                ReconciliationView()
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView { draft in
                    save(draft)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("识别中…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.25),
                    Color.purple.opacity(0.12),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.24))
                .blur(radius: 70)
                .frame(width: 320, height: 320)
                .offset(
                    x: backgroundAnimate ? 230 : -170,
                    y: backgroundAnimate ? -170 : -320
                )
                .scaleEffect(backgroundAnimate ? 1.2 : 0.85)
                .animation(
                    .easeInOut(duration: 6)
                        .repeatForever(autoreverses: true),
                    value: backgroundAnimate
                )

            Circle()
                .fill(Color.indigo.opacity(0.22))
                .blur(radius: 80)
                .frame(width: 340, height: 340)
                .offset(
                    x: backgroundAnimate ? -240 : 180,
                    y: backgroundAnimate ? 230 : 350
                )
                .scaleEffect(backgroundAnimate ? 0.85 : 1.2)
                .animation(
                    .easeInOut(duration: 7.5)
                        .repeatForever(autoreverses: true),
                    value: backgroundAnimate
                )

            Circle()
                .fill(Color.pink.opacity(0.16))
                .blur(radius: 90)
                .frame(width: 280, height: 280)
                .offset(
                    x: backgroundAnimate ? -220 : 240,
                    y: backgroundAnimate ? 60 : -40
                )
                .animation(
                    .easeInOut(duration: 8)
                        .repeatForever(autoreverses: true),
                    value: backgroundAnimate
                )
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "无法读取所选图片"
            return
        }
        process(image)
    }

    private func process(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "图片格式不受支持"
            return
        }
        lastImage = image
        errorMessage = nil
        errorTitle = "识别失败"
        isProcessing = true
        do {
            let result = try pipeline.recognize(cgImage: cgImage)
            draft = result
            showReview = true
        } catch {
            errorMessage = "识别失败：\(error.localizedDescription)"
        }
        isProcessing = false
    }

    private func save(_ updated: PaymentDraft) {
        do {
            if isDuplicate(updated) {
                errorTitle = "重复账单"
                errorMessage = "该笔交易已存在，已跳过重复保存"
                draft = nil
                selectedItem = nil
                showReview = false
                return
            }
            let model = try PaymentRecordModel.make(from: updated, crypto: crypto)
            modelContext.insert(model)
            try modelContext.save()
            let amount = model.amount
            let recordID = model.id
            draft = nil
            selectedItem = nil
            showReview = false
            onSaved?(amount, recordID)
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func isDuplicate(_ draft: PaymentDraft) -> Bool {
        let hash = draft.transactionId.map(PaymentRecordModel.transactionIdHash)
        let amount = draft.amount
        let merchant = draft.merchant
        let paidAt = draft.paidAt

        return records.contains { record in
            if let hash, record.transactionIdHash == hash {
                return true
            }
            guard let paidAt, let recordPaidAt = record.paidAt,
                  amount != nil, record.amount == amount,
                  merchant != nil, record.merchant == merchant else {
                return false
            }
            return abs(paidAt.timeIntervalSince(recordPaidAt)) < 300
        }
    }
}
