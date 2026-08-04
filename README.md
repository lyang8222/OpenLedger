# OpenLedger

本地优先的智能收支统计 App：一张支付截图，自动完成记账，快速掌握收支。

[![CI](https://github.com/lyang8222/OpenLedger/actions/workflows/ci.yml/badge.svg)](https://github.com/lyang8222/OpenLedger/actions/workflows/ci.yml)

用户把微信、支付宝、云闪付、抖音等平台的支付成功截图交给 OpenLedger，App 在本机完成识别、解析、加密存储；数据默认不出设备，多端之间可通过隔空投送加密传输账本。

> 当前状态：M0 概念验证完成（57 张四平台真实截图，金额/商户/时间/状态提取率 100%、交易单号 98%）；M1 进行中——核心库（OCR 解析 / 加密 / 备份）已可独立测试，iOS App 源码已就绪，待 Xcode 26 环境构建。详见 [docs/m0-summary.md](docs/m0-summary.md) 与 [智能记账App开发计划.md](智能记账App开发计划.md)。

> 最新进展：核心库新增**账单对账**（支付宝 CSV / 微信 xlsx / 加密 zip 解析 + 匹配引擎），已用真实账单验证——支付宝 535 笔、微信 171 笔；App 已支持 **Face ID 应用锁**、**账单总结提醒**（每日/每周/每月/每季度/每年本地通知，默认隐藏金额）、**Liquid Glass 视觉打磨**、**首页漏记提醒**、**今日/本月支出小组件**、**截图后回前台导入询问** 与 **账单页收支图表**（条形/饼图/折线/曲线可切换）。

> TestFlight 内测准备：App 图标、版本号、签名与上传步骤见 [docs/testflight.md](docs/testflight.md)。

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
OpenLedgerCore/       # 核心库：识别、解析、加密、备份（SPM 包）
OpenLedgerTests/      # 单元测试
OpenLedgerUITests/    # UI 测试
Scripts/              # M0 验证脚本（平台分类 / OCR 转储 / 字段提取）
docs/                 # 设计文档
.github/workflows/    # CI
```

## 开发环境

- Xcode 26+（App 构建必需；当前机器仅命令行工具时，可先开发核心库）
- iOS 26+（真机或模拟器）
- Git + GitHub（仓库公开后启用 CI）

## 构建 App

1. 安装 Xcode（当前使用 Xcode 27 beta；正式版 Xcode 26 亦可）。
2. 打开 `OpenLedger.xcodeproj`，选择 `OpenLedger` scheme 运行到模拟器。
3. 首次运行需在 Xcode 的 Settings → Components 中下载 iOS Simulator 运行时。
4. 命令行构建：

```bash
xcodebuild -project OpenLedger.xcodeproj -scheme OpenLedger \
  -destination 'generic/platform=iOS Simulator' build
```

> `project.yml`（XcodeGen 配置）保留作为工程生成的备选方案；当前仓库直接维护 `OpenLedger.xcodeproj`。

## 核心库校验（无需 Xcode）

```bash
swift run --package-path OpenLedgerCore OpenLedgerCoreCheck
```

安装 Xcode 后也可运行 `swift test --package-path OpenLedgerCore` 执行 XCTest 测试套件。

## 开发计划

详见 [智能记账App开发计划.md](智能记账App开发计划.md)，当前里程碑：M0 概念验证（支付截图 OCR 与字段解析准确率验证）。

## 许可证

[MIT](LICENSE)
