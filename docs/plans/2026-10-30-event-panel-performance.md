# 日程面板性能优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 消除日程详情和编辑器的窗口尺寸反馈循环，恢复切换、失焦关闭与日期选择的即时响应，并保留跨天日期和小屏幕滚动行为。

**Architecture:** 视图报告固定宽度下的内容自然高度，滚动视口独立受限；控制器单独管理窗口尺寸，合并最新测量并丢弃旧页面回调。随后局部减少重复文本检测和日期格式化，不改变 EventKit 持久化契约。

**Tech Stack:** SwiftUI、AppKit `NSPanel` / `NSHostingController`、EventKit、XCTest，macOS 14+。

---

## 实施目标、阶段和交付范围

状态：2026-10-30 已完成任务 1～7 的实施及自动化验证。任务 8 的真实应用交互与 Instruments 性能采样尚未执行；任务 10 按计划等待采样证据。

本次必做范围为任务 1～9：修复窗口尺寸反馈循环、隔离旧页面回调、消除重复备注排版和日期格式化、复用会议匹配规则，并完成实际交互验证。任务 10 是根据采样启动的后续工作，不阻塞已验证的主缺陷修复交付。

| 阶段 | 任务 | 完成标志 |
| --- | --- | --- |
| A：修复尺寸循环 | 1～4 | 真实视图装载到测试面板后能稳定，旧页面不会改变新页面，小窗口保持可操作 |
| B：减少重复工作 | 5～7 | 相同文字不重复替换富文本，日期和正则初始化不再随重绘成倍增加 |
| C：验证用户路径 | 8～9 | 应用内测量切换、关闭、编辑和日期弹层；完成日期语义、提醒事项和窗口回归 |
| D：有采样依据时继续 | 10 | 仅针对仍占用主线程的 EventKit 查询去重或调整隔离域 |

任务 2、3、4 共同构成尺寸修复，按顺序集成，不把仅改变视图测量而仍受旧控制器反馈影响的版本作为阶段 A 完成。任务 5～7 在阶段 A 稳定后实施，使新增失败更容易定位。

## 必须维持的行为契约

| 契约 | 验收要求 |
| --- | --- |
| 全天和跨天日期 | 继续使用 EventKit 半开区间；展示结束是最后覆盖日；不得用 86,400 秒替代日历日运算 |
| 未修改时间的保存 | 原始 `startDate`、`endDate`、`isAllDay` 精确保留；只改标题不会缩短多日事件 |
| 面板布局 | 宽度、顶部对齐及左右放置沿用现有规则；标题和操作按钮位于滚动区外 |
| 高度来源 | 自然内容高度只依赖内容及可用宽度；滚动视口和窗口当前高度不得回流为自然内容高度 |
| 尺寸管理 | 日程详情和编辑宿主只由控制器决定窗口尺寸；同轮消费最新有效测量 |
| 生命周期 | 已关闭或被替换页面的测量不能操作当前面板；同一 `NSPanel` 被复用也必须区分页面 |
| 动态内容 | 备注展开/折叠、校验错误、会议操作有无、参与状态变更仍能正确改变布局 |
| 备注 | 可选取、可复制、链接可打开；系统颜色在浅色/深色模式下正常 |
| 共用路径 | 提醒事项详情沿用其尺寸策略；提醒事项新建/编辑使用修复后的 composer 并正常工作 |
| 主线程 | SwiftUI/AppKit 窗口与文字视图操作继续留在主线程；不把现有 EventKit 对象直接放入 detached task |

正式实施优先编辑现有 Swift 和测试文件，不增加依赖，不引入通用窗口框架。若实际需要新增文件，按仓库规则执行工程注册并保留已有构建配置。

## 执行范围与约定

- 实施及验证记录追加在本文末尾；诊断和隔离探针结果见 [分析设计](2026-10-30-event-panel-performance-design.md)。
- 模板引用的 `executing-plans` 不可用时直接按步骤实施，不自动安装或委派 agent。
- 不自动 commit、push、发布或修改用户日历。只使用未保存的内存事件及独立测试设置。
- 优先使用现有测试文件，不为重复布局声明编写实现同构测试；本次关键回归必须实际构建 SwiftUI/AppKit 宿主并证明尺寸会收敛。
- 初版不迁移 EventKit 服务的并发模型；相关后续工作以性能采样为依据。

实施前后各保留一份实际应用采样，记录系统版本、Debug/Release 配置、是否连接调试器及场景。性能对比必须在相同配置下进行；前面的隐藏面板实验仅证明会不会产生反馈循环。

## Task 1：将反馈循环变成正式回归用例

**Files:**

