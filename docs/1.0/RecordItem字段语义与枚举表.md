下面继续，直接给出 **《RecordItem 字段语义与枚举表》V1**。
这份文档的目标只有一个：**把首页和 V1 里会用到的数据语义一次性定清，避免后面“同一个字段每个人理解都不一样”。**

---

# 初长 V1.0｜RecordItem 字段语义与枚举表

## 一、文档目的

这份文档用于明确：

1. `RecordItem` 每个字段在 V1 中的合法含义
2. 哪些字段是必填，哪些是可空
3. 不同 `type` 下各字段如何使用
4. 哪些值是允许的，哪些值 V1 禁止出现

这份文档应被视为：

**首页、记录页、周报、统计页的数据真源之一**

---

# 二、核心模型（现有定义）

```swift id="6l2tl4"
@Model
final class RecordItem {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var type: String // milk, diaper, sleep, food, growth, milestone, photo
    var value: Double? // e.g., 120ml, 75cm
    var subType: String? // e.g., "Breast milk", "Pee", "Left Side"
    var imageURL: String? // Local sandbox path
    var aiSummary: String? // AI generated poetic description
    var tags: [String]? // AI extracted ingredients like ["Pumpkin", "Cod"]
    var note: String?
}
```

---

# 三、全局字段语义定义

## 3.1 `id`

### 类型

`UUID`

### 语义

一条记录的全局唯一标识。

### 规则

* 必填
* 不可变
* 仅用于数据标识与操作回滚
* 不用于任何展示文案

---

## 3.2 `timestamp`

### 类型

`Date`

### 语义

**该记录所代表事件的发生时间。**

### 统一原则

首页时间线和历史排序都以 `timestamp` 为主。

### V1 规则

* 必填
* 所有记录必须有 `timestamp`
* 不同 `type` 下都表示“事件开始/发生的时刻”

### 各类型解释

* `milk`：记录奶量时的保存时刻
* `diaper`：记录尿布事件时的保存时刻
* `sleep`：睡眠开始时间
* `food`：完成本次辅食记录的时刻

### 为什么这样定义

统一让 `timestamp` 表示“事件起点/发生点”，比混用“开始时间/结束时间/保存时间”更稳定。

---

## 3.3 `type`

### 类型

`String`

### 语义

记录的大类。

### V1 合法值

* `milk`
* `diaper`
* `sleep`
* `food`

### 模型中预留但首页 V1 不消费的值

* `growth`
* `milestone`
* `photo`

### V1 规则

* 必填
* 必须属于合法集合
* 首页首版只处理 4 个高频类型

### 建议

虽然模型里是 `String`，但在业务层必须映射为枚举，禁止在 View 层直接使用裸字符串判断。

---

## 3.4 `value`

### 类型

`Double?`

### 语义

一个**数值型载荷字段**，只在需要数值表达时使用。

### V1 使用规则

并非所有类型都使用 `value`。

### 各类型定义

* `milk`：奶量数值，单位固定为 `ml`
* `sleep`：睡眠总时长，单位必须全项目统一
* `diaper`：不用
* `food`：不用

### V1 建议统一

#### milk

* `value` 表示 ml
* 例如：120 表示 120ml

#### sleep

必须二选一并冻结：

* 方案 A：以分钟保存
* 方案 B：以秒保存

从未来扩展和精度角度，我建议：
**sleep.value = 秒数**
展示时再格式化成“1小时42分”。

### 禁止事项

* `food.value` 不得用于摄入量
* `diaper.value` 不得用于大小/等级
* 不允许同一个 `type` 下临时换单位

---

## 3.5 `subType`

### 类型

`String?`

### 语义

记录大类下的**轻量子分类字段**。

### V1 使用规则

只在确有必要时使用，不能把它变成杂物箱。

### 各类型定义

* `milk`：V1 暂不强制使用
* `diaper`：用于尿布类型
* `sleep`：V1 不用
* `food`：V1 不用

### 当前 V1 明确值

#### diaper.subType 合法值

* `pee`
* `poop`
* `both`

### 预留但不启用

#### milk.subType 预留值（V1 暂不使用）

* `formula`
* `breastmilk`
* `mixed`

