# TestFlight 内测准备

本文档汇总 OpenLedger 上 TestFlight 前需要准备的事项与操作步骤。

## 已完成

- App 图标：1024×1024（Liquid Glass 玻璃质感：张开的手掌托住一枚透明玻璃硬币），生成脚本见 `Scripts/generate_app_icon.swift`；
- 导出合规声明：`ITSAppUsesNonExemptEncryption = NO`（加密均为系统 API，无需额外申报）；
- 版本号：`MARKETING_VERSION = 0.1.0`，`CURRENT_PROJECT_VERSION = 1`；
- Bundle ID：App `com.openledger.app`，小组件 `com.openledger.app.widget`；
- App Groups：`group.com.openledger.app`（App 与小组件共用，需签名生效）；
- 签名方式：`CODE_SIGN_STYLE = Automatic`（需在 Xcode 中选择你的开发团队）。

## 前置条件

1. 拥有 [Apple Developer Program](https://developer.apple.com/programs/) 付费账号；
2. 在 [App Store Connect](https://appstoreconnect.apple.com) 创建 App 记录（Bundle ID 填 `com.openledger.app`）；
3. 在 [Developer 后台](https://developer.apple.com/account) 注册 App ID 并开启 App Groups 能力；
4. Xcode 登录你的 Apple ID（Xcode → Settings → Accounts）。

## 操作步骤

### 方式一：Xcode 图形界面（推荐）

1. 打开 `OpenLedger.xcodeproj`；
2. 选中 OpenLedger target → Signing & Capabilities → 选择你的 Team；
3. 顶部菜单 Product → Destination 选 **Any iOS Device (arm64)**；
4. Product → Archive；
5. Organizer 窗口 → Distribute App → App Store Connect → Upload；
6. 上传完成后，到 App Store Connect 的 TestFlight 页面添加内部测试员并构建版本。

### 方式二：命令行归档

```bash
xcodebuild -project OpenLedger.xcodeproj -scheme OpenLedger \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/OpenLedger.xcarchive archive
```

归档后用 Xcode Organizer 或 `xcodebuild -exportArchive` 导出上传。

## 提交前检查清单

- [ ] App 图标已包含（Assets.xcassets/AppIcon.appiconset/AppIcon.png）；
- [ ] 真机验证：截图导入、识别、对账、Face ID、小组件、提醒通知；
- [ ] 隐私标签：App Store Connect 中如实声明"不收集数据"；
- [ ] 小组件 App Group 在真机签名后可用（模拟器上无法完全验证）；
- [ ] 内部测试员至少 1 人（可先只用自己）。

## 已知注意事项

- 小组件与 App Groups 依赖开发者证书与 provisioning profile，模拟器构建不验证该部分；
- 首次上传需要接受 Apple 的加密合规声明（已在 Info.plist 声明为 NO）；
- 若使用 Xcode 27 beta 构建，建议同时用稳定版 Xcode 26 复验一次归档，避免 beta 产物兼容问题。
