# 日程详情独立窗口设计

## 背景

当前 Popover 只支持“选中日期后在下方显示日程列表”。用户可以看到当天有哪些日程，但点击某条日程时没有任何响应，也无法在不离开当前界面的情况下查看单个日程的详细信息。

本次需求调整为：点击日程后打开一个独立的 macOS 窗口展示详情，同时保持当前下拉菜单的宽度、布局和浏览节奏不变。

## 需求分析

### 用户目标

- 在菜单栏下拉中浏览当天日程时，点击某条会议或日程能立即看到详情
- 详情展示为独立的 macOS 窗口，而不是挤压当前 Popover
- 继续保留下拉中的月历、日期切换和日程列表，不打断原有浏览流程

### 约束

- 当前应用主壳基于 `NSStatusItem + NSPopover + SwiftUI`
- 现有交互状态主要在 `RootPopoverView -> CalendarPopoverView -> EventListView`
- 日程数据来自 `EventKit`，列表中还可能混入提醒事项，提醒事项不应误导成可查看“日程详情”
- 工程文件由 [`tools/generate_xcodeproj.rb`](/Users/yelog/workspace/swift/calendar-pro/tools/generate_xcodeproj.rb) 生成，新增 Swift 文件后需要重生成 `xcodeproj`
- 工作区已有未提交改动，实施时不能误改无关文件

### 成功标准

- 点击列表中的日历日程后，弹出一个独立的 macOS 详情窗口
- 当前 Popover 宽度和主体布局保持不变
- 切换到另一条日程时，复用同一个详情窗口并刷新内容
- 点击同一条已选日程、切换日期、权限关闭、筛选变化或目标日程刷新失效时，详情窗口自动关闭
- 关闭 Popover 时，详情窗口同步关闭
- 提醒事项条目不展示“可打开详情”的误导性交互

## 方案对比

### 方案 A：在同一个 Popover 内扩展双栏

- 做法：保留当前 `NSPopover`，在左侧插入详情栏并整体增宽
- 优点：实现简单，数据流短
- 缺点：直接违背“不要影响当前下拉布局”的要求

### 方案 B：新增独立 `NSPanel` 作为详情窗口

- 做法：点击日程时创建或复用一个 `NSPanel`，锚定在 Popover 左侧；空间不足时回退到右侧
- 优点：是真正独立的 macOS 窗口，不影响 Popover 尺寸；适合菜单栏应用的临时辅助信息
- 缺点：需要处理窗口定位、关闭同步、窗口复用与屏幕边界

### 方案 C：新增普通 `NSWindow` 作为详情窗口

- 做法：点击日程时弹出标准窗口承载详情
- 优点：实现直观
- 缺点：窗口行为过重，更像主内容窗口，容易抢焦点，也不如 `NSPanel` 适合作为临时附属面板

## 推荐方案

采用方案 B：独立 `NSPanel`。

这是唯一同时满足“独立窗口”和“不改变当前 Popover 布局”的方案。相较普通 `NSWindow`，`NSPanel` 更适合菜单栏应用的辅助详情展示，窗口可以复用、浮于当前上下文附近，并在主 Popover 关闭时一并回收。

## 架构设计

### 组件职责

- `RootPopoverView`
  - 继续管理 `selectedDate`、已加载列表和选中日程标识
  - 负责判断当前点击是“打开详情”还是“关闭详情”
  - 在日期切换、权限变化、筛选变化、事件刷新失效时发出关闭详情窗口的意图

- `CalendarPopoverView`
  - 保持当前单栏 Popover 布局
  - 仅负责列表展示、高亮选中项和把点击事件向上抛出
  - 不再承载任何内嵌详情面板或扩宽逻辑

- `EventListView` / `EventCardView`
  - 仅对 `.event(EKEvent)` 条目提供点击能力
  - `.reminder(EKReminder)` 保持普通列表项样式，不显示详情箭头

- `PopoverController`
  - 持有一个详情窗口协调器
  - 把 SwiftUI 侧“打开 / 关闭详情”的意图桥接到 AppKit 层
  - 在 Popover 关闭时同步关闭详情窗口

