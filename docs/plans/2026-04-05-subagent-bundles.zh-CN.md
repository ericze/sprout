# 初长 V1 第一批子代理执行包

**用途：** 这份文档用于直接启动子代理执行第一批任务，并统一记录进度。

**当前批次目标：** 先解决公开上线前的 P0 阻塞项，优先处理数据安全、配置清理、假入口移除、全局状态同步，以及双语切换基础设施。

**已锁定前提：**

- 公开 V1：`local-first + 单宝宝 + 免费`
- 公开 V1 移除：`cloud`、`family`、`paywall`
- 首发语言：`简体中文 + 英文`
- 必须支持：`App 内语言切换`
- 成长页英文标题：`Growth`
- 英文辅食标签：更窄、更偏食材描述的一组标签，保留 `First taste`
- V1 移除通知权限请求

---

## 启动顺序建议

第一波可并行启动：

- `Bundle A`：E01-E02
- `Bundle B`：E03-E14
- `Bundle C`：E04
- `Bundle D`：E05
- `Bundle E`：E11-E13

说明：

- `Bundle A` 是数据安全硬阻塞，优先级最高
- `Bundle B` 和 `Bundle C` 可以并行，因为主要写配置和 Shell，不直接碰持久化核心
- `Bundle D` 与 `Bundle C` 都会改 Shell，但职责不同；如果你希望更稳，可以在 `Bundle C` 完成后再开 `Bundle D`
- `Bundle E` 依赖产品拍板已经完成，现在可以启动，但要注意与 `Bundle C` 在语言页文件上可能有交叉

更稳妥的实际顺序：

1. 先开 `Bundle A`
2. 同时开 `Bundle B`
3. 再开 `Bundle C`
4. `Bundle C` 开始后，再开 `Bundle D`
5. `Bundle C` 合并后，再开 `Bundle E`

---

## Bundle A：核心安全

**任务范围：**

- `E01` 替换危险的启动删库恢复逻辑
- `E02` 为启动失败路径补回归测试

**写入范围：**

- `sprout/SproutApp.swift`
- `sprout/Features/Shell/AppStartupErrorView.swift`
- `sproutTests/*Bootstrap*`
- 允许为可测试性做最小范围抽取

**不要修改：**

- `sprout/Features/Shell/Sidebar*`
- `sprout/Features/Onboarding/*`
- 语言切换相关文件
- 业务记录逻辑

**子代理 Prompt：**

```text
你负责初长（sprout）项目的 Bundle A：核心安全。

目标：
1. 修复启动时 ModelContainer 初始化失败会删库重建的问题
2. 把这个行为改成“安全失败 + 用户可见错误页”
3. 为这个启动路径补自动化测试

必须遵守：
- 不要引入第三方依赖
- 不要扩散改动范围
- 不要顺手改 unrelated UI
- 不要删除仍在使用的核心业务逻辑，除非它本身就是危险恢复路径
- 如果为了可测试性需要抽取启动逻辑，保持最小 diff

明确任务：
- 修改 sprout/SproutApp.swift
- 新增 calm、非破坏性的启动失败页
- 移除自动 clearPersistentStoreFiles 的默认恢复路径
- 启动失败时展示阻断型错误 UI，而不是静默删数据
- 为启动成功 / 启动失败 / 测试环境 TestHostView 分别补测试

验收标准：
- 启动失败时不会自动删除用户数据
- 用户能看到明确但克制的错误页
- 测试能覆盖成功和失败状态转换

输出要求：
- 直接修改文件
- 最终回复中列出改动文件路径
- 总结实现方案、剩余风险、你没有验证到的地方
```

**进度字段：**

- 状态：`todo`
- owner：`__________`
- 开始时间：`__________`
- 完成时间：`__________`
- 阻塞项：`__________`

---

## Bundle B：配置清理

**任务范围：**

- `E03` 清理 release entitlement / background mode
- `E14` 移除通知权限请求及相关未完成 wiring

**写入范围：**

- `sprout/Info.plist`
- `sprout/sprout.entitlements`
- `sprout.xcodeproj/project.pbxproj`
- `sprout/Features/Onboarding/OnboardingStepViews.swift`
- 若存在通知入口，可小范围改设置页文案

**不要修改：**

- `SproutApp.swift`
- `SidebarDrawer.swift`
- `LanguageRegionView.swift`
- 记录 / 成长 / 珍藏核心逻辑

**子代理 Prompt：**

