# OpenLedger（App 源码）

iOS App 源码目录。M1 阶段在此生成 Xcode 工程（SwiftUI + SwiftData + Vision）。

计划结构：

```
OpenLedger/
  App/          # App 入口与根视图
  Models/       # SwiftData 数据模型
  Features/
    Capture/    # 主按钮与截图导入
    Recognition/# OCR 与模板解析
    Ledger/     # 账单列表与详情
    Settings/   # 设置、提醒、导出/恢复
  Services/     # 加密、密钥管理、OCR 管线
  DesignSystem/ # Liquid Glass 组件
```
