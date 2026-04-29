# Sprout 1.3 开发实施与 QA 验收文档

## 文档信息
- 版本：1.0
- 面向版本：Sprout 1.3
- 文档类型：开发实施 + QA 验收
- 适用对象：产品、iOS 开发、后端、测试、设计
- 依赖版本：Sprout 1.2（Growth 2.0 / Weekly Letter 2.0 / AI 辅食助手 1.0）

---

# 1. 文档目标

本文档用于指导 Sprout 1.3 的研发实施、联调、测试与上线验收。

1.3 的目标不是新增孤立功能，而是把 Sprout 升级为一个可正式公开上线的版本，完成以下闭环：
- 中英双语正式支持
- Pro 订阅能力正式兑现
- 多宝宝管理
- 家庭组协作
- 云同步与账号绑定
- 上线必需的法务、权限、错误恢复和 QA 收口

本文档要求做到：
- 开发可直接按模块实施
- QA 可直接按用例验证
- PM 可据此拆 Epic / Story / Sprint
- 上线前可用作 Launch Gate 检查表

---

# 2. 版本范围

## 2.1 P0 范围
- 国际化正式化（中文简体 / English）
- Pro 订阅正式化
- Multi-Baby 1.0
- Family Group 1.0
- Cloud Sync 正式化
- Account / Device Binding 正式化
- 上线配套：隐私、条款、错误处理、权限说明

## 2.2 P1 范围
- 同步冲突中心
- 家庭组高级角色
- 更细的 Pro 权益中心
- A/B 转化实验
- 同步审计日志可视化

## 2.3 非目标
- 不做 Web 端 / Android 端
- 不增加新的重型 AI 能力
- 不做复杂营养分析
- 不做社交动态 / 内容广场
- 不做医学建议与预警

---

# 3. 总体实施原则

## 3.1 原则
1. local-first
2. 现有 store / repository 增量改造，避免新建平行架构
3. 文案和显示语义分离，杜绝直接持久化最终展示语言文本
4. 权益承诺与实际交付一致
5. 未完成能力不出现在 Paywall 主承诺中
6. 所有失败态必须有用户可见反馈
7. 所有共享 / 多宝宝 / 同步能力都要以 babyID 和 userID 为边界

## 3.2 研发策略
- 优先补“基础设施能力”和“上线阻塞项”
- 新 UI 尽量复用现有 Shell 结构
- 对当前 placeholder 页面优先升级，而不是重做导航
- 先完成功能闭环，再优化视觉与增长链路

---

# 4. 目录与模块映射

## 4.1 现有主要模块
- `Features/Home`
- `Features/Growth`
- `Features/Treasure`
- `Features/Shell`
- `Domain/Records`
- `Domain/Growth`
- `Domain/Treasure`

## 4.2 1.3 重点改动模块
- `Features/Shell/LanguageRegionView.swift`
- `Features/Shell/PaywallView.swift`
- `Features/Shell/AccountView.swift`
- `Features/Shell/CloudSyncView.swift`
- `Features/Shell/SidebarDrawer.swift`
- `Features/Shell/BabyProfile*`
- `Features/Shell/FamilyGroup*`
- `Domain/Treasure/WeeklyLetter*`
- `Domain/Growth/Growth*`
- `Domain/Records/FoodTagCatalog*`
- 所有 toast / formatter / renderer / generated content

---

# 5. 版本级 Launch Gate

以下项为 1.3 上线阻塞项：

1. 中英双语完整可用
2. Pro 购买 / 恢复购买 / 过期处理可用
3. 免费与 Pro 权益 gating 正确
4. 多宝宝可创建 / 切换 / 隔离
5. 家庭组可创建 / 邀请 / 加入 / 查看共享宝宝
6. 云同步可在两台设备间验证成功
7. 登录 / 注册 / 退出 / 设备绑定冲突处理完整
8. Terms / Privacy 为真实链接
9. 关键失败态均有用户可见提示
10. 埋点接入，至少覆盖购买、同步、切换、邀请关键事件

---

# 6. Epic A：国际化正式化

## A.1 目标
支持中文简体与英文双语正式切换，并保证 Home / Growth / Treasure / Shell / Paywall / Account / Cloud Sync / Family Group 全链路文案一致。

## A.2 当前问题
- 仍有硬编码中文
- 一部分生成内容直接持久化为最终中文文本
- 周信 / 成长解读 / toast / 标签显示语义与语言耦合
- 语言页当前还是只读展示，不是真切换器

## A.3 功能要求

### A.3.1 应用内语言切换
支持：
- 中文简体
- English

入口：
- `Language & Region`
- 可从侧边栏进入

保存规则：
- 写入 `AppLanguageManager`
- 切换后全局刷新视图
- 新生成内容使用当前语言

