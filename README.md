# 初长 sprout

Sprout. At your own pace.

让成长，按自己的节奏发生。

初长是一个面向 0-3 岁宝宝家庭的成长记录 App。它服务的是疲惫、缺觉、没有精力和复杂界面周旋的父母：快速记录，低噪音反馈，本地优先保存，不用连续打卡、奖杯或高刺激的成长焦虑来驱动使用。

## 产品原则

- 安静、克制、低焦虑。
- 核心记录流程必须快速完成，不依赖网络或 AI。
- 默认 local-first，云同步只能增强体验，不能阻塞记录。
- 视觉上保持极简、温暖、编辑感和 Apple 原生气质。
- 不做卡通化母婴 App，不使用高饱和颜色、彩色标签、游戏化奖励或庆祝动画。

## 技术栈

- 平台：iOS 17.0+
- UI：SwiftUI
- 数据持久化：SwiftData
- 状态观察：Observation
- 工程：Xcode project
- 同步能力：Supabase 相关服务与本地同步引擎
- 订阅能力：StoreKit 相关领域模型与服务封装

## 功能模块

- 首页记录：奶、尿布、睡眠、辅食等高频记录入口与时间线展示。
- 成长：身高、体重、里程碑、趋势图和克制的解释性文案。
- 珍藏：照片、文字记忆、时间线、月锚点和周信。
- 侧边栏：宝宝资料、设置入口、订阅与状态信息承载。
- 同步：本地优先的数据迁移、游标、资产同步和删除墓碑。
- 国际化：字符串目录、语言状态、格式化服务和文案模板提供器。

## 目录结构

```text
sprout/
  DesignSystem/        语义化颜色、排版、形状等设计系统入口
  Domain/              业务模型、仓储、规则、格式化和服务
  Features/            按功能拆分的 SwiftUI 页面、容器、组件和 sheet
  Shared/              跨功能复用的 UI、日志、本地化和工具类型
  Localization/        String Catalog 与本地化资源
  Assets.xcassets/     App 图标、颜色和图片资源

sproutTests/           单元测试与测试支撑
Config/                本地构建配置示例和环境配置
docs/                  PRD、规格、验收、发布与实现计划
```

核心边界：

- `Features` 负责渲染、布局和交互接线，不承载复杂业务逻辑。
- `Domain` 放业务规则、数据转换、仓储和副作用边界。
- `Shared` 只放真正跨模块复用的轻量能力。
- `DesignSystem` 提供语义化 token，业务页面不应散落一次性色值。

## 本地运行

1. 使用 Xcode 打开 `sprout.xcodeproj`。
2. 选择 `sprout` scheme。
3. 如需启用 Supabase 相关能力，复制配置模板并填入本地值：

```bash
cp Config/Supabase.xcconfig.example Config/Supabase.local.xcconfig
```

4. 构建并运行到 iOS 17.0+ 模拟器或真机。

核心记录流程应在没有网络、没有 AI 服务、没有云同步成功的情况下保持可用。

## 测试

使用 Xcode Test 运行 `sproutTests`，或通过命令行执行：

```bash
xcodebuild test \
  -project sprout.xcodeproj \
  -scheme sprout \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

测试覆盖重点包括：

- 记录校验、时间线格式化和首页 store。
- 成长数据、图表交互、里程碑和格式化。
- 珍藏时间线、周信、图片路径和仓储。
- 同步状态、游标、迁移、启动容器和订阅状态。
- 国际化语言状态、模板和本地化格式。

## 开发约束

- 优先使用 Apple 原生能力；未经明确要求，不引入第三方依赖。
- View 文件保持小而可组合，复杂逻辑下沉到 store、service 或 domain。
- 应用级和功能级状态优先使用 `@Observable`。
- View 本地状态按 SwiftUI 习惯使用 `@State`、`@Binding`、`@Environment`、`@FocusState`、`@Bindable`。
- 公共类和公开函数保持清晰命名，复杂业务决策才添加注释。
- 不硬编码业务页面颜色，统一走语义化设计 token。
- 不使用纯黑文本、高饱和提示色或刺眼错误红。
- 错误与危险状态优先通过文案、层级和确认流程表达，不靠强刺激视觉。
- 成长解读等解释性文本不使用 emoji 作为前缀或图标，避免缺字、误读和额外视觉噪音。
- 修改 SwiftData schema 时，staged migration 中每个版本的模型集合必须保持唯一；不要用“删除后再新增同一模型集合”的方式推进版本，否则会触发重复 version checksum。
- 变更保持最小 diff，避免巨型 ViewModel、God Object 和无关重构。

## 设计系统基线

基础语义色：

- `background`：Light `#F7F4EE`，Dark `#1C1A18`
- `cardBackground`：Light `#FFFFFF`，Dark `#2A2724`
- `primaryText`：Light `#3A342F`，Dark `#EFEAE0`
- `accent`：`#8FAE9B`
- `highlight`：`#D89A7A`，仅用于 AI 周报或重要里程碑

派生层级：

- `secondaryText = primaryText.opacity(0.6)`
- `tertiaryText = primaryText.opacity(0.4)`

默认形状：

```swift
RoundedRectangle(cornerRadius: 24, style: .continuous)
```

默认动效：

```swift
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
```

## 维护准则

每次实现前优先问：

> 这是否让疲惫的父母用更少噪音、更低负担完成记录？

如果答案是否定的，应该优先删减复杂度，而不是增加入口、动效、提示或解释。