- Modify: `CalendarProTests/Events/CalendarItemComposerTests.swift`
- Modify: `CalendarProTests/App/EventDetailWindowSizingTests.swift`
- Reference: `CalendarPro/App/EventDetailWindowController.swift:205`
- Reference: `CalendarPro/Views/Popover/EventDetailWindowView.swift:436`

**Step 1：建立可收集的基线。**

记录 `git status --short` 和 Xcode 版本，重新确认工作区改动。保留本次诊断的临时日志；临时路径失效时按设计文档重建最小隐藏宿主，不依赖真实日历授权。

**Step 2：添加实际宿主测试。**

在现有测试文件中加入 `@MainActor` 宿主辅助：创建隐藏 `NSPanel`，装载生产视图，使用生产尺寸计算方式回写；记录自然高度回报、手动窗口调整次数及末尾观察窗口中的变化。测试清理时卸载视图和回调，不向桌面显示面板。保留 `EventDetailWindowSizingTests` 原有纯尺寸用例，可在同文件中新增 `EventPanelLayoutTests` 类承载真实宿主测试，不将原测试全部改为依赖窗口环境。

宿主稳定性测试与控制器生命周期测试分工如下：前者验证真实视图测量会收敛，后者在任务 4 通过真实 `EventDetailWindowController` 验证最新回报和旧回调隔离。现有 `PopoverControllerTests` 使用模拟详情 presenter，只覆盖外围转发，不能代替这两类验证。

固定合成事件为两日全天，附 6 行 `Synthetic note https://example.com/path with text for sizing.`，另建同日期的定时事件。编辑器使用未保存 `EKCalendar` 和空保存闭包。

测试不能只断言某一个最终高度。至少验证以下行为：

- `testComposerWindowHeightSettlesWithoutInteraction`
- `testEventDetailWithNotesWindowHeightSettlesWithoutInteraction`
- `testComposerKeepsFooterWithinAvailableHeight`

测试场景矩阵：

| 场景 | 事件 | 备注 | 可用高度 | 必须验证 |
| --- | --- | --- | --- | --- |
| E1 | 两日全天 | 空 | 700pt | composer 自然高度稳定 |
| E2 | 当天定时 | 空 | 700pt | 时分控件出现后仍稳定 |
| D1 | 两日全天 | 6 行 | 700pt | 详情备注排版后停止持续调窗 |
| D2 | 两日全天 | 200 行 | 700pt | 窗口遵守上限，内容可滚动 |
| S1 | 两日全天 | 6 行 | 360pt | 标题和底部操作可达，内容不被静默截断 |
| L1 | 无备注 → 有备注 → 编辑 | 不同 | 700pt | 旧页面测量不会改变当前页面 |

固定 Gregorian 日历、日期和时区构造 fixture；全天 `EKEvent` 在赋值时可能按本机时区处理，日期往返断言使用真实回读字段，避免测试本身误判。fixture 不保存、不请求系统权限。

前两项先运行验证原始实现无法稳定。观察稳定性时使用有上限的调窗次数和末尾静默窗口；不要断言精确的排版高度或毫秒耗时，以免字体/系统版本造成脆弱用例。若主队列循环会阻止测试超时返回，宿主在超过阈值时立即停止回写并主动失败。

建议测试预算：总观察上限 3 秒，最后连续 0.5 秒无新主动调窗即可判定稳定；累计超过 64 次主动调窗时立即失败并停止回写。该次数为防挂死保护，不是性能指标。小窗口测试通过布局边界或可访问性位置确认按钮可见，不能只断言 `panel.frame.height <= 360`。

如果某个受支持系统没有复现原始缺陷，记录该系统和日志，不人为制造失败；至少让原始缺陷机上的回归用例先失败，再验证修复。避免用“一定正好回报 1 次”作为通用测试断言。

