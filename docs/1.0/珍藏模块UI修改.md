下面是一版可以直接交给 **Codex / SwiftUI 开发** 的【珍藏模块】可执行改稿 spec。
目标只有一个：

> **把珍藏页做回“杂志级单列大画幅”**，删掉所有组件感、管理感、工具感。

---

# 珍藏模块改稿目标

## 设计目标

* 单列
* 大画幅
* 极简留白
* 图像优先
* 文本安静承接
* 多图仍保持杂志排版感

## 硬约束

* 不出现顶部筛选栏
* 不出现白色胶囊“+ 留住今天”
* 不出现图片四周 padding
* 不出现明显边框线
* 不出现深色脏底
* 不出现九宫格
* 不出现整个卡片一起横滑
* 不出现重阴影

---

# 一、先删掉的内容

## 1. 删除顶部 Filter Bar / Segmented Control

直接删掉以下整块：

* 全部记忆
* 星标时刻
* 时光信笺

### 删除要求

* 删除视图组件
* 删除占位 spacing
* 删除与其相关的 divider / background / sticky 行为
* 列表内容直接承接全局导航栏下方

---

## 2. 删除右上角“+ 留住今天”胶囊按钮

删除：

* 白底
* 圆角胶囊
* 阴影
* 文案“留住今天”

替换为：

* 纯图标按钮 `plus.viewfinder`

---

## 3. 删除 Memory Card 中图片外围所有 padding

删除所有这类写法：

```swift
.padding(.horizontal)
.padding(.top)
.padding(12)
.padding(16)
```

只允许：

* 图片撑满卡片左右
* 图片撑满卡片顶部
* 文本区自己有 padding

---

## 4. 删除深色脏底 / 厚重卡片感

删除：

* 深褐底
* 重暖灰底
* 明显 card shadow
* 明显边框 stroke

---

# 二、视觉 Tokens

```swift
enum TreasureTheme {
    static let pageBackground = Color(hex: "#F7F4EE")
    static let paperWhite = Color(hex: "#FCFBF8")
    static let textPrimary = Color(hex: "#3A342F")
    static let textSecondary = Color(hex: "#7A736C")
    static let sageDeep = Color(hex: "#5F786A")
    static let terracottaGlow = Color(hex: "#C97C5D").opacity(0.03)

    static let cardRadius: CGFloat = 24
    static let cardSpacing: CGFloat = 24
    static let contentPadding: CGFloat = 16
    static let imageAspect: CGFloat = 4.0 / 3.0
}
```

## 视觉要求

* 页面背景：燕麦白
* 文本区：纸白，不要死白
* 主文字：深碳灰
* 次级文字：暖灰
* 右上角按钮：深鼠尾草绿
* 星标卡：只允许极轻 terracotta 暖意

---

# 三、数据结构改造

把单图改为多图数组。

```swift
struct MemoryItem: Identifiable {
    let id: UUID
    let images: [String]          // 原来的 image 改成 images
    let title: String
    let timestampText: String     // 例如 "★ MAR 23 · 128天"
    let isStarred: Bool
}
```

### 约束

* `images.count >= 1`
* 单图时按普通图渲染
* 多图时走 Carousel
* 文本区结构不因单图/多图变化

---

# 四、页面结构

## 珍藏页整体结构

```swift
struct TreasureView: View {
    let items: [MemoryItem]

    var body: some View {
        ZStack {
            TreasureTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                GlobalTopNav(selected: .treasure)

                TreasureHeaderBar()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: TreasureTheme.cardSpacing) {
                        ForEach(items) { item in
                            MemoryCardView(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}
```

---

# 五、顶部结构

## 1. 只保留全局导航 + 极简加号按钮

不再增加任何二级筛选栏。

```swift
struct TreasureHeaderBar: View {
    var body: some View {
        HStack {
            Spacer()

            Button(action: {
                // open create flow
            }) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(TreasureTheme.sageDeep)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
```

## 要求

* 视觉上只有图标
* 点击区域 44x44
* 不加背景、不加阴影、不加描边

---

# 六、Memory Card 结构

## 核心结构

卡片只保留两层：

1. 图片区
2. 文本区

不要第三层、不要额外盒子。

```swift
struct MemoryCardView: View {
    let item: MemoryItem

    var body: some View {
        VStack(spacing: 0) {
            MemoryMediaView(images: item.images)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.timestampText)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(TreasureTheme.textSecondary)

                Text(item.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TreasureTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TreasureTheme.contentPadding)
            .padding(.vertical, TreasureTheme.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(item.isStarred ? TreasureTheme.paperWhite.overlay(TreasureTheme.terracottaGlow) : TreasureTheme.paperWhite)
        }
        .clipShape(TopRoundedCardShape(radius: TreasureTheme.cardRadius))
    }
}
```

---

# 七、卡片圆角规则

## 要求

* 整张卡片统一裁切
* 上圆角 24
* 下边保持直角
* 不要图片自己一个 radius，容器再一个 radius

```swift
struct TopRoundedCardShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: radius),
            control: CGPoint(x: rect.width, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}
```

---

# 八、单图模式

## 目标

* 图片 edge-to-edge
* 左右 0 padding
* 顶部 0 padding
* 高度稳定
* 大画幅

```swift
struct MemoryMediaView: View {
    let images: [String]

    var body: some View {
        if images.count == 1 {
            SingleMemoryImageView(imageName: images[0])
        } else {
            MemoryCarouselView(images: images)
        }
    }
}

struct SingleMemoryImageView: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(TreasureTheme.imageAspect, contentMode: .fill)
            .clipped()
    }
}
```

