# OpenLedger 真机验证与 TestFlight 操作手册

## 0. 前置条件

- [ ] Apple Developer Program 付费账号（个人或公司均可）
- [ ] 稳定版 Xcode 26（App Store 下载；当前机器上的 Xcode 27 beta 仅用于开发验证，建议正式归档用稳定版）
- [ ] iPhone（建议 iOS 26+），开启「设置 → 隐私与安全性 → 开发者模式」
- [ ] Apple ID 已在 Xcode 登录（Xcode → Settings → Accounts）
- [ ] App Store Connect 已创建 App 记录，Bundle ID：`com.openledger.app`

## 1. 签名与真机运行

1. 打开 `OpenLedger.xcodeproj`；
2. 选中 **OpenLedger** target → **Signing & Capabilities**：
   - Team 选择你的开发者团队；
   - 确认 App Groups（`group.com.openledger.app`）已勾选，Xcode 会自动生成 provisioning profile；
3. 选中 **OpenLedgerWidget** target，同样选择 Team 并确认 App Groups；
4. 用数据线连接 iPhone，在 Xcode 顶部选择你的 iPhone 作为运行目标；
5. 首次运行需在 iPhone 上「设置 → 通用 → VPN 与设备管理」信任开发者证书；
6. 点击 Run。

## 2. 真机测试清单（逐项勾选）

### 核心记账流程

- [ ] 首页主按钮 → 从相册选择 → 系统选图器出现（无权限弹窗）
- [ ] 微信支付截图识别：金额/商户/时间/状态/交易单号正确
- [ ] 支付宝截图识别正确
- [ ] 云闪付截图识别正确（参考号作为单号）
- [ ] 抖音截图识别正确
- [ ] 识别低置信度/缺字段时，确认页出现"待补充"提示且可手动编辑
- [ ] 保存后金额胶囊动画 → 自动切到账单页 → 新纪录高亮
- [ ] 同一张截图重复导入被去重拦截
- [ ] 拍照导入（真机相机）流程可用

### 对账

- [ ] 导入支付宝 CSV：笔数与文件声明一致（此前验证 535 笔）
- [ ] 导入微信 xlsx：笔数与文件声明一致（此前验证 171 笔）
- [ ] 导入加密 zip：输入正确密码可解压；错误密码提示明确
- [ ] 漏记清单正确显示；一键补记后漏记横幅消失
- [ ] 金额不一致、账单内重复分类正确

### 隐私与安全

- [ ] Face ID / 触控 ID 解锁开关生效
- [ ] 切后台再回来：App 立即锁定，切换器预览显示锁屏遮罩
- [ ] 密码错误时解锁失败提示
- [ ] 加密导出备份 → 删除 App → 重新安装 → 用口令恢复成功
- [ ] 错误口令恢复失败

### 提醒与小组件

- [ ] 设置 → 账单提醒：开启时弹出通知权限请求
- [ ] 每日/每周/每月/每季度/每年开关生效
- [ ] 到达设定时间收到"账单总结"通知
- [ ] 默认通知**不显示金额**；开启"通知显示金额"后显示
- [ ] 主屏幕添加 OpenLedger 小组件（小/中尺寸）
- [ ] 新增一笔账单后，小组件数据刷新

### 截图询问

- [ ] 在微信/支付宝截图后切回 OpenLedger，首页出现"检测到你刚截了支付截图"
- [ ] 点导入 → 选图器打开 → 走识别流程
- [ ] 忽略后本次不再打扰

### 常规

- [ ] 深色/浅色模式显示正常
- [ ] 动态字体（辅助功能 → 更大字体）不破版
- [ ] 横竖屏/后台恢复不崩溃

## 3. TestFlight 上传

1. Xcode 顶部 Destination 选 **Any iOS Device (arm64)**；
2. Product → **Archive**（归档，等待完成）；
3. Organizer → 选中最新归档 → **Distribute App**；
4. 选择 **App Store Connect** → **Upload** → 按提示选择团队；
5. 上传完成后，打开 [App Store Connect](https://appstoreconnect.apple.com)：
   - 进入 App → **TestFlight** 页；
   - 等待构建处理完成（几分钟到几十分钟）；
   - **添加内部测试员**（你的 Apple ID），发布构建；
6. iPhone 上安装 **TestFlight** App，登录后即可收到内测版本。

## 4. 常见问题

- **签名报错 "No profiles for ..."**：确认 Developer 后台已注册 App ID `com.openledger.app` 并启用 App Groups；在 Xcode 里让 Team 自动管理签名。
- **App Groups 在真机不生效**：App 与小组件都必须使用同一 `group.com.openledger.app`，且 provisioning profile 包含该能力；模拟器无法完全验证，以真机为准。
- **TestFlight 构建一直 "Processing"**：等 10–30 分钟，或检查归档是否包含小组件扩展（PlugIns/OpenLedgerWidget.appex）。
- **Xcode 27 beta 归档被拒/异常**：优先用稳定版 Xcode 26 归档。
- **开发者模式未开启**：iPhone 设置 → 隐私与安全性 → 开发者模式 → 开启后重启。

## 5. 测试记录

| 日期 | 设备 | iOS 版本 | 测试项 | 结果 | 备注 |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  | ✅ / ❌ |  |
