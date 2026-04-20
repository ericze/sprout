下面继续，给出 《初长 V1.0｜成长模块给 Codex 的实现说明文档》。 这份文档不是 PRD 复述，而是把研发实现边界、状态、事件、组件和禁止事项写死，方便直接开工。

初长 V1.0｜成长模块给 Codex 的实现说明文档
状态：已冻结 适用对象：Codex / iOS 开发 / 联调 范围：成长模块（身高 / 体重趋势） 原则：不假设，不自行扩展，不回退成传统医疗报告式页面

1. 模块目标
成长模块只做三件事：
	1	查看身高或体重的连续变化趋势
	2	在需要时核实某个点的精确数值
	3	新增一条身高或体重记录
它不是：
	•	百分位排名页
	•	医疗判断页
	•	发育预警页
	•	营养建议页

2. 已冻结的产品结论
以下为实现时不得更改的硬规则：
2.1 顶部切换器
	•	仅两项：身高、体重
	•	纯文本切换
	•	当前项有鼠尾草绿胶囊滑块
	•	热区外扩 16pt
2.2 元信息锚点
必须显示当前维度最近一次记录值与距今时间。
2.3 图表双层可见性
	•	默认层：温柔趋势，不显示 Y 轴数字
	•	精确层：长按 / scrubbing 时显示 Y 轴数字与 tooltip
2.4 参考区间命名
只能叫： 参考区间 不得出现：
	•	健康区
	•	正常区
	•	安全区
2.5 AI 解读卡
	•	默认展开
	•	可折叠
	•	只描述变化，不评价质量
2.6 录入方式
	•	主路径：刻度尺
	•	辅路径：手动输入
	•	打开时默认对齐上次记录值
2.7 参数冻结
	•	身高：0.1cm 精度，0.5cm selection，整数位 light
	•	体重：0.1kg 精度，0.1kg selection，0.5kg / 整公斤 light
2.8 精确层消失延迟
	•	松手后 400ms

3. 组件清单
Codex 需要至少拆出以下组件：
	•	GrowthModuleContainer
	•	GrowthZenToggle
	•	GrowthMetaInfoAnchor
	•	GrowthLifeLineChartCard
	•	GrowthChartReferenceRangeLayer
	•	GrowthChartLineLayer
	•	GrowthChartNodeLayer
	•	GrowthChartPrecisionOverlay
	•	GrowthChartTooltipBubble
	•	GrowthAIWhisperCard
	•	GrowthRecordEntryButton
	•	GrowthRecordSheet
	•	GrowthRulerPicker
	•	GrowthManualInputPanel
不允许把整页写成一个超长 View。

4. 页面状态模型
建议 Codex 按以下状态建模。
enum GrowthMetric {
    case height
    case weight
}

enum GrowthChartInteractionState {
    case idle
    case scrubbing
    case precisionVisible
    case precisionFading
}

enum GrowthAIState {
    case expanded
    case collapsed
}

enum GrowthSheetState {
    case closed
    case openHeight
    case openWeight
    case manualInputHeight
    case manualInputWeight
}

enum GrowthDataState {
    case loading
    case empty
    case hasData
    case error
}

5. 数据展示模型
不要让 View 直接消费原始记录模型。 建议先做一层 Growth 专用展示模型。
struct GrowthPoint: Identifiable {
    let id: UUID
    let date: Date
    let ageText: String
    let value: Double
}

struct GrowthMetaInfo {
    let latestValueText: String
    let relativeTimeText: String
}

struct GrowthTooltipData {
    let ageText: String
    let valueText: String
}

struct GrowthAIContent {
    let expandedText: String
    let collapsedText: String
}

6. 页面结构实现要求
页面从上到下固定为：
	1	GrowthZenToggle
	2	GrowthMetaInfoAnchor
	3	GrowthLifeLineChartCard
	4	GrowthAIWhisperCard
