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

    var body: some View {
        NavigationStack {
            Form {
                Section("数据与隐私") {
                    Button("导出加密备份") {
                        pendingAction = .export
                        passphrase = ""
                    }
                    Button("恢复备份") {
                        pendingAction = .restore
                        passphrase = ""
                    }
                }

                Section("本地存储") {
                    LabeledContent("账单数量", value: "\(records.count)")
                    LabeledContent("多端同步", value: "仅隔空投送")
                    LabeledContent("网络", value: "无")
                }

                Section("账单提醒（V1.x）") {
                    Text("每日 / 每周 / 每月 / 每季度 / 每年账单总结将在后续版本提供")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
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
                    importedData = try? Data(contentsOf: url)
                    if importedData != nil {
                        pendingAction = .restore
                        passphrase = ""
                    } else {
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
        guard let data = importedData else { return }
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
