import CryptoKit
import OpenLedgerCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PaymentRecordModel.createdAt, order: .reverse)
    private var records: [PaymentRecordModel]

    private let crypto = CryptoService()
    private let archive = EncryptedArchive()

    enum PendingAction {
        case export
        case restore
    }

    @State private var pendingAction: PendingAction?
    @State private var passphrase = ""
    @State private var exportData: Data?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importedData: Data?
    @State private var message: String?
    @State private var showReconciliation = false

    let appLock: AppLockService

    @AppStorage(ReminderKeys.enabled) private var remindersEnabled = false
    @AppStorage(ReminderKeys.daily) private var dailyReminderEnabled = true
    @AppStorage(ReminderKeys.weekly) private var weeklyReminderEnabled = true
    @AppStorage(ReminderKeys.monthly) private var monthlyReminderEnabled = true
    @AppStorage(ReminderKeys.quarterly) private var quarterlyReminderEnabled = true
    @AppStorage(ReminderKeys.yearly) private var yearlyReminderEnabled = true
    @AppStorage(ReminderKeys.dailyTime) private var dailyTimeMinutes = 21 * 60
    @AppStorage(ReminderKeys.weeklyWeekday) private var weeklyWeekday = 2
    @AppStorage(ReminderKeys.showAmounts) private var showAmountsInNotifications = false
    @AppStorage("chart.type") private var chartTypeRaw = LedgerChartType.bar.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                Form {
                    Section("隐私保护") {
                    Toggle(
                        "面容 / 触控 ID 解锁",
                        isOn: Binding(
                            get: { appLock.isEnabled },
                            set: { appLock.isEnabled = $0 }
                        )
                    )

                    if appLock.canUseBiometrics {
                        LabeledContent("生物识别", value: biometricName)
                    } else {
                        Text("当前设备未设置面容/触控 ID，请先在系统设置中开启。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("开启后，App 进入后台会立即锁定；切换器预览将显示锁定遮罩。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                    Section("对账") {
                    Button {
                        showReconciliation = true
                    } label: {
                        Label("导入平台账单对账", systemImage: "checkmark.seal")
                    }
                }

                    Section("数据与隐私") {
                    Button("导出加密备份") {
                        pendingAction = .export
                        passphrase = ""
                    }
                    Button("恢复备份") {
                        showImporter = true
                    }
                }

                Section {
                    Picker("图表类型", selection: $chartTypeRaw) {
                        ForEach(LedgerChartType.allCases) { type in
                            Text(type.label).tag(type.rawValue)
                        }
                    }
                } header: {
                    Text("账单图表")
                } footer: {
                    Text("账单页顶部收支图表的显示样式")
                }

                    Section("本地存储") {
                    LabeledContent("账单数量", value: "\(records.count)")
                    LabeledContent("多端同步", value: "仅隔空投送")
                    LabeledContent("网络", value: "无")
                }

                Section("账单提醒") {
                    Toggle("账单总结提醒", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await ReminderService.requestAuthorization()
                                    if granted {
                                        await ReminderService.refreshSummaries(records: records)
                                    } else {
                                        remindersEnabled = false
                                        message = "通知权限被拒绝，请在系统设置中允许 OpenLedger 通知。"
                                    }
                                }
                            } else {
                                ReminderService.cancelAll()
                            }
                        }

                    if remindersEnabled {
                        Toggle("每日", isOn: $dailyReminderEnabled)
                        Toggle("每周", isOn: $weeklyReminderEnabled)
                        Toggle("每月", isOn: $monthlyReminderEnabled)
                        Toggle("每季度", isOn: $quarterlyReminderEnabled)
                        Toggle("每年", isOn: $yearlyReminderEnabled)

                        DatePicker(
                            "每日提醒时间",
                            selection: dailyTimeBinding,
                            displayedComponents: .hourAndMinute
                        )

                        Picker("每周提醒日", selection: $weeklyWeekday) {
                            ForEach(weekdayOptions, id: \.value) { option in
                                Text(option.name).tag(option.value)
                            }
                        }

                        Toggle("通知显示金额", isOn: $showAmountsInNotifications)

                        Text("汇总在打开 App 或新增账单时刷新；长时间未打开可能显示最近一次的数据。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    }
                    .onChange(of: dailyReminderEnabled) { _, _ in refreshReminders() }
                .onChange(of: weeklyReminderEnabled) { _, _ in refreshReminders() }
                .onChange(of: monthlyReminderEnabled) { _, _ in refreshReminders() }
                .onChange(of: quarterlyReminderEnabled) { _, _ in refreshReminders() }
                .onChange(of: yearlyReminderEnabled) { _, _ in refreshReminders() }
                .onChange(of: dailyTimeMinutes) { _, _ in refreshReminders() }
                .onChange(of: weeklyWeekday) { _, _ in refreshReminders() }
                    .onChange(of: showAmountsInNotifications) { _, _ in refreshReminders() }
                }

            }
            .scrollContentBackground(.hidden)
            .navigationTitle("设置")
            .sheet(isPresented: $showReconciliation) {
                ReconciliationView()
            }
            .alert(
                "输入备份口令",
                isPresented: Binding(
                    get: { pendingAction != nil },
                    set: { if !$0 { pendingAction = nil } }
                )
            ) {
                SecureField("口令", text: $passphrase)
                Button("确定") { performPendingAction() }
                Button("取消", role: .cancel) { pendingAction = nil }
            } message: {
                Text(pendingAction == .export
                    ? "用于加密备份文件，请牢记；口令丢失后备份无法恢复。"
                    : "输入导出备份时设置的口令。")
            }
            .fileExporter(
                isPresented: $showExporter,
                document: ExportDocument(data: exportData),
                contentType: .data,
                defaultFilename: "OpenLedgerBackup.olbk"
            ) { result in
                switch result {
                case .success:
                    message = "备份已导出"
                case .failure(let error):
                    message = "导出失败：\(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data]) { result in
                switch result {
                case .success(let url):
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    do {
                        importedData = try Data(contentsOf: url)
                        if importedData != nil {
                            pendingAction = .restore
                            passphrase = ""
                        } else {
                            message = "无法读取备份文件"
                        }
                    } catch {
                        message = "无法读取备份文件"
                    }
                case .failure(let error):
                    message = "导入失败：\(error.localizedDescription)"
                }
            }
            .alert(
                "提示",
                isPresented: Binding(
                    get: { message != nil },
                    set: { if !$0 { message = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func performPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .export:
            exportBackup()
        case .restore:
            restoreBackup()
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    Color.purple.opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.indigo.opacity(0.12))
                .blur(radius: 80)
                .frame(width: 360, height: 360)
                .offset(x: -170, y: 320)
        }
    }

    private var biometricName: String {
        switch appLock.biometricType {
        case .faceID:
            "面容 ID"
        case .touchID:
            "触控 ID"
        default:
            "不可用"
        }
    }

    private func refreshReminders() {
        Task {
            await ReminderService.refreshSummaries(records: records)
        }
    }

    private var dailyTimeBinding: Binding<Date> {
        Binding(
            get: {
                let minutes = dailyTimeMinutes
                return Calendar.current.date(
                    bySettingHour: minutes / 60,
                    minute: minutes % 60,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                dailyTimeMinutes = (components.hour ?? 21) * 60 + (components.minute ?? 0)
            }
        )
    }

    private var weekdayOptions: [(value: Int, name: String)] {
        [
            (2, "周一"),
            (3, "周二"),
            (4, "周三"),
            (5, "周四"),
            (6, "周五"),
            (7, "周六"),
            (1, "周日")
        ]
    }

    private func exportBackup() {
        do {
            let key = try crypto.masterKey()
            let coreRecords = try records.map { try toCoreRecord($0, key: key) }
            exportData = try archive.export(records: coreRecords, passphrase: passphrase)
            showExporter = true
        } catch {
            message = "导出失败：\(error.localizedDescription)"
        }
    }

    private func restoreBackup() {
        guard let data = importedData else {
            message = "请先选择备份文件"
            return
        }
        do {
            let restored = try archive.importArchive(data: data, passphrase: passphrase)
            let key = try crypto.masterKey()
            var inserted = 0
            for record in restored {
                if let hash = record.transactionIdHash,
                   records.contains(where: { $0.transactionIdHash == hash }) {
                    continue
                }
                let model = try coreToModel(record, key: key)
                modelContext.insert(model)
                inserted += 1
            }
            try modelContext.save()
            message = inserted > 0 ? "已恢复 \(inserted) 条记录" : "没有需要恢复的新记录"
        } catch ArchiveError.invalidFormat {
            message = "不是有效的 OpenLedger 备份文件。"
        } catch ArchiveError.unsupportedVersion {
            message = "备份版本不兼容，请更新 App 后重试。"
        } catch ArchiveError.wrongPassphrase {
            message = "口令错误或备份文件已损坏，无法解密。"
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
    }

    private func toCoreRecord(_ model: PaymentRecordModel, key: SymmetricKey) throws -> PaymentRecord {
        let transactionId = try model.transactionIdEncrypted.flatMap {
            try crypto.decrypt(String.self, from: $0, using: key)
        }
        let rawOcrText = try model.rawOcrTextEncrypted.flatMap {
            try crypto.decrypt(String.self, from: $0, using: key)
        }
        return PaymentRecord(
            id: model.id,
            amount: model.amount,
            currency: model.currency,
            merchant: model.merchant,
            category: model.category,
            paidAt: model.paidAt,
            platform: model.platform,
            transactionId: transactionId,
            transactionIdHash: model.transactionIdHash,
            rawOcrText: rawOcrText,
            status: model.status,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    private func coreToModel(_ record: PaymentRecord, key: SymmetricKey) throws -> PaymentRecordModel {
        PaymentRecordModel(
            id: record.id,
            amount: record.amount,
            currency: record.currency,
            merchant: record.merchant,
            category: record.category,
            paidAt: record.paidAt,
            platform: record.platform,
            transactionIdEncrypted: try record.transactionId.map {
                try crypto.encrypt($0, using: key)
            },
            transactionIdHash: record.transactionIdHash,
            rawOcrTextEncrypted: try record.rawOcrText.map {
                try crypto.encrypt($0, using: key)
            },
            status: record.status,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    var data: Data

    init(data: Data?) {
        self.data = data ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
