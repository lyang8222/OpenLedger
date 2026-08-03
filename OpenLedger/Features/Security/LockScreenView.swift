import LocalAuthentication
import SwiftUI

struct LockScreenView: View {
    let service: AppLockService

    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                Text("OpenLedger 已锁定")
                    .font(.title3.weight(.semibold))

                Text("账单数据已加密保存在本机")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if isAuthenticating {
                    ProgressView()
                        .padding(.top, 8)
                } else {
                    Button {
                        authenticate()
                    } label: {
                        Label("解锁", systemImage: biometricIcon)
                            .font(.headline)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(.tint, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }

    private var biometricIcon: String {
        switch service.biometricType {
        case .faceID:
            "faceid"
        case .touchID:
            "touchid"
        default:
            "lock.open"
        }
    }

    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil
        Task {
            let success = await service.unlock()
            isAuthenticating = false
            if !success {
                errorMessage = "验证失败，请重试"
            }
        }
    }
}
