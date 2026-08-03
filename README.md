# OpenLedger

本地优先的智能记账 App：一张支付截图，自动完成记账。

用户把微信、支付宝、云闪付、抖音等平台的支付成功截图交给 OpenLedger，App 在本机完成识别、解析、加密存储；数据默认不出设备，多端之间可通过隔空投送加密传输账本。

> 当前状态：规划完成（v0.5），准备进入 M0 概念验证。完整开发计划见 [智能记账App开发计划.md](智能记账App开发计划.md)。

## 功能

**MVP（第一版）**

- 一个主按钮导入支付截图（相册 / 拍照 / 系统分享）
- 本机 OCR + 平台模板解析（微信 / 支付宝 / 云闪付 / 抖音支付）
- 敏感字段加密存储（Keychain + CryptoKit）
- 账单浏览、去重、截图默认仅保留缩略图
- 加密导出 / 恢复（口令派生密钥）

**路线图**

- 平台账单对账、Face ID 应用锁、账单总结提醒（每日 / 每周 / 每月 / 每季度 / 每年）
- AirDrop 近距同步、隐私脱敏分享卡、桌面小组件
- iPad / macOS / Android（Android 在 iOS 上线后启动）

## 技术栈

| 项 | 选型 |
| --- | --- |
| 语言 / UI | Swift 6 / SwiftUI |
| 最低系统 | iOS 26.0 |
| 数据 | SwiftData + CryptoKit（敏感字段加密） |
| OCR | Vision `VNRecognizeTextRequest` |
| 密钥 | Keychain（仅本设备） |
| 设计 | Liquid Glass（iOS 26 设计语言） |

## 隐私与安全

- 默认纯本地：识别、解析、加密全部在本机完成，无网络请求、无遥测。
- 敏感字段（交易单号、订单描述、OCR 原文等）用 AES-256-GCM 加密，密钥存 Keychain。
- 加密导出 / 恢复：用户口令派生密钥，口令丢失则备份不可恢复。
- 多端同步仅支持 AirDrop 近距传输，远程网络同步暂不提供。
- 代码开源（MIT），加密方案可审计。

## 目录结构

```
OpenLedger/           # iOS App 源码（M1 阶段生成 Xcode 工程后填充）
OpenLedgerTests/      # 单元测试
OpenLedgerUITests/    # UI 测试
docs/                 # 设计文档
.github/workflows/    # CI
```

## 开发环境

- Xcode 26+
- iOS 26+（真机或模拟器）
- Git + GitHub（仓库公开后启用 CI）

## 开发计划

详见 [智能记账App开发计划.md](智能记账App开发计划.md)，当前里程碑：M0 概念验证（支付截图 OCR 与字段解析准确率验证）。

## 许可证

[MIT](LICENSE)