**Step 3：运行范围最小的失败检查。**

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-event-panel-performance -only-testing:CalendarProTests/CalendarItemComposerTests -only-testing:CalendarProTests/EventDetailWindowSizingTests -only-testing:CalendarProTests/EventPanelLayoutTests
```

预期：新增稳定性用例在原始实现失败；日期往返和既有尺寸规则仍通过。失败原因必须是高度不收敛，而非测试缺少 NSApplication / 主线程环境。

**完成门槛：** 保存失败场景的高度序列及退出原因。旧代码上的失败和修复后的收敛必须来自同一套宿主测量，不在测试里偷偷替换生产视图的布局行为。

## Task 2：编辑器改为自然内容测量

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift:96`
- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift:707`
- Test: `CalendarProTests/Events/CalendarItemComposerTests.swift`

**Step 1：测量三个独立区域。**

分别测 `header`、`content.fixedSize(horizontal: false, vertical: true)`、`footer`。去掉根背景中测当前总体布局高度的逻辑，去掉 `maximumHeight - 125`。使用同一组测量偏好/快照聚合各区域，测量结果只在变化超过 1pt 时更新；未知尺寸不能当作可提交的完整自然高度。

推荐直接在该文件中定义私有 `ComposerRegion` 和 `ComposerHeightsPreferenceKey`。每个区域在背景 `GeometryReader` 中写入高度偏好，根视图的一个 `onPreferenceChange` 接收本轮完整字典。这样可同时移除三个独立 state 写回造成的半完成快照，不新增共享 ObservableObject。

回报规则固定为：

1. 需要的区域全部到齐，且数值均为有限正数后才构造有效快照。
2. 从本次局部快照计算自然高度和视口，不依赖刚赋值但尚未更新的旧 `@State`。
3. 高度向上取整，以 >1pt 差异判断是否更新，忽略相同偏好重发。
4. 初始内容高度可以是零的“尚未测得”状态；滚动内容仍参与自然尺寸测量。未知值不能保存为最终零高度。
5. 外层背景填充可以覆盖理想窗口留下的空白，但不得再次把其高度作为输入。

**Step 2：明确设置滚动视口。**

采用以下独立计算，不从窗口当前高度反推：

```swift
let chromeHeight = headerHeight + footerHeight
    + PopoverSurfaceMetrics.outerPadding * 2
    + PopoverSurfaceMetrics.sectionSpacing * 2
let naturalHeight = chromeHeight + contentHeight
let viewportHeight = min(contentHeight, max(0, maximumHeight - chromeHeight))
```

`ScrollView` 使用 `.frame(height: viewportHeight)`，标题和底部留在滚动区外；表单内容测量在固定宽度下不受视口高度影响。将完整 `naturalHeight` 回报给控制器。

**Step 3：删除重复异步转发。**

测量在安全的布局结束阶段批量提交，控制器负责下一轮合并写入；不要继续保留 `ComposerHeightReporter.report` 和 `reportPreferredHeight` 两层 `DispatchQueue.main.async`。

临时目录中的候选编辑器已验证上述测量方式会从数百次回报降至一次，可用作实现参考；正式实现应使用结构明确的测量快照，避免照搬探针中的 key path 测量辅助。

**Step 4：运行编辑器回归。**

执行 Task 1 命令中的 `CalendarItemComposerTests`。此步骤若仍受 hosting 自动约束影响，继续完成 Task 4 后验证收敛，不单独交付中间版本。

**完成门槛：** 全天与定时表单均报告独立于当前 panel 高度的自然高度；在 360pt 和正常高度下，标题及按钮留在滚动区外。保存、草稿和日期动作代码不因布局调整而变化。

## Task 3：详情页移除三路高度相减

**Files:**

- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:59`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:281`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:436`
- Modify: `CalendarPro/App/EventDetailWindowController.swift:69`
- Test: `CalendarProTests/App/EventDetailWindowSizingTests.swift`

**Step 1：传入有效可用高度。**

控制器向详情视图传入与最终 `EventDetailWindowSizing.panelSize` 一致的有效上限；至少考虑已有 `minHeight` 规则。不直接在视图硬编码 700pt。新增内部初始化参数保留合理默认值，使现有构造调用兼容。

**Step 2：用内容区独立测量替换相减。**

移除 `containerHeight`、`detailViewportHeight` 与 `container - viewport + content`。测量标题、摘要、会议操作、详情内容、底部按钮；会议操作不存在时对应高度为零，参与间距按实际区域数计算。视口高度为 `min(detailContentHeight, max(0, maximumHeight - chromeHeight))`。

沿用任务 2 的私有偏好聚合方式，在该文件内使用独立的 region/key，避免为两个视图建立可配置通用表单框架。回调需要从本轮预期区域集合构建快照：没有会议操作时不等待其测量，也不能保留上一轮会议区的旧高度。

无会议操作时实际垂直间隔为 3 处，有会议操作时为 4 处；外边距仍为两倍 `PopoverSurfaceMetrics.outerPadding`。标题、摘要、底部按钮采用各自自然高度，不从 panel frame 作减法。参与范围确认 overlay 属于覆盖层，不增加主内容自然高度。

在一次 `content` 求值中将会议操作解析结果存到局部值，保证显示条件、操作区内容和所需测量区域使用同一份结果。

详情内容在滚动区域内采用垂直自然尺寸。备注从初始高度收敛到排版后高度可以触发少量有效回报，但每次窗口变化本身不得改变内容的自然高度。

**Step 3：覆盖动态内容。**

回归无备注、6 行备注、200 行备注、备注展开/折叠、会议操作出现/缺失、只读按钮变化。已有全天 `visibleEndDate` 继续复用日期草稿，不改成秒数减一天。

**Step 4：运行详情稳定性和尺寸规则测试。**

预期 6 行备注场景稳定，长内容钳制在有效上限，短内容继续遵循原理想高度。不要以“备注越长越稳定”作为验收理由。