## 约束

* 不允许 `.cornerRadius()` 单独加在 Image 上
* 不允许给图片再包一层带 padding 的容器

---

# 九、多图 Carousel 模式

## 实现原则

* 只滑图片
* 文本区固定不动
* 高度锁定
* 不做 Grid
* 不做缩略图条

```swift
struct MemoryCarouselView: View {
    let images: [String]
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, name in
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(TreasureTheme.imageAspect, contentMode: .fill)
                        .clipped()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 36)
            .allowsHitTesting(false)
        }
    }
}
```

---

# 十、多图体验约束

## 1. 统一比例

默认统一使用：

```swift
.aspectRatio(4/3, contentMode: .fill)
```

### 不要这样做

* 每张图按原始比例展示
* 一张高一张矮
* 滑动时卡片高度变化

---

## 2. 指示器可见性

保留原生 dots，但必须加底部轻渐变托底。

### 渐变要求

* 只在多图时出现
* 高度：32–40pt
* 底部黑色透明度：0.10–0.15
* 向上过渡到 clear

---

## 3. 图片下缘保持直切

图片区上边受外层裁切约束为圆角，
图片区下边保持直线，不做下圆角。

---

# 十一、文本区样式

## 1. 时间戳

目标是“轻编目感”，不是标签感。

```swift
Text(item.timestampText)
    .font(.system(size: 12, weight: .medium))
    .tracking(0.4)
    .foregroundStyle(TreasureTheme.textSecondary)
```

### 要求

* 小字
* 更轻
* 不抢标题
* 不上图
* 不做胶囊底
* 不做图标底

---

## 2. 标题 / 文案

```swift
Text(item.title)
    .font(.system(size: 18, weight: .semibold))
    .foregroundStyle(TreasureTheme.textPrimary)
    .lineSpacing(2)
```

### 要求

* 比时间戳更有存在感
* 不做过粗黑体
* 不做过密字距
* 不做多行信息堆叠

---

# 十二、星标卡处理

## 原则

星标是“有一点暖意”，不是“明显特殊样式”。

### 允许

```swift
TreasureTheme.paperWhite.overlay(
    TreasureTheme.terracottaGlow
)
```

### 不允许

* 深褐底
* 暖色大面积块
* 明显描边
* 金色徽章
* 明显角标

---

# 十三、页面留白与节奏

## 列表间距

```swift
LazyVStack(spacing: 24)
```

### 要求

* 不能太密
* 每张卡之间要有“翻页停顿感”
* 不能像 feed 一样连续挤压

---

## 顶部留白

全局导航下不要马上贴第一张图。

建议：

```swift
.padding(.top, 12)
```

目标：

* 有呼吸
* 不空
* 不压迫

---

# 十四、明确禁止项

开发时不要做以下任何一种：

## 视觉禁止

* 不要图片外围 padding
* 不要重阴影
* 不要边框线
* 不要深脏底色
* 不要多层卡片套壳
* 不要九宫格
* 不要缩略图条
* 不要大面积品牌色铺底
* 不要玻璃态 / 毛玻璃
* 不要大号操作按钮

## 交互禁止

* 不要整个卡片左右滑
* 不要文本区跟着图片一起滑
* 不要吸顶筛选
* 不要再加二级 toolbar
* 不要在图上叠时间戳或标题

---

# 十五、验收标准

改完后，珍藏页必须同时满足这 8 条：

1. 第一眼看到的是照片，不是控件
2. 顶部全局导航下直接进入内容流
3. 不再出现“筛选器/频道切换”的感觉
4. 每张卡片像“图版 + 注解”，不是“内容组件”
5. 图片左右和顶部完全贴边
6. 多图滑动时高度不跳
7. 文本区始终安静稳定
8. 整页像成长册，不像相册工具页

---

# 十六、给 Codex 的直接执行指令

把下面这段直接发给 Codex 即可：

```text
请重构珍藏模块首页，只保留“全局导航 + 右上角 plus.viewfinder + 单列大画幅 Memory Card 列表”。

必须删除：
1. 顶部 Filter Bar / Segmented Control（全部记忆 / 星标时刻 / 时光信笺）
2. 右上角“+ 留住今天”白色胶囊按钮
3. Memory Card 图片外围所有 padding
4. 深色脏底、明显阴影、明显边框

Memory Card 新结构：
- 外层统一裁切，上圆角 24，下边直角
- 图片区 edge-to-edge，左右和顶部 0 padding
- 单图：普通 Image
- 多图：TabView + .page(indexDisplayMode: .always)
- 多图必须锁定 4:3 aspectRatio，.scaledToFill + .clipped，防止滑动跳高
- 仅图片区域左右滑动，文本区固定不动
- 多图底部加极轻黑到透明的渐变遮罩，提升白色 page dots 可见性

文本区：
- 图片正下方
- 纸白底（不要纯系统白，不要深底）
- padding 16
- 第一行时间戳（小、轻、灰）
- 第二行标题（更实、更清晰）
- 星标只允许极淡 terracotta 暖意，不允许明显特殊底色

整体页面：
- 背景为燕麦白
- 列表单列
- 卡片间距约 24
- 不要任何九宫格、缩略图条、吸顶筛选、重阴影、边框线、额外盒子嵌套
- 最终效果要像杂志级成长册翻阅页，而不是内容管理页