### A.3.2 历史内容语言策略
- 历史周信保留生成时语言
- 用户点击“重新生成本周内容”后，按当前语言生成新文本
- 用户手写 note / caption / 自定义标题不自动翻译

### A.3.3 生成内容语义化
以下对象不得只存最终展示文本：
- Growth 解读
- Weekly Letter
- Undo Toast
- 月份锚点文字
- 推荐食材标签展示名

必须改为：
- 语义 key
- 参数 payload
- 渲染层按当前语言拼接

### A.3.4 标签体系
Food Tag 必须拆成：
- `canonicalKey`
- `displayNameZh`
- `displayNameEn`
- `aliases`

所有存储层只存 `canonicalKey`。

## A.4 数据结构要求

### A.4.1 WeeklyLetter
新增字段：
- `languageCode: String`
- `generatedBy: String`
- `sourceSignature: String`

### A.4.2 GrowthInsight
建议新增类型：
```swift
struct GrowthInsightPayload {
    let kind: GrowthInsightKind
    let metric: GrowthMetric
    let deltaValue: Double?
    let intervalDays: Int?
    let recordCount: Int
    let milestoneCount: Int
}
```

由 renderer 负责生成实际文案。

### A.4.3 Toast
```swift
struct ToastMessage {
    let key: ToastKey
    let args: [String: String]
}
```

## A.5 开发任务

### DEV-A1：字符串资源体系接入
**目标**
- 建立标准本地化资源

**实现要求**
- 使用 `.xcstrings` 或 `Localizable.strings`
- 所有 Shell 文案优先完成
- 所有 Home / Growth / Treasure 用户可见文案接入资源
- 不允许新增硬编码中文或英文

**涉及文件**
- 新增：`Resources/Localizable.xcstrings`
- 全项目用户可见字符串调用点

**DoD**
- 中文和英文资源完整
- 所有新增代码不含裸文本

### DEV-A2：语言切换器正式化
**目标**
- `LanguageRegionView` 从只读展示升级为正式切换器

**当前状态**
- 已接入 `AppLanguageManager`
- 语言 chip 不再是 no-op，选择不同语言会持久化设置并更新 `LocalizationService`
- 侧边栏菜单使用当前语言重新计算文案

**实现要求**
- 点击语言项后写入设置
- 切换后刷新当前页面
- 重新进入 App 保持上次选择
- 重复点击当前语言不应重复提交

**边界条件**
- 首次安装默认跟随系统语言
- 若系统语言非中文 / 英文，则默认英文

**DoD**
- 切换即生效
- 重启后仍保持
- `AppLanguageManagerTests` 覆盖语言选择去重与侧边栏文案重算

### DEV-A3：生成内容语义化改造
**目标**
- WeeklyLetter / Growth 解读 / toast 不再直接持久化最终文案

**实现要求**
- 增加 payload 层
- renderer 按语言输出文案
- 历史数据兼容旧结构

**兼容策略**
- 旧周信若只有文本，直接展示原文本
- 新周信按新结构生成

**DoD**
- 新旧数据都可正常展示
- 切语言不导致旧内容丢失

### DEV-A4：FoodTag canonical 化改造
**目标**
- 所有 food tag 按 canonicalKey 存储

**实现要求**
- 迁移现有 tags
- UI 展示时按语言映射 displayName
- AI 返回结果也必须走 canonical 化

**DoD**
- 历史标签不丢
- 中文 / 英文切换时标签展示正确

## A.6 QA 验收项

### QA-A1 语言切换
- [ ] 默认跟随系统语言
- [ ] 中文环境首次打开显示中文
- [ ] 英文环境首次打开显示英文
- [ ] 应用内切换为英文后立即生效
- [ ] 应用内切换回中文后立即生效
- [ ] 杀进程重启后语言保持

### QA-A2 页面覆盖
- [ ] Home 全页无残留中文/英文混杂
- [ ] Growth 全页无残留中文/英文混杂
- [ ] Treasure 全页无残留中文/英文混杂
- [ ] Shell / Paywall / Account / Sync / Family Group 全页无残留

### QA-A3 生成内容
- [ ] 中文下生成周信为中文
- [ ] 切英文后新生成周信为英文
- [ ] 旧周信保持原语言
- [ ] 重新生成后按当前语言更新
- [ ] 手写 note 不会被翻译

### QA-A4 标签
- [ ] 中文模式显示中文食材标签
- [ ] 英文模式显示英文食材标签
- [ ] 历史记录标签不丢失
- [ ] AI 建议标签切换语言后展示正确

---

# 7. Epic B：Pro 订阅正式化

## B.1 目标
实现正式的 Pro 购买、恢复购买、权益 gating 和过期处理。

