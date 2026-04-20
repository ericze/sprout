下面是压缩后的 《成长模块｜Codex 工程任务清单版》。 只保留实现必需信息，方便直接拆任务。

初长 V1.0｜成长模块 Codex 工程任务清单
1. 模块目标
实现成长模块的 3 个核心能力：
	1	查看身高 / 体重趋势
	2	长按/滑动图表核实精确值
	3	新增身高 / 体重记录

2. 必做页面结构
按顺序实现以下 4 块：
	1	GrowthZenToggle
	2	GrowthMetaInfoAnchor
	3	GrowthLifeLineChartCard
	4	GrowthAIWhisperCard

3. 必做状态
实现以下状态：
enum GrowthMetric { case height, weight }
enum GrowthChartInteractionState { case idle, scrubbing, precisionVisible, precisionFading }
enum GrowthAIState { case expanded, collapsed }
enum GrowthSheetState {
    case closed
    case openHeight
    case openWeight
    case manualInputHeight
    case manualInputWeight
}

4. 必做组件
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

5. Zen Toggle 任务
T1
实现 身高 | 体重 纯文本切换器
要求：
	•	当前项字重更高
	•	绿色胶囊滑块跟随
	•	热区外扩 16pt
T2
点击切换后同步更新：
	•	当前 metric
	•	元信息
	•	图表数据
	•	AI 卡文案

6. 元信息锚点任务
T3
实现最新记录锚点
格式：
	•	身高：最新记录：75.2cm · 7天前
	•	体重：最新记录：9.6kg · 7天前
T4
实现无数据态：
	•	还没有身高记录
	•	还没有体重记录

7. 图表默认层任务
T5
实现默认图表卡片
要求：
	•	白底大圆角
	•	默认不显示 Y 轴数字
	•	默认不显示网格
	•	显示 X 轴时间标签
	•	显示深碳灰主曲线
T6
实现 参考区间 图层
要求：
	•	极淡浅绿色面状填充
	•	命名只能是 参考区间
	•	禁止写成“健康区”
T7
实现真实转折曲线
要求：
	•	允许轻微平滑
	•	禁止过度 smoothing

8. 图表精确层任务
T8
实现长按 / scrubbing 触发精确层
进入后：
	•	图表背景轻微变暗
	•	Y 轴数字淡入
	•	垂直辅助线出现
	•	tooltip 吸附最近点
T9
实现 tooltip 吸附逻辑
格式：
	•	身高：13个月 · 75.2cm
	•	体重：13个月 · 9.6kg
要求：
	•	只能吸附最近节点
	•	不可自由漂浮
T10
实现离手延迟消失
要求：
	•	tooltip 与 Y 轴保留 400ms
	•	之后淡出

9. AI 卡任务
T11
实现 AI 卡默认展开 + 可折叠
折叠态示例： ✨ 记录了距上次 15 天的变化
T12
实现文案约束
允许：
	•	间隔天数
	•	增减量
	•	前进节奏
禁止：
	•	健康判断
	•	好坏评价
	•	同龄比较
	•	医学建议

10. +记录 入口任务
T13
在图表卡右上角实现 + 记录 按钮
点击后：
	•	当前是身高 -> openHeight
	•	当前是体重 -> openWeight

11. Bottom Sheet 任务
T14
实现 GrowthRecordSheet
默认：
	•	ruler mode
	•	当前值吸附到上次记录值
T15
实现 ⌨️ 手动输入 入口
点击后切换：
	•	openHeight -> manualInputHeight
	•	openWeight -> manualInputWeight
返回刻度尺时：
	•	保留当前输入值

12. 刻度尺任务
T16
实现通用 GrowthRulerPicker
要求：
	•	横向滑动
	•	中央红色准星
	•	当前值始终可见
T17
实现身高配置
precision = 0.1
selectionStep = 0.5
strongStep = 1.0
unit = "cm"
触感：
	•	0.5cm -> selection
	•	整数位 -> light
T18
实现体重配置
precision = 0.1
selectionStep = 0.1
strongStep = 0.5
unit = "kg"
触感：
	•	0.1kg -> selection
	•	0.5kg / 整公斤 -> light

13. 手动输入任务
T19
实现 GrowthManualInputPanel
要求：
	•	仅数字输入
	•	单位固定
	•	非法值不可保存
	•	不增加备注等额外字段

14. 保存链路任务
T20
实现 完成记录
保存后：
	1	校验数值
	2	写入记录
	3	关闭 Sheet
	4	更新图表
	5	更新元信息
	6	更新 AI 卡
	7	曲线平滑延伸

15. 无数据态任务
T21
实现无数据空态
要求：
	•	图表不是白板
	•	+记录 可用
	•	AI 卡可显示轻量空态文案或按最终产品决定隐藏

16. Store / Repository 任务
T22
实现 GrowthStore
至少管理：
	•	当前 metric
	•	图表交互状态
	•	AI 卡状态
	•	Sheet 状态
	•	数据刷新
T23
实现 GrowthRecordRepository
能力：
	•	查询身高记录
	•	查询体重记录
	•	新增记录
	•	删除/撤销记录
T24
实现 GrowthFormatter
负责：
	•	元信息文案
	•	tooltip 文案
	•	AI 卡文案

17. 禁止事项
Codex 不得：
	1	默认显示 Y 轴数字
	2	把 参考区间 写成健康区
	3	把图表做成医疗报告样式
	4	删掉手动输入兜底
	5	忽略“默认从上次值开始”
	6	用同一套参数硬套身高和体重
	7	把 AI 卡写成判断式文案
	8	让 tooltip 自由漂浮不吸附
	9	让松手后 tooltip 立刻消失
	10	过度平滑曲线

18. 验收 Checklist
	•	可切换身高 / 体重
	•	元信息正确显示
	•	默认图表不显示 Y 轴数字
	•	长按/滑动可出现精确层
	•	tooltip 吸附最近点
	•	离手后 400ms 淡出
	•	AI 卡默认展开且可折叠
	•	AI 卡文案不越界
	•	+记录 可打开对应 Sheet
	•	默认停在上次值
	•	刻度尺可录入
	•	手动输入可录入
	•	身高 / 体重触感参数不同
	•	保存后图表 / 元信息 / AI 卡同步更新

如果你要，我下一条可以继续把首页 PRD、底部胶囊文档、成长模块文档，整理成一份 统一的 V1 产品执行总纲。