**完成门槛：** 详情不再记录或回报滚动视口的测量值；备注排版完成后能稳定，展开/折叠确实更新自然高度。浅色/深色模式和选择文字行为没有布局回归。

## Task 4：统一窗口尺寸所有权和回调生命周期

**Files:**

- Modify: `CalendarPro/App/EventDetailWindowController.swift:69`
- Modify: `CalendarPro/App/EventDetailWindowController.swift:121`
- Modify: `CalendarPro/App/EventDetailWindowController.swift:158`
- Modify: `CalendarPro/App/EventDetailWindowController.swift:189`
- Modify: `CalendarPro/App/EventDetailWindowController.swift:205`
- Modify: `CalendarPro/App/EventDetailWindowController.swift:230`
- Test: `CalendarProTests/App/EventDetailWindowSizingTests.swift`
- Regression: `CalendarProTests/CalendarProTests.swift`

**Step 1：手动管理的宿主关闭自动尺寸约束。**

对日程详情、新建和编辑的 `NSHostingController` 设置 `sizingOptions = []`；不要让自动 intrinsic / min / preferred size 同时操纵手动尺寸。共享入口显式区分手动策略和提醒事项详情既有策略，确保没有误伤。

首次尺寸采用当前 ideal height 或有界的 `hostingController.sizeThatFits(in:)`。禁用 sizing options 后 `view.fittingSize` 在探针中为零，不能无条件继续依赖。之后以内容自然测量为准。

实施时固定采用：先给当前宿主设置固定宽度和按有效上限钳制的 ideal height；若调用一次有界 `sizeThatFits(in:)` 得到有效结果，则可用于首帧，否则继续使用 ideal height。首次偏好测量完成后按自然高度调整。不要在初始化阶段循环强制布局，也不重新加入 `layoutSubtreeIfNeeded()`。

有效高度上限由控制器一次计算并同时交给视图和尺寸钳制逻辑，至少保持现有 `max(availableHeight, minHeight)` 规则一致。提醒事项详情继续使用原自动测量策略；关闭/替换逻辑也必须为它生成新页面身份，防止复用同一 detail panel 时收到日程页旧回报。

**Step 2：合并最新请求并防止过期回写。**

控制器维护当前展示 generation、pending height 和最多一个待执行任务。高度闭包绑定展示时的 panel 和 generation；每次展示、切换模式与关闭使旧任务失效。执行回写前再次核对身份，校验有限正数并应用 >1pt 阈值。

关闭时取消待执行任务，清理对应 hosting 内容与测量引用；不取消新页面任务。旧详情的备注测量完成后不能调整编辑器面板。

具体时序：

1. 每次 `show(event:)`、`show(reminder:)`、`showComposer`、`showEditor` 先失效旧尺寸任务，再完成必要的旧 panel 关闭。
2. 旧 panel 的同步关闭回调处理结束后，登记新 panel、关闭闭包和新的 `presentationID`。
3. 内容的高度闭包捕获本次 ID，对 panel / anchor 使用弱引用。接收回报时先核对 ID 和对象身份，再覆盖 pending height。
4. 当前没有待执行任务时才入队一次主队列任务；任务执行前再次核对身份。旧任务不得先清空新任务的 pending state 再退出。
5. 应用最新高度后清空本次 pending state；同轮收到多个有效高度只设置一次最终 frame。
6. `windowWillClose` 首先核对通知中的窗口是否仍是当前 panel，再清理当前展示和调用一次对应 `onClose`。旧窗口迟到的关闭通知不能清理新面板。

保留最多一个可取消的调窗任务即可，不引入固定 100～300ms debounce。测量聚合解决输入语义，队列合并解决重复调度，二者职责不同。

**Step 3：每次有效变化只设置一次最终 frame。**

borderless panel 的 frame / content 转换按现有结构确认后，避免重复设置同一尺寸；保持顶部对齐和左右定位。减少一次设置是减工作量，不替代前面的反馈循环修复。

**Step 4：添加生命周期行为回归。**

覆盖“旧详情入队测量 → 打开新详情/编辑 → 执行主队列”的真实路径；断言新 panel 尺寸由新内容决定。另验证关闭后旧测量不会重新调窗。避免为私有方法调用顺序写死实现细节。

如实际控制器无法在隐藏窗口中观察，允许增加最小的内部构造依赖：`panelFactory` 创建给定 rect/style 的 `NSPanel`，以及 `activateApplication` 执行应用激活。默认值继续使用当前 FloatingPanel 和 NSApp 行为；测试传入记录 frame 的隐藏面板及空激活闭包。不要新增公共协议、暴露私有 resize 方法或改变 `EventDetailWindowPresenting`。