## B.2 权益定义
### 免费版
- 1 个宝宝
- 单设备本地使用
- 基础记录 / Growth / Treasure
- 不可使用家庭组
- 不可使用云同步
- AI 限次或不可用

### Pro
- 多宝宝
- 家庭组
- 云同步
- AI 能力
- 后续高级报告

## B.3 产品规则
1. 权益必须服务端或本地可靠可验证
2. 购买后即时解锁
3. 恢复购买可恢复权益
4. 过期后不删用户数据
5. 超出免费额度的数据保留但限制继续新增

## B.4 开发任务

### DEV-B1：Subscription Manager
**目标**
- 建立统一的订阅状态管理
- 进度：已落地 `ProCapability` 与 `SubscriptionManager.allows(_:)`，侧边栏入口已从裸 `isPro` 改为声明 `requiredCapability`

**建议结构**
```swift
struct SubscriptionEntitlement {
    let tier: SubscriptionTier
    let isActive: Bool
    let expiresAt: Date?
    let capabilities: Set<Capability>
}
```

**Capability 示例**
- `.multiBaby`
- `.familyGroup`
- `.cloudSync`
- `.aiAssistant`

**DoD**
- 全局可读
- 页面 gating 不直接写死 plan 名称
- 页面只声明 capability，实际放行统一由 subscription capability 层判断

### DEV-B2：Paywall 对齐
**目标**
- Paywall 文案与真实能力一致
- 进度：已引入 `PaywallContent` 作为 Paywall 主承诺来源；当前未通过验收的 Pro 能力不会进入可购买权益列表，订阅 CTA 暂不开放

**实现要求**
- 删除未上线承诺
- 替换 Terms / Privacy 为真实链接
- 增加 restore purchase
- 增加 plan 选择与失败提示
- Terms / Privacy 已改为仓库内 `docs/legal/terms-of-service.md` 与 `docs/legal/privacy-policy.md` 的公开链接来源
- restore / purchase 失败会向 Paywall 展示克制错误提示，不再静默吞掉失败

### DEV-B3：Feature Gating
**目标**
- 多宝宝 / 家庭组 / 云同步 / AI 入口统一按 capability 判断

**实现要求**
- 未开通时展示 paywall
- 已开通时直接进入
- 过期时根据 capability 实时退回限制

### DEV-B4：过期处理
**目标**
- 数据不丢，能力收回

**规则**
- 多宝宝：超出 1 个的宝宝保留但不可新增/编辑
- 云同步：停止同步，保留本地数据
- 家庭组：保留查看或降级为只读，由产品决定；建议首版为不可新建、已存在家庭保留只读
- AI：不可继续调用

## B.5 QA 验收项

### QA-B1 购买流程
- [x] 可成功拉起购买（`StoreKitProvider.purchase(productID:)` 统一走 StoreKit 2 `Product.purchase()`；真实 sandbox 账号仍需 release 前手动 smoke）
- [x] 月付购买成功后权益生效（`SubscriptionManagerTests/test_purchaseMonthlySandboxResult_unlocksProAndCachesEntitlement`）
- [x] 年付购买成功后权益生效（`SubscriptionManagerTests/test_restoreSandboxPurchase_unlocksProFromCurrentEntitlements` 覆盖 yearly entitlement 生效）
- [x] 购买失败有提示（`PaywallView` 捕获 purchase error 后展示克制错误提示）
- [x] 用户取消购买有提示且不误解锁（`SubscriptionManagerTests/test_cancelledSandboxPurchase_doesNotUnlockOrCachePro`；`PaywallView` 对 `.cancelled` 不 dismiss、不解锁）

### QA-B2 恢复购买
- [x] 同账号重装可恢复购买（`SubscriptionManagerTests/test_restoreSandboxPurchase_unlocksProFromCurrentEntitlements`）
- [x] 新设备登录后可恢复权益（同一 restore/current entitlement 路径；真实 Apple ID 新设备需手动 smoke）
- [x] restore 失败有错误提示（`SubscriptionManagerTests/test_restorePurchases_propagatesProviderError`；`PaywallView` 捕获 restore error）

### QA-B3 权益 gating
- [x] 免费用户创建第二个宝宝触发 paywall / gate（`BabyRepositoryTests/freeEntitlementBlocksSecondBabyWithoutDeletingExistingData` 覆盖 domain gate；UI 入口在 DEV-C 补列表页时接 paywall）
- [x] 免费用户进入家庭组触发 paywall（`SidebarAccessPolicyTests/freeUserFamilyGroupShowsPaywall`）
- [x] 免费用户进入云同步触发 paywall（`SidebarAccessPolicyTests/freeUserCloudSyncShowsPaywall`）
- [x] Pro 用户直接进入对应功能（`SidebarAccessPolicyTests/proUserCloudSyncNavigatesDirectly`；`SubscriptionManagerTests/test_allProCapabilities_areAllowedWhenSubscribed`）