```text
你负责初长（sprout）项目的 Bundle B：配置清理。

已确认产品决策：
- V1 不做 CloudKit sync
- V1 不做 family
- V1 不做 paywall
- V1 不请求通知权限
- V1 不上线提醒功能

你的任务：
1. 清理与 V1 不匹配的 capability / entitlement / background mode
2. 从 onboarding 中移除通知权限请求
3. 清理相关误导性文案或无效入口

必须遵守：
- 不要引入新依赖
- 不要碰语言切换实现
- 不要改动与当前任务无关的业务逻辑
- 配置改动必须和代码行为一致

明确改动目标：
- 如果存在 remote-notification background mode，移除
- 移除 APNs 相关 entitlement
- 移除 CloudKit / iCloud 容器相关 entitlement 和空配置
- 修改 onboarding，使其不再请求通知权限
- 如果设置页或 onboarding 里还有通知相关 copy，做最小必要清理

验收标准：
- 公共 V1 路径里不会触发通知权限请求
- 工程配置不再声明未交付的 push / CloudKit 能力
- Debug / Release 配置结构保持可用

输出要求：
- 直接修改文件
- 最终回复列出改动文件
- 标注有哪些配置被删掉
- 标注任何你不确定但建议人工复核的签名/工程配置点
```

**进度字段：**

- 状态：`todo`
- owner：`__________`
- 开始时间：`__________`
- 完成时间：`__________`
- 阻塞项：`__________`

---

## Bundle C：壳层入口清理

**任务范围：**

- `E04` 移除或隐藏假设置、假付费墙、未闭环入口

**写入范围：**

- `sprout/Features/Shell/SidebarDrawer.swift`
- `sprout/Features/Shell/SidebarMenuView.swift`
- `sprout/Features/Shell/PaywallSheet.swift`
- `sprout/Features/Shell/LanguageRegionView.swift`
- `sprout/Localization/Localizable.xcstrings`
- `sproutTests/SidebarRoutingTests.swift`

**不要修改：**

- `SproutApp.swift`
- `BabyRepository.swift`
- `ContentView.swift`
- 深层 i18n 逻辑

**子代理 Prompt：**

```text
你负责初长（sprout）项目的 Bundle C：壳层入口清理。

已确认产品决策：
- V1 从公开路径中移除 cloud / family / paywall
- V1 保留语言入口，但语言切换必须是真功能

你的目标：
1. 让侧边栏和设置页里只剩真实可用入口
2. 去掉所有 public path 上的 coming soon / 假跳转 / 死路
3. 为后续真实语言切换实现保留正确入口

必须遵守：
- 不要自己实现完整语言切换逻辑，只处理入口层和壳层信息架构
- 不要碰宝宝资料全局状态同步
- 不要改持久化层

明确任务：
- 侧边栏移除 cloud / family
- 付费墙从公开路径中移除
- 清理相关无效文案和路由
- 调整 SidebarRoutingTests，使测试反映新的 V1 IA
- LanguageRegionView 不能继续表现为“假切换器”占位页
  - 如果无法在本 bundle 中变成真功能，至少把它收口成一个明确、可继续对接真实语言状态的页面
  - 不要保留纯本地 state + restart alert 的伪实现

验收标准：
- 每个用户可见入口都能通向真实结果
- 没有核心设置项以 coming soon 结束
- 为后续 Bundle E 接入真实语言切换留下干净壳层

输出要求：
- 直接修改文件
- 最终回复列出改动文件
- 说明你如何处理语言页占位问题，方便下一位代理继续接
```

**进度字段：**

- 状态：`todo`
- owner：`__________`
- 开始时间：`__________`
- 完成时间：`__________`
- 阻塞项：`__________`

---

## Bundle D：宝宝资料全局同步

**任务范围：**

- `E05` 修复宝宝资料修改后不能即时同步到全局壳层和 feature 状态的问题

**写入范围：**

- `sprout/ContentView.swift`
- `sprout/Domain/Baby/BabyRepository.swift`
- `sprout/Features/Shell/BabyProfileView.swift`
- `sprout/Features/Shell/AppShellView.swift`
- `sprout/Features/Home/HomeModels.swift`
- `sprout/Features/Home/Components/EmotionHeaderBlock.swift`
- `sprout/Features/Shell/SidebarMenuView.swift`
- 相关测试文件

**不要修改：**

- `SidebarDrawer.swift` 的 IA 决策
- 通知 / entitlement 配置
- 语言切换基础设施

**子代理 Prompt：**