注意：
这些值现在**只允许作为未来扩展预留认知**，V1 首页与交互不依赖这些值。

### 禁止事项

* 不允许写自由文本作为 `subType`
* 不允许把情绪、表现、医学判断塞进 `subType`

---

## 3.6 `imageURL`

### 类型

`String?`

### 语义

记录关联图片在本地设备上的可访问路径。

### V1 使用规则

* 仅 `food` 记录使用
* 其他类型默认不使用

### 各类型定义

* `food.imageURL`：用户上传/拍摄照片在本地沙盒的路径
* 其余类型：`nil`

### 说明

这个字段当前语义是：
**本地图片引用**
不是云端 URL，不是网络图片地址。

### 风险提醒

若未来要做跨设备图片同步，这个字段不能单独承担完整同步语义，只能承担本地缓存引用语义。

### V1 禁止事项

* 不允许存远程 URL 伪装成本地路径
* 不允许把 imageURL 当成多图数组入口
* 一条 food 记录 V1 只允许 0 或 1 张图

---

## 3.7 `aiSummary`

### 类型

`String?`

### 语义

由 AI 生成的附加摘要文本。

### V1 使用规则

首页首版默认不接 AI，因此：

* `milk.aiSummary = nil`
* `diaper.aiSummary = nil`
* `sleep.aiSummary = nil`
* `food.aiSummary = nil`

### 未来用途

后续若接 AI，可用于：

* 辅食日记温柔摘要
* 周报聚合文案片段

### V1 禁止事项

* 首页展示逻辑不得依赖 `aiSummary`
* 非 AI 版本不得伪造填充 `aiSummary`

---

## 3.8 `tags`

### 类型

`[String]?`

### 语义

一个轻量结构化标签数组。

### V1 使用规则

当前只在 `food` 中启用。

### 各类型定义

* `food.tags`：本次辅食中涉及的食材或客观标签
* 其余类型：`nil`

### `food.tags` 合法内容类型

#### A. 食材类

例如：

* 南瓜
* 米粉
* 香蕉
* 鸡蛋
* 牛油果
* 面条

#### B. 客观状态类（非常少量）

例如：

* 第一次尝试

### 原则

标签只表达：

* 吃了什么
* 是否首次尝试

标签不表达：

* 喜欢/不喜欢
* 吃得多不多
* 表现好不好
* 医学状态
* 焦虑导向评价

### V1 禁止标签示例

* 光盘行动
* 没胃口
* 挑食
* 过敏风险
* 吃得真棒
* 排敏成功

---

## 3.9 `note`

### 类型

`String?`

### 语义

用户主动填写的一句自然语言备注。

### V1 使用规则

当前只在 `food` 中启用为主路径备注。

### 各类型定义

* `food.note`：用户写的一句话小插曲
* `milk.note`：V1 默认不用
* `diaper.note`：V1 默认不用
* `sleep.note`：V1 默认不用

### `food.note` 的推荐语义

记录这一顿饭的小故事、小细节，而不是营养报告。

例如：

* 今天一直把勺子往地上丢
* 第一次试牛油果
* 很爱南瓜泥
* 吃两口就开始研究碗

### V1 禁止事项

* 不要求标准食材词表
* 不要求情绪评价模板
* 不要求医学说明
* 不将 `note` 当成结构化统计字段

---

# 四、按类型展开的字段矩阵

---

## 4.1 milk

### 记录语义

一次奶量记录。

### 必填字段

* `id`
* `timestamp`
* `type = "milk"`
* `value`

### 可空字段

* `subType`
* `imageURL`
* `aiSummary`
* `tags`
* `note`

### V1 字段要求

```text
type      = "milk"
value     = 奶量ml数值
subType   = nil
imageURL  = nil
aiSummary = nil
tags      = nil
note      = nil
```

### 首页展示语义

* 主文案：`120ml`

### V1 禁止承载

* 速度
* 温度
* 剩余量
* 喂养情绪
* 过度分类

---

## 4.2 diaper

### 记录语义

一次尿布事件记录。

### 必填字段

* `id`
* `timestamp`
* `type = "diaper"`
* `subType`

### 可空字段

* `value`
* `imageURL`
* `aiSummary`
* `tags`
* `note`

### V1 字段要求