### QA-B4 过期处理
- [x] 订阅过期后不可新增第二个宝宝（`BabyRepositoryTests/expiredEntitlementBlocksAdditionalBabyWithoutDeletingExistingData`）
- [x] 订阅过期后家庭组入口限制正确（`SidebarAccessPolicyTests/expiredUserFamilyGroupShowsPaywall`）
- [x] 订阅过期后云同步停止（`CloudSyncStatusStoreTests/expiredEntitlementStopsCloudSyncWithoutDeletingLocalData`）
- [x] 订阅过期不会删除本地数据（multi-baby / cloud sync 两条过期测试均验证本地数据保留）

---

# 8. Epic C：Multi-Baby 1.0

## C.1 目标
支持在同一账号下管理多个宝宝，并保证记录、成长、珍藏、同步严格按 babyID 隔离。

## C.2 用户故事
- 我想创建第二个宝宝
- 我想快速切换宝宝
- 我不希望 A 宝宝的数据出现在 B 宝宝页面

## C.3 功能要求
1. 新增宝宝
2. 编辑宝宝资料
3. 删除宝宝
4. 切换 active baby
5. 宝宝列表展示
6. 页面联动刷新

## C.4 数据要求
所有以下对象必须带 `babyID`：
- Home record
- Growth record
- Growth milestone
- Treasure memory
- Weekly Letter
- AI 食材建议上下文
- Cloud Sync 变更项

## C.5 UI 要求
### Baby List / Switcher
展示字段：
- 头像
- 昵称
- 生日
- 当前是否激活

操作：
- 点击切换
- 新增宝宝
- 编辑资料
- 删除宝宝

### 删除宝宝规则
- 需二次确认
- 提示影响范围
- 若家庭组正在共享该宝宝，需额外确认

## C.6 开发任务

### DEV-C1：BabyProfileStore 扩展
**目标**
- 从单宝宝转为多宝宝集合 + activeBabyID
- 进度：已在 `BabyRepository` 落地最小集合能力，包括 `fetchBabies()`、`createBaby(...)`、`activateBaby(id:)`；创建第二个宝宝会激活新宝宝并停用旧 active baby，切换会同步 `ActiveBabyState`

**建议结构**
```swift
struct BabyProfile {
    let id: UUID
    var name: String
    var birthday: Date
    var avatar: String?
    var isShared: Bool
}
```

```swift
struct BabyRegistry {
    var activeBabyID: UUID?
    var babies: [BabyProfile]
}
```

### DEV-C2：页面联动刷新
**目标**
- 切换宝宝后 Home / Growth / Treasure / Shell 同步刷新
- 进度：`ContentView` 监听 `ActiveBabyState.headerConfig` 后会更新 Home / Growth / Treasure；Home 和 Treasure 在已加载后立即刷新数据，Growth 继续走 `refreshAfterProfileChange()`

**实现要求**
- 使用统一 activeBaby publisher / observer
- 避免页面保留旧数据缓存

### DEV-C3：Pro gating
- 免费版限制 1 个宝宝
- 触发第二个宝宝创建时弹 paywall

### DEV-C4：删除宝宝保护
- 删除前检查：
  - 是否为 active baby
  - 是否有共享家庭组
  - 是否有未同步变更

### DEV-C5：数据隔离最小闭环
**目标**
- Home / Growth / Treasure 默认只读取当前 active baby 数据

**当前状态**
- `RecordRepository.fetchTodayRecords` / `fetchHistory` / `fetchRecentFoodTags` 已按 active babyID 过滤，新增 Home 记录写入 active babyID
- `GrowthRecordRepository.fetchRecords` / `fetchLatestRecord` 已按 active babyID 过滤，新增 Growth 记录写入 active babyID
- `TreasureRepository.fetchMemoryEntries`、周信 digest 内部 memory / milestone / growth 查询已按 active babyID 过滤，新增 Memory 写入 active babyID
- 本轮未给 `WeeklyLetter` 增加 `babyID` 字段，避免在 DEV-C 引入 SwiftData staged migration 变更；周信持久化的 baby 级隔离需后续 schema 任务单独处理

**测试覆盖**
- `BabyRepositoryTests` 覆盖创建第二个宝宝、切换 active baby、header 状态同步
- `RecordRepositoryTests` 覆盖 Home 今日记录和最近辅食标签按 active baby 过滤
- `GrowthRecordRepositoryTests` 覆盖 Growth 记录按 active baby 过滤及新增记录写入 active babyID
- `TreasureRepositoryTests` 覆盖珍藏记忆按 active baby 过滤