6.1 不允许
	•	在图表与 AI 卡之间再插入统计模块
	•	在默认视图里塞入对比排名
	•	在图表区域增加红黄绿警告标签

7. Zen Toggle 实现要求
7.1 默认选中
	•	读取上次停留维度
	•	若无缓存，则默认 height
7.2 点击行为
点击 身高 / 体重 时：
	1	更新当前 metric
	2	更新元信息
	3	更新图表数据
	4	更新 AI 卡内容
	5	播放轻微切换动画
7.3 注意
	•	切换维度时，如果当前处于 scrubbing，先结束 scrubbing，再切换
	•	不允许切换后残留上一维 tooltip

8. 元信息锚点实现要求
根据当前 metric 展示：
8.1 height
格式： 最新记录：75.2cm · 7天前
8.2 weight
格式： 最新记录：9.6kg · 7天前
8.3 empty
	•	height：还没有身高记录
	•	weight：还没有体重记录
8.4 刷新时机
以下事件后必须刷新：
	•	切换 metric
	•	新记录保存成功
	•	删除/撤销记录成功

9. 图表默认层实现要求
默认层只负责“温柔浏览”。
9.1 显示
	•	曲线
	•	X 轴标签
	•	参考区间
	•	极淡节点（可选）
9.2 不显示
	•	Y 轴数字
	•	Y 轴网格
	•	百分位线
	•	排名信息
	•	医疗区间文字
9.3 曲线
	•	可轻度平滑
	•	但必须保留真实转折
	•	数据点极少时不要画得像函数曲线

10. 精确层实现要求
精确层在长按或滑动时触发。
10.1 进入条件
	•	用户按住图表有效区域
	•	或按住后横向滑动
10.2 进入后效果
	•	图表背景轻微变暗
	•	Y 轴数字淡入
	•	垂直辅助线出现
	•	tooltip 吸附最近点
	•	当前点高亮
10.3 吸附规则
	•	必须吸附最近数据节点
	•	不能自由漂浮在手指位置
	•	不能在两个节点间抖动
10.4 Tooltip 文案
height
13个月 · 75.2cm
weight
13个月 · 9.6kg
10.5 离手
	•	保留 400ms
	•	淡出
	•	回到 idle

11. AI 卡实现要求
11.1 默认状态
expanded
11.2 折叠规则
点击右上角箭头：
	•	expanded -> collapsed
	•	collapsed -> expanded
11.3 文案来源
AI 文案或规则生成文案都可以，但最终必须符合约束：
允许
	•	描述记录间隔
	•	描述增减量
	•	描述节奏
禁止
	•	好 / 不好
	•	健康 / 不健康
	•	领先 / 落后
	•	偏瘦 / 偏胖
	•	营养建议
	•	医学建议
11.4 折叠态文案
固定为非常轻的单行摘要，例如： ✨ 记录了距上次 15 天的变化

12. +记录 按钮实现要求
12.1 点击行为
根据当前 metric：
	•	.height -> openHeight
	•	.weight -> openWeight
12.2 位置
图表卡片右上角
12.3 不允许
	•	漂浮到页面其他区域
	•	和底部全局胶囊合并
	•	使用醒目主按钮风格

13. Bottom Sheet 状态机
enum GrowthSheetState {
    case closed
    case openHeight
    case openWeight
    case manualInputHeight
    case manualInputWeight
}
13.1 打开时
	•	默认进入 ruler mode
	•	默认值 = 上次记录值
	•	若无记录，使用产品配置的起始默认值
13.2 手动输入切换
点 ⌨️ 手动输入 后：
	•	openHeight -> manualInputHeight
	•	openWeight -> manualInputWeight
13.3 返回刻度尺
从手动输入返回时：
	•	保留已输入数值
	•	刻度尺同步到当前数值

14. 刻度尺组件实现要求
14.1 共同规则
	•	横向滑动
	•	中央固定准星
	•	当前值始终可见
	•	不弹系统键盘作为主路径

