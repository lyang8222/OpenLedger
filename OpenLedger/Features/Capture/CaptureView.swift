import OpenLedgerCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showSourceMenu = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showReview = false
    @State private var isProcessing = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var draft: PaymentDraft?
    @State private var errorMessage: String?

    private let pipeline = RecognitionPipeline()
    private let crypto = CryptoService()

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

                        Text("从相册选择或拍摄微信、支付宝等支付截图，识别与存储全程在本机完成")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

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
            .sheet(isPresented: $showReview) {
                if let draft {
                    RecognitionReviewView(draft: draft) { updated in
                        save(updated)
                    }
                }
            }
            .alert(
                "提示",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
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
                .fill(Color.cyan.opacity(0.16))
                .blur(radius: 70)
                .frame(width: 320, height: 320)
                .offset(x: -150, y: -280)

            Circle()
                .fill(Color.indigo.opacity(0.14))
                .blur(radius: 80)
                .frame(width: 340, height: 340)
                .offset(x: 160, y: 300)
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
            let model = try PaymentRecordModel.make(from: updated, crypto: crypto)
            modelContext.insert(model)
            try modelContext.save()
            draft = nil
            selectedItem = nil
            showReview = false
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