## C.7 QA 验收项

### QA-C1 创建 / 编辑
- [ ] 可成功创建第二个宝宝（Pro）
- [ ] 免费用户无法创建第二个宝宝
- [ ] 可编辑宝宝昵称 / 生日 / 头像

### QA-C2 切换
- [x] 切换 active baby 后 Home 刷新
- [x] 切换 active baby 后 Growth 刷新
- [x] 切换 active baby 后 Treasure 刷新
- [ ] 周信内容随宝宝切换变化

### QA-C3 数据隔离
- [x] A 宝宝记录不出现在 B 宝宝下
- [x] A 宝宝成长数据不出现在 B 宝宝下
- [ ] A 宝宝周信不出现在 B 宝宝下

### QA-C4 删除
- [ ] 删除宝宝前有二次确认
- [ ] 删除 active baby 后 activeBaby 自动切换为其他可用宝宝
- [ ] 删除共享宝宝有额外提示
- [ ] 删除后页面不崩溃

---

# 9. Epic D：Family Group 1.0

## D.1 目标
实现最小可用家庭协作：创建家庭组、邀请成员、加入、共享宝宝、共同记录。

## D.2 角色模型
- Owner
- Member

### Owner 权限
- 创建 / 解散家庭组
- 邀请成员
- 移除成员
- 管理哪些宝宝共享

### Member 权限
- 查看共享宝宝
- 新增记录
- 编辑自己创建的记录
- 不可解散家庭组

## D.3 功能范围
1. 创建家庭组
2. 邀请成员
3. 接受邀请
4. 查看成员列表
5. 共享宝宝开关
6. 共同记录共享宝宝
7. 展示记录创建者

## D.4 不做
- 多家庭组
- 聊天
- 复杂角色树
- 细粒度字段权限

## D.5 数据结构建议
```swift
struct FamilyGroup {
    let id: UUID
    let ownerUserID: UUID
    var members: [FamilyMember]
    var sharedBabyIDs: [UUID]
}

struct FamilyMember {
    let userID: UUID
    let role: FamilyRole
    let joinedAt: Date
}
```

记录扩展：
- `createdByUserID`
- `updatedByUserID`
- `familyGroupID?`

## D.6 开发任务

### DEV-D1：FamilyGroupStore
**目标**
- 正式替代 placeholder

**功能**
- create group
- fetch group
- invite
- accept invite
- remove member
- share / unshare baby

### DEV-D2：Invitation Flow
**建议首版**
- 邀请链接或邀请码二选一
- 首版建议邀请码，减少 URL deep link 复杂度

**状态**
- pending
- accepted
- expired
- revoked

### DEV-D3：共享宝宝控制
**目标**
- 宝宝加入家庭共享时才可被成员访问

### DEV-D4：记录者展示
**目标**
- 共享场景下在记录项上显示“由谁记录”

### DEV-D5：权限校验
**目标**
- 所有编辑删除操作按角色和创建者限制

## D.7 QA 验收项

### QA-D1 创建与加入
- [ ] Pro Owner 可创建家庭组
- [ ] 非 Pro 不可创建家庭组
- [ ] 受邀人可成功加入
- [ ] 无效邀请码不可加入
- [ ] 过期邀请码不可加入

### QA-D2 成员与共享
- [ ] Owner 可看到成员列表
- [ ] Owner 可共享宝宝
- [ ] 未共享宝宝 Member 不可见
- [ ] 共享后 Member 可见该宝宝记录

### QA-D3 记录协作
- [ ] Member 可新增共享宝宝记录
- [ ] Member 可编辑自己创建的共享记录
- [ ] Member 不可删除 Owner 创建的记录（若策略如此）
- [ ] 记录展示创建者信息

### QA-D4 退出与移除
- [ ] Owner 可移除成员
- [ ] 成员退出后立刻失去共享宝宝访问权限
- [ ] 被移除后不再看到共享记录

---

# 10. Epic E：Cloud Sync 正式化

## E.1 目标
实现可理解、可信赖、可恢复的云同步体验。

## E.2 核心规则
1. local-first
2. 未登录仅本地使用
3. 登录后开始同步
4. 同步失败不删除本地数据
5. 用户可手动同步
6. 至少展示 last sync / pending changes / error 状态
7. SwiftData staged migration 中每个 schema 版本必须有唯一模型集合，禁止出现跨阶段重复 version checksum

## E.3 同步对象
- Baby profiles
- Home records
- Growth records
- Growth milestones
- Treasure memories
- Weekly letters
- Subscription snapshot（只读）
- Family group metadata

## E.4 冲突策略
首版简单处理：
- 新增记录：合并
- 同条记录编辑冲突：last write wins
- 删除冲突：删除优先
- 关键元数据保留 `updatedAt`