- `EventDetailWindowController`
  - 持有并复用 `NSPanel`
  - 使用 `NSHostingController` 承载详情 SwiftUI 视图
  - 负责定位、显示、更新内容和处理关闭回调

### 数据流

1. 用户在 Popover 中点击某条日历日程
2. `EventListView` 把对应 `EKEvent` 回传给 `RootPopoverView`
3. `RootPopoverView` 更新 `selectedEventIdentifier`
4. `RootPopoverView` 调用外部闭包，请求 `PopoverController` 展示详情窗口
5. `PopoverController` 将 `EKEvent` 转交给 `EventDetailWindowController`
6. `EventDetailWindowController` 更新面板内容并将面板定位到 Popover 左侧
7. 若窗口被关闭，关闭回调反向通知 `RootPopoverView` 清空选中态

### 状态设计

- `selectedDate`: 当前选中的日期
- `selectedEventIdentifier`: 当前选中的日历事件 ID，仅用于列表高亮和详情窗口开关
- `itemsForSelectedDate`: 当前日期的混合列表，包含日历事件和提醒事项

规则：

- 只有 `.event` 可以写入 `selectedEventIdentifier`
- 重新加载列表后，如果已选事件不再存在，立即清空 `selectedEventIdentifier` 并关闭详情窗口
- 关闭详情窗口时必须同步清空高亮，避免“列表仍选中但窗口已消失”的不一致状态

## 窗口与交互设计

### 窗口形态

- 使用单实例复用的 `NSPanel`
- 面板内容使用 SwiftUI 详情视图承载
- 面板宽度固定，高度随内容自适应，但不低于基础可读高度
- 面板关闭后不释放对象，仅清空内容并隐藏，便于下次快速复用

### 定位规则

- 默认显示在 Popover 左侧，和 Popover 顶部对齐
- 与 Popover 保持 `8-12pt` 水平间距
- 若左侧空间不足，则回退到右侧
- 若上下超出当前屏幕可见区域，则对 Y 轴做夹取
- 若暂时拿不到 Popover 所在窗口，回退到当前活动屏幕的可见区域居中显示

### 交互规则

- 点击未选中的日历日程：打开或更新详情窗口
- 点击当前已选日历日程：关闭详情窗口
- 点击提醒事项：不打开详情窗口
- 切换日期：关闭详情窗口并清空当前选中日程
- 关闭按钮或窗口系统关闭：关闭详情窗口并清空当前选中日程
- 关闭 Popover：同步关闭详情窗口

## 详情内容设计

详情窗口内容沿用现有 `EventDetailPanelView` 的信息结构，但从 `CalendarPopoverView` 中抽离为独立复用视图：

- 顶部：标题、日历颜色标识、关闭按钮
- 概览区：日期范围、时间摘要
- 元信息区：所属日历、地点、链接
- 备注区：备注文本
- 空状态：无附加信息时展示“暂无更多详情”

## 错误处理

- 若事件对象在展示前失效，关闭窗口并清空高亮
- 若事件筛选变化导致事件不再可见，关闭窗口
- 若权限被撤销，清空当前列表与选中状态，并关闭窗口
- 若提醒事项存在但事件权限不可用，不展示详情交互

## 测试策略

- 单元测试：验证 `CalendarPopoverViewModel` 的选择/切换/清空行为
- 单元测试：为窗口定位计算增加纯函数测试，覆盖左侧优先、右侧回退、屏幕边界夹取
- 单元测试：为 `PopoverController` 与详情窗口 presenter 的联动补充测试，覆盖显示、关闭、Popover 关闭时同步收口
- 手动验证：点击事件打开、切换事件更新、切换日期关闭、关闭 Popover 收口、提醒事项不可点

## 实施范围

- 修改 `CalendarPro/Views/RootPopoverView.swift`
- 修改 `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- 修改 `CalendarPro/Views/Popover/EventListView.swift`
- 修改 `CalendarPro/Views/Popover/EventCardView.swift`
- 修改 `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- 新增详情窗口 SwiftUI 视图
- 新增 `NSPanel` 详情窗口控制器与定位逻辑
- 修改 `CalendarPro/App/PopoverController.swift`
- 为新增文件重生成 `CalendarPro.xcodeproj/project.pbxproj`