15. 身高刻度尺配置
struct HeightRulerConfig {
    let precision: Double = 0.1
    let selectionStep: Double = 0.5
    let strongStep: Double = 1.0
    let unit: String = "cm"
}
15.1 触感
	•	到达 0.5cm 步进点：Haptic.selection
	•	到达整数位：Haptic.light
15.2 文本显示
格式： 75.2 cm

16. 体重刻度尺配置
struct WeightRulerConfig {
    let precision: Double = 0.1
    let selectionStep: Double = 0.1
    let strongStep: Double = 0.5
    let unit: String = "kg"
}
16.1 触感
	•	每 0.1kg：Haptic.selection
	•	每 0.5kg：Haptic.light
	•	整公斤位也应落入 strongStep 感知
16.2 文本显示
格式： 9.6 kg

17. 手动输入面板实现要求
17.1 类型
	•	数字输入
	•	单位固定，不可切换
17.2 输入校验
	•	非法值不可保存
	•	空值不可保存
	•	只允许当前 metric 的单位格式
17.3 不允许
	•	手动输入变成多字段表单
	•	额外加入备注、来源、排名等字段

18. 保存逻辑
点击 完成记录 后：
	1	校验当前数值
	2	写入对应 metric 新记录
	3	关闭 Bottom Sheet
	4	更新图表点集
	5	更新元信息
	6	更新 AI 卡
	7	曲线平滑延伸到新点
	8	若项目接入 Undo，则触发 Undo

19. 空数据态实现要求
19.1 图表
	•	显示空态占位，而不是空白白卡
	•	仍然保留 +记录
19.2 元信息
	•	显示“还没有身高记录”或“还没有体重记录”
19.3 AI 卡
建议显示轻量空态文案，而不是完全消失。 例如：
	•	✨ 记录第一条身高变化，生命线会从这里开始。
如果产品不希望空态文案过于拟人，可用更中性版本。

20. 开发禁止事项
Codex 在实现时不得：
	1	把参考区间写成“健康区”
	2	在默认图表里显示 Y 轴数字
	3	把精确层做成永久显示
	4	把 tooltip 做成自由漂移不吸附
	5	把 AI 卡写成评判式文案
	6	删除手动输入兜底入口
	7	忽略“默认从上次值开始”
	8	把身高和体重用完全同一套触感参数
	9	让曲线过度平滑
	10	把成长页改造成医疗报告样式

21. 代码结构建议
建议至少拆出：
	•	GrowthStore
	•	GrowthViewState
	•	GrowthAction
	•	GrowthFormatter
	•	GrowthRecordRepository
	•	GrowthChartInteractionController
21.1 Store
负责：
	•	页面当前维度
	•	图表交互状态
	•	Sheet 状态
	•	AI 卡状态
	•	数据加载与刷新
21.2 Formatter
负责：
	•	元信息文案
	•	tooltip 文案
	•	AI 卡文案
21.3 Repository
负责：
	•	查询 height / weight 记录
	•	新增记录
	•	删除 / 撤销记录

22. 验收 Checklist
结构
	•	页面包含切换器、元信息、图表、AI 卡
	•	页面整体不呈现医疗报告感
切换器
	•	身高/体重切换明确
	•	热区足够
	•	当前项清晰
图表默认层
	•	默认无 Y 轴数字
	•	默认无密集网格
	•	参考区间命名中性
	•	曲线不过度平滑
精确层
	•	长按/滑动可触发
	•	Y 轴数字淡入
	•	tooltip 吸附最近节点
	•	松手后延迟 400ms 消失
AI 卡
	•	默认展开
	•	可折叠
	•	文案只描述变化，不评价质量
录入
	•	+记录 可用
	•	默认从上次值开始
	•	刻度尺可录入
	•	手动输入可录入
	•	身高/体重参数分化生效
	•	保存后图表更新正确

23. 定版一句话
成长模块的实现底线是：默认温柔，但不能模糊；录入有手感，但不能牺牲效率。