## E.5 状态机
```swift
enum SyncPhase {
    case idle
    case syncing
    case success
    case error
    case blockedByAuth
    case blockedByBinding
}
```

## E.6 开发任务

### DEV-E1：CloudSyncStatusStore 正式化
**目标**
- 将现有状态页接到真实同步引擎
- 进度：已通过 `CloudSyncStatusStore.syncIfEligible(authState:reason:)` 接入 `SyncEngine.performFullSync`；未登录、绑定阻塞等非 authenticated 状态不会触发真实同步

**要求**
- phase
- lastSyncAt
- pendingChangeCount
- pendingDeletionCount
- latestError
- syncNow()

### DEV-E2：Sync Engine
**目标**
- 完成 pull / push 基础链路
- 进度：`SupabaseService` 已从 stub 切到真实 Supabase Swift SDK，覆盖 Auth session restore / sign in / sign up / sign out、Postgres RPC upsert / soft delete / incremental fetch、Storage upload / download / delete；默认同步仍通过本地 `SyncEngine` 统一处理游标、dirty row 跳过、资产下载和删除墓碑
- 后端迁移：新增 `supabase/migrations/202604270001_account_cloud_sync.sql`，包含 `profiles`、`baby_profiles`、`record_items`、`memory_entries`、`server_now`、版本化 upsert / soft delete RPC、RLS policy 与私有 Storage bucket
- 配置防护：`SupabaseConfig` 会拒绝 `/rest/v1/` endpoint URL，必须使用 Supabase project root URL

**要求**
- 支持增量同步
- 支持前后台触发
- 支持登录后首次同步
- 支持退出登录后暂停同步
- 新增或移除本地模型时，同步更新 `SproutMigrationPlan` 与 `SproutSchemaRegistry`
- 每次 schema 调整都必须覆盖“migration plan 不重复模型形状”的启动测试

### DEV-E3：错误恢复
**目标**
- 网络失败 / 鉴权失败 / 冲突失败有明确提示
- 进度：同步失败会进入 `SyncUIPhase.error` 并由 Cloud Sync 页面显示可读错误；push/pull 失败不会清空本地 SwiftData 数据，dirty local row 在 pull 时会跳过，版本冲突会刷新远端版本后重试一次

**要求**
- 用户可点击 retry
- 不影响本地继续记录

### DEV-E4：两设备校验工具
**目标**
- 为 QA 提供可观察的同步验证方式
- 进度：新增 gated `RealSupabaseServiceSmokeTests`，默认不依赖真实账号；设置 `SPROUT_REAL_SUPABASE_SMOKE=1` 和测试账号环境变量后可验证真实 Auth 登录 / 退出、`server_now`、三类同步表 upsert / fetch / soft delete、私有 Storage 上传 / 下载 / 删除链路

**要求**
- 增加 debug 标记或 sync log 面板（Debug only）

## E.7 QA 验收项

### QA-E1 基础同步
- [x] 登录后自动开始同步（`AuthManagerTests` 覆盖登录后触发 sync hook）
- [ ] A 设备新增记录，B 设备可拉到（需真实双设备 QA）
- [ ] B 设备新增记录，A 设备可拉到（需真实双设备 QA）
- [x] 手动 sync 可成功（`CloudSyncStatusStoreTests/manualSyncPushesPendingChanges`）

### QA-E2 同步状态
- [x] 同步中显示 syncing（`CloudSyncStatusStore` 接 `SyncUIPhase.pushing`）
- [x] 完成后显示 last sync（`SyncEngineTests/fullSyncPullsRowsAndSavesCursor` 间接覆盖 completion state）
- [x] 待同步计数准确（`SyncEngineTests` 覆盖 pending upsert 流程）
- [x] 删除待同步计数准确（`SyncEngineTests/pushPipelineDeletesInFixedOrder`）

### QA-E3 失败恢复
- [x] 断网 / 服务失败时同步失败有提示（`SyncEngineTests/offlineUpsertFailureRetriesWithoutDataLoss` 覆盖 error phase；`CloudSyncView` 展示克制错误文案）
- [x] 恢复网络后可重试成功（`SyncEngineTests/offlineUpsertFailureRetriesWithoutDataLoss` 清除故障后再次 manual sync）
- [x] 鉴权失效时有提示并引导登录（`SyncEngineTests/unauthenticatedSyncKeepsLocalPendingRows` 覆盖 sync error；未登录 Cloud Sync 页进入账号提示）
- [x] 同步失败不影响本地新增记录（`SyncEngineTests/partialFailurePersistsEarlierSuccess`、`offlineUpsertFailureRetriesWithoutDataLoss`、dirty row pull skip tests）
- [x] 远端删除失败不会清掉本地 tombstone（`SyncEngineTests/softDeleteFailureKeepsTombstoneQueuedForRetry`）

