import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockService {
    private enum Keys {
        static let enabled = "appLock.enabled"
    }

    private(set) var isLocked = false

    var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.enabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.enabled)
            if !newValue {
                isLocked = false
            }
        }
    }

    var canUseBiometrics: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// 进入后台 / 锁屏时调用：启用状态下立即锁定。
    func lockIfEnabled() {
        guard isEnabled else { return }
        isLocked = true
    }

    /// 解锁：优先生物识别，失败可回退设备密码。
    func unlock() async -> Bool {
        guard isEnabled else {
            isLocked = false
            return true
        }

        let context = LAContext()
        context.localizedFallbackTitle = "使用设备密码"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解锁 OpenLedger 查看账单"
            )
            if success {
                isLocked = false
            }
            return success
        } catch {
            return false
        }
    }
}