高度生命周期测试可从真实 hosting controller 的 `rootView.onPreferredHeightChange` 保存旧回调，在替换或关闭前后主动触发，从而确定性验证过期输入，而不依赖随机排版时序。

| 建议用例 | 操作 | 断言 |
| --- | --- | --- |
| `testLatestPreferredHeightWinsWithinOneMainQueueTurn` | 已稳定页面同轮回报多个高度 | 下一轮只使用最后一个有效高度 |
| `testPreviousDetailHeightCannotResizeReusedPanel` | 同一个 detail panel 展示 A 后改为 B，再调用 A 的回调 | B 不采用 A 的高度 |
| `testPendingDetailHeightCannotResizeEditor` | A 高度已入队，立即切到 editor | 原待执行任务不能操作新 panel |
| `testClosingPanelCancelsPendingHeightUpdate` | 入队后关闭，再执行旧回调和主队列 | 不再设置已关闭或新 panel 的 frame |
| `testLateCloseNotificationDoesNotClearCurrentPresentation` | 已替换窗口后处理旧窗口通知 | 新窗口及其关闭回调保持有效 |

与任务 1 一样，以上测试必须执行真实控制器路径；外围 FakePresenter 仅用于原有 popover 行为回归。

**Step 5：运行所有 Task 1 稳定性测试和控制器回归。**

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-event-panel-performance -only-testing:CalendarProTests/CalendarItemComposerTests -only-testing:CalendarProTests/EventDetailWindowSizingTests -only-testing:CalendarProTests/EventPanelLayoutTests -only-testing:CalendarProTests/EventDetailWindowControllerTests -only-testing:CalendarProTests/PopoverControllerTests
```

预期：自然高度收敛，小屏幕滚动正常，关闭/替换生命周期没有旧回写。

命令已包含同文件新增的 `EventPanelLayoutTests` / `EventDetailWindowControllerTests`。实施后核对实际测试 discovery，确认新套件确实执行，不以命令退出成功代替用例数量检查。

**阶段 A 门槛：** 任务 1 的缺陷样本从失败转为稳定；所有新生命周期用例通过；实际打开、关闭和切换面板不再持续跳动。此时才开始任务 5～7，避免多个优化互相掩盖问题。

## Task 5：备注只保留一个文字测量来源

**Files:**

- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:901`
- Test: `CalendarProTests/App/EventDetailWindowSizingTests.swift` / `EventPanelLayoutTests`

**Step 1：只在文字变化时更新富文本。**

`AttributedTextView` coordinator 记录上次 notes，复用 detector。`updateNSView` 对相同文本不再替换 `textStorage`。测量只与文本、可用宽度及影响布局的属性相关；保留系统动态颜色、链接和文字选择。

将高度来源统一到 representable 的测量或单一可控回报，不并用异步 `textHeight` state 与另一条独立 `sizeThatFits` 回路。文本布局仍在 AppKit 主线程运行；先删重复工作，不为此引入 detached NSTextView 操作。

**Step 2：以 `sizeThatFits` 作为唯一高度出口。**

macOS 最低版本已支持 representable 的 `sizeThatFits`。移除 `SelfSizingTextView.textHeight` state、对应 binding、显式 `.frame(height: textHeight)` 和 `updateNSView` 中异步回写高度的闭包。

在 `sizeThatFits` 中验证 proposal 宽度为有限正数，根据文字视图实际宽度、inset 和 lineFragmentPadding 设置 text container；再读取实际排版高度向上取整。缺少有效宽度时返回 `nil`，等待有效提议，不缓存零宽度的结果。

coordinator 只缓存最后 notes、有效测量宽度和内容版本对应的 CGSize；notes 或影响排版的字体变化后失效，宽度相同且内容不变时可复用。`sizeThatFits` 不修改 SwiftUI state，也不在其中安排新的调窗任务。

**Step 3：验证文字属性与重新布局。**

检查正文替换、同正文重新渲染、窄宽度/正常宽度切换、中文/英文/emoji/长链接、0 行及 200 行备注。内容改变后必须重新排版，单纯高度变化不得重新跑链接识别。

使用 Instruments 调用树或临时 DEBUG 计数确认：稳定状态的无关视图刷新不会再次调用 `textStorage.setAttributedString` 或创建 detector。不要为检查调用次数新增长期暴露给产品的统计属性。

**完成门槛：** 原详情稳定性测试继续通过；长备注保持可滚动、文字选择与链接可用；备注高度变化只通过自然内容偏好传到控制器。