### QA-E4 退出登录
- [x] 退出登录后同步停止（Cloud Sync 手动入口仅 authenticated 时触发；`AuthManagerTests/signOutDoesNotClearBinding` 覆盖退出状态）
- [x] 本地数据保留（Auth sign out 只清 current user / auth state，不删除 SwiftData）
- [ ] 重新登录后可继续同步（需真实账号回归）

### QA-E5 本地 schema 迁移
- [x] 启动容器创建不触发 `Duplicate version checksums across stages detected`（`SproutAppStartupTests/testMigrationPlanContainerStartsWithoutDuplicateVersionChecksums`）
- [x] 当前默认 schema 可插入并读取所有现行模型，包括 Growth milestones（`SproutAppStartupTests/testDefaultSchemaContainsAllModelTypes`）
- [x] migration plan 的 schema 模型集合不跨版本重复（`SproutAppStartupTests/testMigrationPlanDoesNotRepeatModelShapes`）

### QA-E6 真实后端 Smoke
- [x] 默认测试不需要真实凭据（`RealSupabaseServiceSmokeTests` 未设置环境变量时直接通过）
- [x] 设置真实测试账号后 Auth smoke 可登录并退出（2026-04-28 已用 QA 测试账号验证）
- [x] 设置真实测试账号后 data chain smoke 可写入并拉取 baby profile、record item、memory entry，随后 soft delete 生成 tombstone（2026-04-28 已验证）
- [x] 设置真实测试账号后私有 Storage smoke 可上传、下载并删除 `baby-avatars` 对象（2026-04-28 已验证）
- [x] SQL Editor 已执行 `supabase/migrations/202604270001_account_cloud_sync.sql` 且表 / bucket 存在（bucket 已确认为 private）

---

# 11. Epic F：Account / Device Binding 正式化

## F.1 目标
完成登录、注册、退出登录、忘记密码、设备绑定冲突处理。

## F.2 用户规则
1. 每设备同一时刻只绑定一个账号
2. 已绑定设备切换账号时需给风险提示
3. 退出登录保留本地数据
4. 本地数据是否合并到新账号需有明确策略

## F.3 建议策略
首版建议：
- 设备已绑定账号 A 时，登录账号 B 进入 `blockedByAccountBinding`
- 给出两个选项：
  - 取消并返回
  - 确认切换账号（需再次确认）
- 切换账号时，不自动删除本地数据，但停止原账号同步
- 对于本地待同步数据，需提示“将按当前账号重新建立绑定”

## F.4 开发任务

### DEV-F1：Auth Flow 完整化
- 登录
- 注册
- 忘记密码
- 错误提示
- 登录成功回跳

### DEV-F2：Binding Conflict Flow
- 冲突页
- 风险说明
- 用户选择路径

### DEV-F3：Sign Out Flow
- 退出登录确认
- 保留本地数据说明
- 清理 token
- 停止同步

## F.5 QA 验收项
- [x] 可正常注册（`AuthManagerTests/signInBindsAccountAndTriggersHooks` 覆盖同一认证收口；真实注册仍需后端 smoke）
- [x] 可正常登录（`AuthManagerTests/signInBindsAccountAndTriggersHooks`）
- [x] 错误密码有提示（`AuthManagerTests/invalidPasswordUsesUserFacingError`）
- [x] 忘记密码链路可达（`AuthManagerTests/resetPasswordDelegatesToService`；真实邮件投递需 Supabase 邮件配置 QA）
- [x] 已绑定账号时切换另一账号有冲突页（`AuthManagerTests/signInMismatchedAccountBecomesBlockedWithoutAutoSignOut`；`AccountView` 渲染 `blockedByAccountBinding`）
- [x] 确认切换账号后重新绑定设备且触发同步（`AuthManagerTests/confirmedAccountSwitchRebindsDevice`）
- [x] 退出登录不删除本地数据（`AuthManagerTests/signOutDoesNotDeleteLocalData`）
- [x] 退出后同步状态变化正确（`AuthManagerTests/signOutDoesNotClearBinding`；Cloud Sync 入口仅 authenticated 时触发真实同步）

---

# 12. Epic G：上线配套与法务

## G.1 必做项
1. Terms of Service
2. Privacy Policy
3. 订阅说明
4. 家庭共享与云同步隐私说明
5. 相机 / 照片 / 通知权限说明
6. 错误提示统一规范
7. 崩溃监控与关键埋点

## G.2 开发任务

### DEV-G1：真实外链替换
- 替换 Paywall 中示例链接
- 设置页增加条款入口