```text
type      = "diaper"
value     = nil
subType   = "pee" | "poop" | "both"
imageURL  = nil
aiSummary = nil
tags      = nil
note      = nil
```

### 首页展示语义

* `pee` → `尿布：小便`
* `poop` → `尿布：大便`
* `both` → `尿布：都有`

### V1 禁止承载

* 颜色
* 稠度
* 健康判定
* 异常预警
* 详细备注

---

## 4.3 sleep

### 记录语义

一次完整结束的睡眠记录。

### 必填字段

* `id`
* `timestamp`
* `type = "sleep"`
* `value`

### 可空字段

* `subType`
* `imageURL`
* `aiSummary`
* `tags`
* `note`

### V1 字段要求

```text
type      = "sleep"
timestamp = 睡眠开始时间
value     = 睡眠总时长（建议秒）
subType   = nil
imageURL  = nil
aiSummary = nil
tags      = nil
note      = nil
```

### 首页展示语义

* `睡了 1小时42分`

### 关键说明

进行中的睡眠状态**不属于 `RecordItem`**。
只有结束后才落成一条 `sleep` 记录。

### V1 禁止承载

* 睡眠质量评分
* 入睡方式
* 情绪判断
* 医学分析

---

## 4.4 food

### 记录语义

一次辅食 / 进食事件记录。

### 必填字段

* `id`
* `timestamp`
* `type = "food"`

### 至少满足其一

以下三项至少有一项非空：

* `tags`
* `note`
* `imageURL`

否则这条记录不合法。

### 可空字段

* `value`
* `subType`
* `aiSummary`

### V1 字段要求

```text
type      = "food"
value     = nil
subType   = nil
imageURL  = 本地路径或 nil
aiSummary = nil
tags      = 食材/客观标签数组或 nil
note      = 一句话备注或 nil
```

### 首页展示语义

#### 无图

* 吃了南瓜、米粉
* 吃了南瓜、米粉 / 今天一直在扔勺子
* 今天一直把勺子往地上丢

#### 有图

* 使用图片卡
* 文案按上述规则生成

### V1 禁止承载

* 摄入量
* 克数
* 喜好打分
* 表现排名
* AI 结论
* 过敏判断

---

# 五、V1 合法值表

## 5.1 type 合法值表

```swift id="vf2wzv"
enum RecordTypeRaw: String {
    case milk
    case diaper
    case sleep
    case food
}
```

首页 V1 仅消费以上四个。

---

## 5.2 diaper.subType 合法值表

```swift id="f9x6tb"
enum DiaperSubtypeRaw: String {
    case pee
    case poop
    case both
}
```

---

## 5.3 food.tags 推荐值范围

V1 不强制做成硬编码全字典，但需要有“推荐可选集”。

### 食材类推荐值

* 米粉
* 南瓜
* 香蕉
* 鸡蛋
* 牛油果
* 面条
* 豆腐
* 胡萝卜
* 土豆
* 西兰花

### 状态类推荐值

* 第一次尝试

### 原则

* 食材类为主
* 状态类极少
* 标签必须是客观描述，不是评价

---

# 六、首页与表单校验规则

---

## 6.1 milk 校验

合法条件：

* `type == "milk"`
* `value != nil`
* `value > 0`

不合法示例：

* `value = nil`
* `value <= 0`

---

## 6.2 diaper 校验

合法条件：

* `type == "diaper"`
* `subType in {pee, poop, both}`

不合法示例：

* `subType = nil`
* `subType = "wet"`

---

## 6.3 sleep 校验

合法条件：

* `type == "sleep"`
* `timestamp` 存在
* `value != nil`
* `value > 0`

不合法示例：

* duration 为 0
* duration 为负数

---

## 6.4 food 校验

合法条件：

* `type == "food"`
* 至少满足一项：

  * `tags` 非空
  * `note` 非空
  * `imageURL` 非空

不合法示例：

* 三项全空

---

# 七、首页文案生成表

---

## 7.1 milk

输入：

```text
type = milk
value = 120
```

输出：

```text
title = "120ml"
subtitle = nil
```

---

## 7.2 diaper

输入：

```text
type = diaper
subType = pee
```

输出：

```text
title = "尿布：小便"
subtitle = nil
```

---

## 7.3 sleep