## Task 6：日期格式化按页面上下文复用

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift:450`
- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift:823`
- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift:993`
- Modify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift:1132`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:400`

**Step 1：统一 locale / calendar / time zone 上下文。**

编辑器继续使用已捕获的 editingCalendar；格式化也使用该 calendar 的 timeZone 和当前 app locale。优先采用值类型 `Date.FormatStyle`，避免在 body、日期按钮及 42 格可访问性 label 内分别创建 formatter。若某个格式需要保留现有 `HH:mm` 等精确输出，用页面作用域 DateFormatter，并只在上下文改变时重建。

**Step 2：逐个替换格式化热点。**

覆盖顶部摘要、开始/结束日期按钮、开始/结束时分、月份标题、日格 accessibilityLabel 和详情日期范围。一个按钮本次渲染的显示值可存为局部字符串，同时供正文和 accessibilityValue 使用。

42 个日格共享同一完整日期格式定义；月格生成和选中判断继续使用既有日历。不要把所有日期字符串预先永久缓存，更不要用系统默认时区格式化事件后反向重建保存日期。

**Step 3：验证显示与失效。**

验证简中、英文、跨年日期、月历翻页和带年份日期，确保窄日期按钮不会因更长格式无法读取。保持时分的 24 小时显示。App 语言在重新呈现后生效；如果现有根视图支持打开状态下的语言更新，则格式也必须同步失效。编辑中的时间计算继续使用该次编辑日历快照。

**完成门槛：** 日期弹层打开不再出现逐格 formatter 初始化；现有日期语义测试通过，accessibilityLabel 仍能区分年份、日期和星期。将对比值记作格式化耗时，不宣称其等于整个界面的加速比。

## Task 7：会议匹配规则预编译和单次布局复用

**Files:**

- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift:76`
- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift:107`
- Modify: `CalendarPro/Features/Events/MeetingLinkDetector.swift:125`
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:59`
- Regression: `CalendarProTests/Events/MeetingLinkDetectorTests.swift`
- Regression: `CalendarProTests/Events/MeetingActionResolverTests.swift`

**Step 1：预编译现有规则。**

在既有 pattern 定义处存储已编译 `NSRegularExpression`，保留优先级和尾部标点处理。同次详情布局中不要重复完整解析相同事件。备注变更、外部更新与参与操作后的数据刷新仍可使快照失效。

事件 URL → 备注 → 地点的检测顺序和各平台匹配顺序均维持。pattern 编译与匹配分开，避免 `findInText` 和 `matchURL` 各自重建相同正则。Swift 6 下按现有调用隔离实现，不新增 `@unchecked Sendable`。

**Step 2：限制结果复用范围。**

任务 3 已在一次 content 求值中复用解析结果，先保留这一小范围优化。若仍需跨重绘复用，缓存键至少包含 URL、notes 和 location；参与状态等实时信息单独更新，不永久冻结整个 `EKEvent`。没有采样收益时不增加跨页面 LRU 或通用事件缓存。

**Step 3：运行最相关回归并记录量级。**

复用既有会议解析测试，保留平台顺序、URL 直接识别、备注及地点识别、尾部标点处理等断言；新增行为条件时才补针对性测试。在同一输入上比较多次匹配的耗时，确认正则初始化已经从匹配循环移出。

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-event-panel-performance -only-testing:CalendarProTests/MeetingLinkDetectorTests -only-testing:CalendarProTests/MeetingActionResolverTests
```

**阶段 B 门槛：** 布局稳定性不回退；旧平台链接解析行为保留；相同文本和日期重复渲染的初始化工作已显著减少，且不会出现内容变更后继续显示旧结果。

## Task 8：测量用户操作并完成 UI 验收

**Files / Resources:**

- Verify: `CalendarPro/App/EventDetailWindowController.swift`
- Verify: `CalendarPro/App/PopoverController.swift`
- Verify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`
- Verify: `CalendarPro/Views/Popover/CalendarItemComposerView.swift`
- Reference: `CalendarProUITests/CalendarPopoverUITests.swift`
- Artifacts: 本任务 DerivedData / xcresult / Instruments trace 和脱敏截图

**Step 1：选择固定且可比较的测量方式。**

同一机器、同一构建配置，分别记录第一次打开和预热后的交互。使用 Instruments Time Profiler / Hangs；必要时用临时 `os_signpost` 标记选择动作、内容可交互、关闭发起与窗口隐藏，结束后保留最少需要的诊断点或移除临时计数。

冷启动或系统日历首次加载独立报告，不和预热后数据混算。每条路径至少采集 30 次预热样本，按升序第 `ceil(0.95 * count)` 个样本统计 p95；记录样本数和最大值。菜单栏弹层动画完成时间与事件处理/窗口隐藏时间分开记录，不通过关闭原有动画来达标。

**Step 2：沿用户原始操作顺序验收。**