### DEV-G2：权限请求前说明
- 首次使用相机/相册前说明用途
- 首次启用通知前说明用途（若已上）

### DEV-G3：错误提示系统统一
建议统一错误呈现：
- inline error
- blocking alert
- retry action
- non-blocking toast

### DEV-G4：埋点接入
关键事件：
- language_changed
- purchase_started
- purchase_succeeded
- purchase_restored
- baby_created
- baby_switched
- family_group_created
- family_invite_sent
- family_invite_accepted
- sync_started
- sync_succeeded
- sync_failed
- account_binding_conflict_shown

## G.3 QA 验收项
- [ ] Terms 链接可打开
- [ ] Privacy 链接可打开
- [ ] 权限拒绝后有合理提示
- [ ] 关键错误均有用户可见反馈
- [ ] 埋点触发无明显遗漏

---

# 13. 联调要求

## 13.1 前后端联调项
- Auth
- Subscription entitlement
- Cloud sync
- Family group
- Invite code/link
- Shared baby visibility

## 13.2 联调验收
- iOS 与后端字段一致
- 错误码有统一映射
- 超时、鉴权失败、资源不存在、权益不足都有明确处理

---

# 14. QA 测试矩阵

## 14.1 账号维度
- 未登录免费用户
- 已登录免费用户
- 已登录 Pro 用户
- 已过期 Pro 用户

## 14.2 语言维度
- 中文
- 英文

## 14.3 数据维度
- 单宝宝
- 多宝宝
- 共享宝宝
- 有历史旧数据
- 有未同步本地数据

## 14.4 设备维度
- 单设备
- 双设备同步
- 已绑定设备换账号

## 14.5 网络维度
- 正常网络
- 弱网
- 断网
- 登录失效

---

# 15. 回归清单

1. Home 基础记录不受 1.3 影响
2. Growth 图表与解读不受 1.3 影响
3. Treasure 周信与记忆卡不受 1.3 影响
4. AI 辅食助手在免费 / Pro / 双语 / 多宝宝下行为正确
5. Undo / 删除 / 撤销在共享与同步场景下不出现脏状态
6. App 启动性能无明显退化
7. 语言切换无明显闪烁或空白

---

# 16. 开发完成定义（DoD）

每个 Story 完成必须满足：
- 代码合并到主分支
- 单元测试通过
- QA 用例全部通过
- 文案已本地化
- 埋点已接入
- 失败态已处理
- 有至少 1 个回归用例
- 不引入新的裸文案和未受控 capability 判断

---

# 17. 里程碑建议

## M1：I18N Foundation
- 字符串资源
- 语言切换
- 语义化输出改造
- canonical tag 改造

## M2：Subscription + Account + Sync
- 购买 / 恢复购买
- entitlement
- 登录 / 退出 / 绑定冲突
- 云同步正式化

## M3：Multi-Baby + Family Group
- 多宝宝
- active baby
- 家庭组
- 共享宝宝

## M4：Launch Polish
- 法务页
- 权限说明
- 埋点
- 修复收口
- 双设备和双语全链路回归

---

# 18. 最终上线验收 Checklist

## 18.1 核心功能
- [ ] 双语完整可用
- [ ] Pro 能买能恢复
- [ ] 免费 / Pro 权益正确
- [ ] 可创建第二个宝宝
- [ ] 可切换宝宝
- [ ] 可创建家庭组
- [ ] 可邀请与加入
- [ ] 可共享宝宝
- [ ] 可云同步
- [ ] 两台设备验证通过

## 18.2 稳定性
- [ ] 断网下可继续本地记录
- [ ] 同步失败不丢数据
- [ ] 账号切换不崩溃
- [ ] 删除宝宝 / 退出家庭组 / 退出登录路径安全

## 18.3 上线合规
- [ ] Terms / Privacy 就绪
- [ ] 权限说明就绪
- [ ] 订阅说明准确
- [ ] 审核截图和 metadata 与产品实际一致

---

# 19. 建议的后续拆分方式

建议你把 1.3 再拆成以下交付包：
1. I18N 包
2. Subscription 包
3. Multi-Baby 包
4. Family Group 包
5. Cloud Sync 包
6. Launch Polish 包

每个包再继续拆成：
- Story
- Dev Task
- API 对接
- QA Case
- Regression Case

---

# 20. 总结

1.3 的核心不是“再加几个功能”，而是把 Sprout 从内容体验版升级成正式产品版。

开发上最关键的三件事：
- 把语言和文案从业务逻辑里拆出来
- 把 capability 和订阅权益做成统一系统
- 把 baby、user、family、sync 四个维度的边界彻底理顺

只要这三件事收稳，1.3 就不是一个“功能拼装版”，而会是一个真正能公开上线和持续迭代的版本。
