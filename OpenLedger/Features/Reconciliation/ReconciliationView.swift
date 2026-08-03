import CryptoKit
import OpenLedgerCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ReconciliationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [PaymentRecordModel]

    private let crypto = CryptoService()

    @State private var showImporter = false
    @State private var isParsing = false
    @State private var report: ReconciliationReport?
    @State private var parsedCount = 0
    @State private var message: String?
    @State private var pendingZipData: Data?
    @State private var zipPassword = ""
    @State private var showZipPassword = false

    private var importTypes: [UTType] {
        [.commaSeparatedText, UTType(filenameExtension: "xlsx") ?? .data, .data]
    }

    var body: some View {
        NavigationStack {
            Group {
                if isParsing {
                    ProgressView("正在解析账单…")
                } else if let report {
                    reportList(report)
                } else {
                    GlassEmptyState(
                        title: "导入平台账单",
                        message: "支持支付宝 CSV、微信 xlsx，以及两者官方导出的加密 zip",
                        systemImage: "doc.badge.arrow.up",
                        actionTitle: "选择账单文件",
                        action: {
                            showImporter = true
                        }
                    )
                }
            }
            .navigationTitle("账单对账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("导入账单", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: importTypes) { result in
                switch result {
                case .success(let url):
                    importBill(at: url)
                case .failure(let error):
                    message = "无法读取文件：\(error.localizedDescription)"
                }
            }
            .alert(
                "输入解压密码",
                isPresented: $showZipPassword
            ) {
                SecureField("解压密码", text: $zipPassword)
                Button("解压导入") {
                    if let data = pendingZipData {
                        importZip(data: data, password: zipPassword)
                    }
                }
                Button("取消", role: .cancel) {
                    pendingZipData = nil
                    zipPassword = ""
                }
            } message: {
                Text("微信/支付宝会在公众号或站内信中下发解压密码。")
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

    // MARK: - 导入与解析

    private func importBill(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        isParsing = true
        do {
            let data = try Data(contentsOf: url)
            let isZip = url.pathExtension.lowercased() == "zip"
                || data.starts(with: Data([0x50, 0x4B, 0x03, 0x04]))
            if isZip {
                pendingZipData = data
                zipPassword = ""
                showZipPassword = true
                isParsing = false
                return
            }
            let billEntries: [BillEntry]
            switch url.pathExtension.lowercased() {
            case "csv":
                billEntries = try AlipayBillParser().parse(data: data)
            case "xlsx":
                billEntries = try WeChatBillParser().parse(data: data)
            default:
                if let alipay = try? AlipayBillParser().parse(data: data) {
                    billEntries = alipay
                } else {
                    billEntries = try WeChatBillParser().parse(data: data)
                }
            }
            parsedCount = billEntries.count
            report = recomputeReport(billEntries: billEntries)
        } catch {
            message = "账单解析失败：\(error.localizedDescription)"
        }
        isParsing = false
    }

    private func importZip(data: Data, password: String) {
        isParsing = true
        showZipPassword = false
        pendingZipData = nil
        zipPassword = ""
        do {
            let result = try BillZipImporter().importBill(data: data, password: password)
            parsedCount = result.entries.count
            report = recomputeReport(billEntries: result.entries)
        } catch BillZipError.wrongPassword {
            message = "解压密码错误，请核对微信/支付宝公众号下发的密码。"
        } catch BillZipError.unsupportedEncryption {
            message = "该压缩包使用 AES 加密，当前版本暂不支持。"
        } catch BillZipError.noBillEntryFound {
            message = "压缩包内没有找到 CSV/xlsx 账单文件。"
        } catch {
            message = "账单解析失败：\(error.localizedDescription)"
        }
        isParsing = false
    }

    private func recomputeReport(
        billEntries: [BillEntry],
        models: [PaymentRecordModel]? = nil
    ) -> ReconciliationReport {
        let localRecords = (models ?? records).map(Self.coreRecord(from:))
        return ReconciliationEngine(includeNeutral: false)
            .reconcile(billEntries: billEntries, records: localRecords)
    }

    // MARK: - 报告展示

    @ViewBuilder
    private func reportList(_ report: ReconciliationReport) -> some View {
        List {
            Section {
                LabeledContent("账单笔数", value: "\(parsedCount)")
                LabeledContent("已匹配", value: "\(report.matched.count)")
                LabeledContent("漏记", value: "\(report.missingInApp.count)")
                LabeledContent("金额不一致", value: "\(report.amountMismatched.count)")
                LabeledContent("账单内重复", value: "\(report.duplicatesInBill.count)")
                LabeledContent("App 有而账单无", value: "\(report.missingInBill.count)")
            } header: {
                Text("对账结果")
            }

            if !report.missingInApp.isEmpty {
                Section {
                    ForEach(report.missingInApp.sorted { $0.paidAt > $1.paidAt }, id: \.self) { entry in
                        missingRow(entry)
                    }
                } header: {
                    Text("漏记（可补记）")
                } footer: {
                    Text("这些交易存在于平台账单中，但 App 里没有对应记录。")
                }
            }

            if !report.amountMismatched.isEmpty {
                Section {
                    ForEach(report.amountMismatched, id: \.bill.transactionId) { item in
                        mismatchRow(item)
                    }
                } header: {
                    Text("金额不一致")
                }
            }

            if !report.duplicatesInBill.isEmpty {
                Section {
                    ForEach(report.duplicatesInBill, id: \.self) { entry in
                        Text("\(entry.counterparty ?? "未知商户") · \(Self.amountText(entry.amount))")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("账单内重复")
                }
            }

            if !report.missingInBill.isEmpty {
                Section {
                    ForEach(report.missingInBill, id: \.id) { record in
                        Text("\(record.merchant ?? "未知商户") · \(Self.amountText(record.amount))")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("App 有而账单无")
                }
            }
        }
        .toolbar {
            if !report.missingInApp.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        addMissing(report.missingInApp)
                    } label: {
                        Label("补记漏记（\(report.missingInApp.count)）", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
    }

    private func missingRow(_ entry: BillEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.counterparty ?? "未知商户")
                    .font(.body.weight(.medium))
                Text(entry.paidAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Self.amountText(entry.amount))
                .font(.body.weight(.semibold))
                .foregroundStyle(entry.amount < 0 ? .primary : Color.green)
            Button("补记") {
                addMissing([entry])
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func mismatchRow(_ item: (bill: BillEntry, record: PaymentRecord)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.bill.counterparty ?? "未知商户")
                .font(.body.weight(.medium))
            Text("账单：\(Self.amountText(item.bill.amount)) · App：\(Self.amountText(item.record.amount))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 补记

    private func addMissing(_ entries: [BillEntry]) {
        do {
            let key = try crypto.masterKey()
            let existingHashes = Set(records.compactMap(\.transactionIdHash))
            var inserted = 0
            var skipped = 0
            var newModels: [PaymentRecordModel] = []

            for entry in entries {
                if let id = entry.transactionId, existingHashes.contains(Self.hash(id)) {
                    skipped += 1
                    continue
                }
                let model = try Self.model(from: entry, key: key, crypto: crypto)
                modelContext.insert(model)
                newModels.append(model)
                inserted += 1
            }
            try modelContext.save()

            if let report {
                self.report = recomputeReport(
                    billEntries: billEntries(from: report),
                    models: records + newModels
                )
            }
            message = inserted > 0
                ? "已补记 \(inserted) 笔" + (skipped > 0 ? "，跳过重复 \(skipped) 笔" : "")
                : "没有需要补记的新记录"
        } catch {
            message = "补记失败：\(error.localizedDescription)"
        }
    }

    private func billEntries(from report: ReconciliationReport) -> [BillEntry] {
        report.matched + report.missingInApp
            + report.amountMismatched.map(\.bill)
            + report.duplicatesInBill
    }

    // MARK: - 转换

    private static func coreRecord(from model: PaymentRecordModel) -> PaymentRecord {
        PaymentRecord(
            id: model.id,
            amount: model.amount,
            currency: model.currency,
            merchant: model.merchant,
            category: model.category,
            paidAt: model.paidAt,
            platform: model.platform,
            transactionIdHash: model.transactionIdHash,
            status: model.status,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    private static func model(
        from entry: BillEntry,
        key: SymmetricKey,
        crypto: CryptoService
    ) throws -> PaymentRecordModel {
        let platform: PaymentRecord.Platform
        switch entry.platform {
        case .wechat: platform = .wechat
        case .alipay: platform = .alipay
        case .unionpay: platform = .unionpay
        case .douyin: platform = .douyin
        }

        let transactionIdEncrypted = try entry.transactionId.map {
            try crypto.encrypt($0, using: key)
        }
        let itemDescriptionEncrypted = try entry.itemDescription.map {
            try crypto.encrypt($0, using: key)
        }
        let notesEncrypted = try entry.note.map {
            try crypto.encrypt($0, using: key)
        }

        return PaymentRecordModel(
            amount: entry.amount,
            merchant: entry.counterparty,
            category: entry.category,
            paidAt: entry.paidAt,
            platform: platform,
            transactionIdEncrypted: transactionIdEncrypted,
            transactionIdHash: entry.transactionId.map(Self.hash),
            itemDescriptionEncrypted: itemDescriptionEncrypted,
            notesEncrypted: notesEncrypted,
            status: entry.status
        )
    }

    private static func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func amountText(_ amount: Decimal) -> String {
        LedgerFormatters.string(from: amount)
    }
}