| 编号 | 操作 | 结果要求 |
| --- | --- | --- |
| U1 | 打开两日全天详情，无操作观察 3 秒 | 最后 2 秒无持续主动调窗，无持续高占用 layout 链 |
| U2 | 全天详情 → 其他日程，连续往返 | 选中和内容及时更新，旧高度不影响新页面 |
| U3 | 详情可见时点击其他应用 | 下拉日历和详情随关闭路径消失，无数秒排队 |
| U4 | 点击全天日程编辑 | 编辑器及时可交互，标题焦点正确 |
| U5 | 起止日期弹层打开、翻月、选日期、取消 | 无鼠标长时间转圈，选值/取消行为正确 |
| U6 | 全天 ↔ 定时，输入非法结束，再修正 | 控件、就近错误和保存状态正确，无高度循环 |
| U7 | 备注展开折叠、长备注滚动、选择和打开链接 | 高度可变但很快稳定，文本交互正常 |
| U8 | 360pt 高度、长标题、中文/英文、浅色/深色 | 标题和底部操作可达，内容可滚动，日期可读 |
| U9 | 新建事件、提醒事项详情和含/不含时间编辑 | 共用窗口和控件保持正常 |
| U10 | 关闭后立即重开，详情直接转编辑 | 不闪回旧尺寸，不残留旧回调或关闭状态 |

**Step 3：判定性能目标。**

预热后的事件处理/可交互或窗口隐藏延迟目标为 p95 <100ms；主线程不应出现本次路径造成的 >250ms 单次阻塞。冷打开、完整动画和 EventKit I/O 单独说明。隐藏探针调窗数只能作为收敛证据，不能代替这些应用内结果。

如果出现 >250ms 阻塞，附主线程栈并归属布局、文字、EventKit 或系统行为，再决定补充修复。没有采样到用户原始现场时如实记录，不将数据量或权限作为未经证实的原因。

**Step 4：选择合适的 UI 验证入口。**

现有 `CalendarPopoverUITests` 的 `popover-window` 模式用于常规窗口，不能单独证明真实菜单栏弹层的失焦关闭行为；它也没有现成的全天事件 fixture，且会终止同 bundle ID 的运行实例。本任务优先用隐藏宿主做自动化稳定性回归、用受控测试实例完成真实菜单栏操作；执行现有 UI 套件只作为补充导航回归，不能宣称已自动覆盖 U1～U10。

无需为此搭建通用测试数据注入系统；复用可用的内存 fixture 或明确隔离的测试事件。只改标题保存等会写入的检查仅操作测试事件，不触碰用户原事件。

**完成门槛：** U1～U10 逐项记录通过/失败/未验证，并附环境、测量方式和耗时。实际仍卡顿时按调用栈继续处理，不以候选方案已收敛结束验收。

## Task 9：构建、关联回归与交付记录

**Files:**

- Verify: 本方案列出的应用与测试文件
- Update: `docs/plans/2026-10-29-cross-day-event-editing-design.md`
- Update: `docs/plans/2026-10-30-event-panel-performance-design.md`
- Update: 本文执行记录