输入：

```text
type = sleep
value = 6120秒
timestamp = 09:10
```

输出：

```text
title = "睡了 1小时42分"
subtitle = nil
```

---

## 7.4 food：只有 tags

输入：

```text
type = food
tags = ["南瓜", "米粉"]
note = nil
imageURL = nil
```

输出：

```text
title = "吃了南瓜、米粉"
subtitle = nil
style = standard
```

---

## 7.5 food：只有 note

输入：

```text
note = "今天一直把勺子往地上丢"
```

输出：

```text
title = "今天一直把勺子往地上丢"
subtitle = nil
style = standard
```

---

## 7.6 food：tags + note

输入：

```text
tags = ["南瓜", "米粉"]
note = "今天一直把勺子往地上丢"
```

输出：

```text
title = "吃了南瓜、米粉"
subtitle = "今天一直把勺子往地上丢"
style = standard
```

---

## 7.7 food：带图

输入：

```text
tags = ["南瓜", "米粉"]
note = "今天一直把勺子往地上丢"
imageURL = "/local/path/xxx.jpg"
```

输出：

```text
style = foodPhoto
title = "吃了南瓜、米粉"
subtitle = "今天一直把勺子往地上丢"
imagePath = "/local/path/xxx.jpg"
```

---

# 八、V1 不允许的字段滥用

为了避免后续“哪里都能塞点东西”，下面这些行为一律禁止：

## 禁止 1

把不同单位混塞进 `value`

* milk 用 ml
* sleep 用秒或分钟
* food 不得偷偷拿 value 塞克数

## 禁止 2

把自由文本塞进 `subType`
`subType` 只能承载预定义轻枚举，不是任意备注区。

## 禁止 3

把主观判断塞进 `tags`
例如：

* 吃得真好
* 今天挑食
* 没胃口

## 禁止 4

把 AI 结果伪装成人工 note
`aiSummary` 和 `note` 的来源必须语义分明。

## 禁止 5

让首页依赖未来字段
V1 首页只能基于目前冻结的字段工作，不预埋“等以后有 AI / 云同步 / 多图再说”的展示依赖。

---

# 九、建议补充的业务层枚举

虽然 SwiftData 模型里先保留 `String`，但业务层必须包一层强类型。

## 9.1 RecordType

```swift id="o6v9vd"
enum RecordType: String {
    case milk
    case diaper
    case sleep
    case food
}
```

## 9.2 DiaperSubtype

```swift id="vyrqso"
enum DiaperSubtype: String {
    case pee
    case poop
    case both
}
```

## 9.3 FoodTag（建议值域，不一定首版强枚举）

如果未来要做精选标签库，可以再抽象。
V1 可先保留字符串数组，但由产品给推荐列表。

---

# 十、建议的校验器

为了避免 View / Store / Repository 各写一份判断，建议增加统一校验器：

```swift id="m2n9mc"
enum RecordValidator {
    static func validate(_ item: RecordItem) -> Bool
}
```

它负责：

* 检查 type 合法性
* 检查不同 type 的必填字段
* 防止创建空 food 记录
* 防止非法 diaper subtype

---

# 十一、V1 最终冻结建议

如果你现在就要把首页与记录系统冻结到可以开工的程度，我建议先把下面 4 条当成硬规则：

### 规则 1

`sleep.timestamp = 开始时间`

### 规则 2

`sleep.value = 秒数`

### 规则 3

`food` 至少满足 `tags / note / imageURL` 之一

### 规则 4

`diaper.subType` 只允许 `pee / poop / both`

这四条一旦不再摇摆，首页开发就能稳定推进。

---

# 十二、接下来最值得继续写的文档

你现在手里已经有：

* 首页完整设计
* 首页交互规格
* 四个 Bottom Sheet 详细规格
* 首页数据映射与状态机稿
* RecordItem 字段语义与枚举表

下一步最适合写两份之一：

1. **《首页低保真线框说明稿》**
   把每个区域的布局和信息层级真正画成页面说明

2. **《开发任务拆解 Backlog》**
   直接把首页拆成工程任务、优先级、依赖关系和验收标准

我建议下一条直接做 **《开发任务拆解 Backlog》**，这样这套方案就能直接进入排期。