```text
你负责初长（sprout）项目的 Bundle D：宝宝资料全局同步。

目标：
修复宝宝姓名、生日等资料更新后，首页、成长、珍藏、侧边栏等壳层派生状态不能即时刷新的问题。

约束：
- 采用单一 app-level source of truth
- 优先使用 @Observable / SwiftUI 原生数据流
- 不要做巨型 ViewModel
- 保持最小 diff

明确任务：
- 设计并接入一个全局可观察的 active baby profile state
- App 启动时初始化它
- BabyProfileView 修改资料时，同时更新共享状态和 repository
- Home / Growth / Treasure / Sidebar 依赖的派生信息要跟着刷新

至少验证这些结果：
- 头像字母即时变化
- 侧边栏 header 即时变化
- 首页年龄 / 天数即时变化
- 成长页年龄相关显示即时变化
- 珍藏新增内容时年龄计算使用最新资料

输出要求：
- 直接修改文件
- 最终回复列出改动文件
- 说明新的 source of truth 放在哪，哪些模块订阅它
- 标明还缺哪些测试
```

**进度字段：**

- 状态：`todo`
- owner：`__________`
- 开始时间：`__________`
- 完成时间：`__________`
- 阻塞项：`__________`

---

## Bundle E：双语与语言切换

**任务范围：**

- `E11` Treasure i18n 清理
- `E12` Onboarding / 默认名 i18n 清理
- `E13` 真正实现 App 内语言切换

**写入范围：**

- `sprout/Features/Treasure/*`
- `sprout/Domain/Treasure/*`
- `sprout/Features/Onboarding/*`
- `sprout/Domain/Baby/BabyProfile.swift`
- `sprout/Shared/AppLanguage.swift`
- `sprout/Shared/LocalizationService.swift`
- `sprout/Features/Shell/LanguageRegionView.swift`
- `sprout/Localization/Localizable.xcstrings`
- 相关测试文件

**不要修改：**

- `SproutApp.swift` 启动安全逻辑
- entitlement / APNs / CloudKit 配置
- 侧边栏 IA

**子代理 Prompt：**

```text
你负责初长（sprout）项目的 Bundle E：双语与语言切换。

已确认产品决策：
- V1 必须支持简体中文 + 英文
- App 内语言切换必须是真功能
- 成长页英文标题固定为 Growth
- 英文辅食标签不是当前中文标签的机械直译
- 英文标签要更窄、更偏食材描述
- 必须保留 First taste

你的任务包含三部分：
1. Treasure 模块去硬编码中文，并满足双语
2. Onboarding / 默认名 / 迁移逻辑去中文哨兵值
3. 实现真正可持久化、可全局生效的 App 内语言切换

必须遵守：
- 不要只做页面内局部切换
- 不要保留“语言按钮能点，但 app 不真正切换”的伪实现
- 不要继续依赖某个中文默认字符串来判断用户状态
- 尽量保持最小 diff，但不要为了小改而留下半成品

关键要求：
- AppLanguage / LocalizationService / app root 必须串起来
- 切换语言后，核心页面要真正重渲染
- Treasure 的月份、周信、卡片文案要 locale-aware
- Onboarding 默认名要安全本地化
- 成长页英文标题使用 Growth
- 英文辅食标签要重新定义一组可本地化词条，保留 First taste

建议优先顺序：
1. 先打通语言状态持久化和 app root 刷新
2. 再清理 Onboarding 默认值和迁移逻辑
3. 最后清理 Treasure 文案和格式化输出

输出要求：
- 直接修改文件
- 最终回复列出改动文件
- 说明语言切换是如何持久化、如何驱动 root 刷新的
- 列出你新定义的英文辅食标签集合
- 标注还没法验证的双语边界
```

**进度字段：**

- 状态：`todo`
- owner：`__________`
- 开始时间：`__________`
- 完成时间：`__________`
- 阻塞项：`__________`

---

## 汇总进度看板

```markdown
## 第一批子代理进度

| Bundle | 任务 | 状态 | Owner | 开始时间 | 完成时间 | 阻塞项 |
|---|---|---|---|---|---|---|
| A | E01-E02 核心安全 | todo |  |  |  |  |
| B | E03-E14 配置清理 | todo |  |  |  |  |
| C | E04 壳层入口清理 | todo |  |  |  |  |
| D | E05 宝宝资料全局同步 | todo |  |  |  |  |
| E | E11-E13 双语与语言切换 | todo |  |  |  |  |
```

---

## 合并顺序建议

推荐按下面顺序 review / 合并，降低冲突：

1. `Bundle A`
2. `Bundle B`
3. `Bundle C`
4. `Bundle D`
5. `Bundle E`

说明：

- `Bundle E` 最容易和 `Bundle C` 在语言页上冲突，所以放后面
- `Bundle D` 如果改到侧边栏展示，和 `Bundle C` 也可能有轻微冲突
- `Bundle A` 完成后，后续错误处理和测试扩展更安全