**Step 1：一次运行日期和窗口关联回归。**

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-event-panel-performance -only-testing:CalendarProTests/CalendarEventScheduleDraftTests -only-testing:CalendarProTests/CalendarItemComposerTests -only-testing:CalendarProTests/EventServiceTests -only-testing:CalendarProTests/EventDetailWindowSizingTests -only-testing:CalendarProTests/EventPanelLayoutTests -only-testing:CalendarProTests/EventDetailWindowControllerTests -only-testing:CalendarProTests/PopoverControllerTests -only-testing:CalendarProTests/MeetingLinkDetectorTests -only-testing:CalendarProTests/MeetingActionResolverTests
```

**Step 2：构建与全量单元测试。**

```bash
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-event-panel-performance
```

```bash
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/var/folders/d9/5sfcnz292bvbdh3nv19rvhc40000gn/T/opencode/CalendarProDerivedData-event-panel-performance -only-testing:CalendarProTests
```

此前文档记录过 BoardSnapshotTests 的语言断言失败；执行时重新核对，不预设当前一定失败或通过。

**Step 3：核对任务 8 的交互记录。**

将每个场景的状态、trace/截图位置及未完成原因整理到设计文档。只有隐藏窗口测试通过时，交付描述必须写“布局稳定性已验证，实际交互尚未验收”，不能写“用户卡顿完全解决”。

**Step 4：检查差异并更新记录。**

```bash
git diff --check
```

说明实际通过的构建/测试、UI 测量、未验证项和截图位置。若没有新增 Swift 文件，不运行工程生成器。新增测试文件才按仓库约定注册并保留版本、scheme 和锁文件；优先在现有文件补用例以减小工程变更。

**最终交付清单：**

- 代码：详情、编辑器和控制器共同消除尺寸反馈；文本和日期重复工作减少。
- 自动化：真实宿主收敛、小窗口、过期回调、关闭清理、日期语义及平台链接回归均有证据。
- 人工/性能：U1～U10、冷/热打开耗时、p95/最大值、主线程采样和未验证项有记录。
- 文档：跨天编辑设计补充此次高度策略的后续链接；本方案和诊断设计状态与实际一致。
- 范围：没有版本号、依赖、发布源或用户真实日历的无关变更；未经用户要求不提交或推送。

## Task 10：仅在仍有 EventKit 阻塞时执行

**启动条件：** 任务 8 的主线程采样仍出现 `EKEventStore.calendars`、`events(matching:)` 或相关同步解析造成的明显阻塞，并保留可重复场景。没有该证据时本任务记为“不需要”，不为完整性提前改造。

**Files:**

- Potential Modify: `CalendarPro/Views/RootPopoverView.swift:566` / `:610` / `:1013`
- Potential Modify: `CalendarPro/Features/Events/EventService.swift:134` / `:196` / `:206` / `:399`
- Regression: `CalendarProTests/Events/EventServiceTests.swift`
- Regression: `CalendarProTests/Popover/UpcomingSnapshotTests.swift`

**Step 1：先去除相同交互中的重复查询。**

检查 `refreshEventsForCurrentSelection → loadEvents` 对日历的重复枚举，集中到一次目录刷新。事件编辑不预先刷新无关提醒事项目录；已有目录有效时先打开编辑器。权限变化和 `.EKEventStoreChanged` 仍刷新并使相关数据失效；空目录不能永久阻止后续可写日历出现。

**Step 2：重新采样。**

在相同数据和操作路径下比较查询次数、主线程等待和 p95。去重后已达标时结束，不继续迁移 store。

**Step 3：只有仍阻塞时设计独立数据路径变更。**

采用单一串行 worker / actor 拥有 store，从读取到字段提取都在同一隔离域完成，界面接收值类型快照。更新事件按标识在 store 所属隔离域重新解析，保留重复实例区分、`.thisEvent`、未修改字段和错误反馈。取消旧请求、store change 失效和写后刷新也在方案中明确。

这一变更影响列表、详情、写入和提醒事项，应先补独立设计及兼容性评估，再进入实施；不通过捕获现有 `EKEvent` 的 `Task.detached`、延后主线程调用或 `@unchecked Sendable` 规避问题。

## 执行记录

2026-10-30：完成诊断及隐藏面板候选方案验证，未执行上述生产实施步骤。隔离原始实现出现持续尺寸交替，候选自然测量 + 单一尺寸管理 + 最新回报合并在全天、定时、小高度和长备注场景均收敛。未修改应用源码、未提交、未写入日历。

2026-10-30：按用户要求细化为 9 项本次必做任务及 1 项采样触发的后续任务，补充阶段门槛、区域偏好聚合策略、真实控制器测试缝、过期通知处理、单一文本测量路径、用户操作矩阵及性能采集方法。本次仅更新计划，不执行生产代码修复。

2026-10-30：完成任务 1～7。编辑器与详情视图分别测量固定区和滚动内容的自然高度，控制器禁用手动管理页面的自动尺寸约束、采用有界 `sizeThatFits` 首帧测量并合并每轮最新高度；页面替换、关闭及旧 panel 迟到通知均由展示身份隔离。备注高度统一由 `NSViewRepresentable.sizeThatFits` 提供；重复备注不再替换富文本；日期 formatter 按页面/控件上下文复用；会议正则预编译且详情布局使用同一份会议操作快照。已建立隐藏真实 AppKit 宿主及真实控制器回归。

- `xcodebuild build ...`：通过，Xcode 27.1 / macOS 27.0.1 / arm64 Debug。
- 关联回归（日期草稿、跨夜/全天请求、EventService、窗口尺寸/布局、控制器生命周期、PopoverController、会议链接与操作解析）：最终复跑 85 项通过。控制器生命周期测试覆盖旧页面高度、关闭后回调、同轮最新有效高度和旧 panel 迟到关闭通知。
- 全量 `CalendarProTests`：476 项中 475 项通过，1 项失败。失败为 `BoardSnapshotTests.testGroupingByPriorityOrdersHighMediumLowNoneAndSkipsEmptyGroups`，断言期望中文优先级分组名称，当前运行环境实际本地化为英文；失败位置 `CalendarProTests/Popover/BoardSnapshotTests.swift:115`，与本次改动无关。
- `git diff --check`：通过。
- 尚未运行 UI 测试，也未在应用实例中完成 U1～U10、冷/热延迟采样或 Instruments 主线程采样。因此当前结论是布局收敛、日期语义和控制器生命周期已由自动化验证；真实菜单栏失焦关闭、鼠标响应以及 p95/阻塞目标仍未验收。没有采样证据触发任务 10，不修改 EventKit 并发模型或用户日历。
