# Issue #4 菜单栏自适应文字色修复实施计划

**Goal：** 日程色点出现与消失时，默认菜单栏文字继续接受系统模板着色，色点仍保留日历原色。
**Architecture：** 一个 NSStatusItem、一个原生 NSStatusBarButton；默认非 emoji 文字用模板底图，色点用同尺寸原色覆盖图。自定义前景色、填充背景、既有 emoji 原图路径保持兼容。
**Tech Stack：** Swift 6、AppKit、Combine、SwiftUI、XCTest。
**执行者：** Luna；实现、验证、审查、纠偏、提交合并均由 Luna 完成。

## 基线与决策

- 来源：本目录 `analysis.md`；已确认 `ClockRenderService.swift:191–205` 的 `!hasDot` 使整图失去模板着色，普通文字则固定为白色。
- 指定起点：`6bbc0946b97fd3ecb0ae7e994dfa199c484f7519`；目标分支 `main`。
- 分析时 HEAD 等于起点，工作区及 index 干净；计划不依赖未提交文件。实施开始仍须检查实际状态，保护之后新增的用户修改。
- 分支和工作流由后续自动命名；本阶段不创建分支、不修改 index、不修改业务代码。
- 不选择仅将固定白色替换为 labelColor：这不能恢复系统模板对菜单栏背景与控件状态的处理。不将整个彩色图强制模板化，以免丢失日历颜色。
- 不增加设置、权限或偏好迁移；不更改事件筛选、来源授权、番茄计时与弹层行为。

## 验证要求分级（以本节为准）

### 用户需求与项目既有要求

- 用户需求：确认并修复 issue #4，不破坏原有功能；本阶段仅计划，后续由自动工作流继续。
- AGENTS.md：相关自动化测试；涉及菜单栏/弹层需提供手动验证说明；UI 改动的 PR 应附截图或录屏；影响设计假设时更新既有设计文档；新增/删除源码或测试时重建 Xcode 工程。
- 手动验证说明应写清步骤、预期、实际执行情况及环境限制。项目并未要求本计划新增的每一种人工组合都必须成功执行；不要把建议矩阵升级为逐项硬门禁。
- PR 截图/录屏要求不能默认为不存在；若当前环境无法产出，明确记录证据缺口，交由 Luna 收尾审查处理，不伪造截图或无限等待 GUI。

### 本修复的自动化验证计划

- 单元 1 的定向测试验证渲染分层、颜色内容与按钮状态切换；功能齐备后执行 build、完整 test 和 diff 检查。它们是本方案选择的回归检查，不宣称用户逐项指定了这些命令。
- 失败时先判断产品回归还是环境限制；普通编译/逻辑错误直接修复。环境受限按文末一次针对性重试规则处理。

### 补充建议（不新增人工阻塞门禁）

- 单元 2 所列亮/暗壁纸、全部高亮状态、1/2/3 点人工排列、emoji/胶囊组合、多屏、多缩放及额外 macOS 版本，是针对风险提出的建议覆盖。
- 有 GUI 时优先采集 issue 场景的有点/无点对比及点击行为；未能完成的补充矩阵标注未验证，不要求用户逐项执行，也不使工作流无限 progress。
- 自动化能够覆盖的颜色隔离、几何和生命周期优先自动化；真实系统着色效果未观察时如实说明，不能将模板标志断言描述为视觉验证通过。

## 单元 1：完成默认文字与彩色色点分层的业务闭环

### 修改范围

1. `CalendarPro/Features/MenuBar/ClockRenderService.swift`
   - `MenuBarTextImageRenderResult` 新增可选 `indicatorOverlayImage`。
   - `MenuBarTextImageRenderer.render`：默认非 emoji 文字不再因为色点而关闭模板；底图只画文字并保留色点布局空间，色点绘于独立非模板图。
   - 共用尺寸、坐标及色点绘制逻辑，避免两条路径出现布局差异。
2. `CalendarPro/App/StatusBarController.swift`
   - 图片应用增加覆盖图的复用、定位及清理。
   - 在现有文件内定义轻量覆盖视图和可测试辅助方法，保持 target/action、tooltip、accessibility label。
3. `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`
   - 替换 `testTextImageRendererUsesOriginalImageForCalendarColorIndicator` 的旧预期。
   - 添加渲染内容与按钮状态转换回归测试。

### 步骤

1. 检查实施目录的 HEAD、工作区和 index，从指定起点建立任务分支/worktree。不要复制或覆盖原工作区用户改动。
2. 先补失败测试：默认文本加绿色 ongoing 色点，文字图必须仍为模板，色点必须有独立原色载体；去除色点后覆盖图清空。旧实现至少应有一项对应断言失败。

   首先采用现有 API 编写以下测试，避免仅因新增属性尚未存在而产生编译失败：

   ```swift
   func testDefaultTextKeepsTemplateColorWithEventIndicator() {
       let indicator = MenuBarEventIndicator(
           dots: [MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing)],
           tooltipText: "会议",
           count: 1
       )
       let result = MenuBarTextImageRenderer().render(
           text: "10:30 Tue 04/22",
           style: .default,
           indicator: indicator
       )
       XCTAssertTrue(result.usesTemplateColor)
       XCTAssertTrue(result.image.isTemplate)
   }
   ```

   运行本单元定向命令，预期旧基线在上述两项断言失败。实现后再追加 overlay 内容和清理检查；不能仅删除原来的原图测试而不补充保留彩色色点的断言。
3. 将渲染结果扩展为以下形状（字段名称可遵循周边风格微调，语义固定）：

   ```swift
   struct MenuBarTextImageRenderResult {
       let image: NSImage
       let usesTemplateColor: Bool
       let indicatorOverlayImage: NSImage?
   }
   ```

4. 模板条件移除 `!hasDot`，保留显式前景色、实际填充背景及 emoji 判定。模板底图画黑色 alpha 掩码；overlay 为透明背景、原色色点，`isTemplate = false`。自定义/填充/emoji 路径保留完整原图，overlay 为 nil。
5. 保持直径 6pt、文字间距 6pt、列间距 4pt、行间距 2pt；两点一列上下，三点第二列上方；ongoing 实心、upcoming 空心，非法颜色继续回落 systemBlue。画布高度须容纳点及描边，包含空文字情形。
6. 控制器继续将底图交给原生按钮；覆盖视图复用且不可命中，使用 cell 的 image rect 对齐绘图区域，随按钮布局更新。清除色点或进入原图路径时隐藏/清除覆盖图。不要每次刷新新增 subview。
7. 完成以下自动化验收矩阵并运行定向测试。

### 单元验收

- 默认文字的 0/1/2/3 点场景均保持模板底图；nil 与空 dots 不占额外空间。
- 有点时 overlay 非模板、文字区域透明；底图色点区域透明。采样实心绿色点及空心点，确认颜色、描边和透明中心，不使用脆弱的整图逐像素快照。
- 1 点与 2 点宽度一致，3 点增加一列；文字自身几何与 alpha 不随色点增删改变。
- 自定义文字色、浅/深填充、粗体及 emoji 仍走兼容原图路径，没有重复色点。
- 按钮从有点→无点、默认→自定义→默认、1 点→3 点及文字长度变化时没有残留，最多一个覆盖视图；覆盖层不拦截点击，tooltip/accessibility 保留。
- AppKit 测试遵循 Swift 6 MainActor 隔离要求。

```sh
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests
```

计划复用已有源文件和测试文件，不新增文件，因此不预计修改 Xcode 工程。如果实施中确需改变这一决策，先更新任务 change-scope.json 纳入新文件及受影响工程文件，再执行 `ruby tools/generate_xcodeproj.rb` 并复核生成差异。单元完成后继续单元 2，不等待用户 resume。

**单元复核：** 检查所有 `MenuBarTextImageRenderResult` 初始化均传入新字段；模板路径不再绘制彩色色点，原图路径没有漏画/重复绘制；覆盖层的帧、翻转坐标和缩放与 button cell 一致；字重和原有默认文字 alpha 不因修复被无意改变。布局辅助方法应服务生产逻辑，不为测试新增产品开关或 EventKit 依赖。

## 单元 2：真实菜单栏验收与最终交付

### 修改/核对范围

- `CalendarPro/Views/Settings/MenuBarSettingsView.swift`：仅读取核对无 indicator 的现有预览兼容性，不预计修改。现有预览传 indicator: nil，继续读取 image 和 usesTemplateColor 即可；此次不新增预览色点功能。
- `docs/plans/2026-04-22-menubar-font-style-design.md`
- `docs/plans/2026-04-29-upcoming-event-indicator-design.md`
- `docs/plans/2026-05-15-menu-bar-event-indicator-two-row-design.md`

### 步骤与验收

1. 编写项目要求的手动验证说明：使用已有授权测试来源触发正在进行/即将到来的事项，默认样式对比无点、有点及点消失，预期文字不因色点而切换颜色策略。有可用 GUI 时执行并记录实际结果，否则明确说明未执行及原因。
2. 建议人工检查浅/深外观及亮/暗菜单栏背景、点击高亮、popover 开关、1/2/3 点布局，预期点区域点击也触发原按钮动作。主题颜色不等于菜单栏背景；这些新增组合不作为必须逐项通过的门禁。
3. 建议补充显式文字色、胶囊填充、番茄 emoji 与设置预览，有条件再检查多屏及不同缩放。按项目 PR 要求准备截图/录屏；不可获取时记录缺口，由收尾审查决定如何补证据。
4. 更新上述既有设计文档的单图假设，说明模板底图与彩色色点分层，但仍是单个系统按钮。
5. 功能齐备后运行一次全量验证：

   ```sh
   xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
   xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
   git diff --check
   ```

6. Luna 审查实际 diff、自动化及 UI 证据，解决遗漏后按工作流完成提交合并。建议提交主题：`fix(menu-bar): preserve adaptive text color with event indicators`。

**最终复核：** 变更只涉及本问题的渲染、按钮呈现、测试与设计记录；没有权限/事件筛选/偏好迁移改动，没有覆盖原工作区用户修改。默认文字保持系统模板语义，色点保持原色、位置与空心/实心状态，原图样式兼容；通过的自动化结果、未完成的人工建议与实际环境限制分开列明。

## 精确变更范围与工作区依赖

预计仅修改以下六个现有仓库文件，没有新增、删除或重命名业务文件：

1. `CalendarPro/Features/MenuBar/ClockRenderService.swift`
2. `CalendarPro/App/StatusBarController.swift`
3. `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`
4. `docs/plans/2026-04-22-menubar-font-style-design.md`
5. `docs/plans/2026-04-29-upcoming-event-indicator-design.md`
6. `docs/plans/2026-05-15-menu-bar-event-indicator-two-row-design.md`

以上同步写入本任务 `change-scope.json`。UpcomingEventMonitor、MenuBarPreferences、MenuBarSettingsView 等仅作为参考读取，不列入修改范围。任务报告和插件回执位于 .git，不是待提交业务变更。

本轮 plan 检查时 HEAD 仍等于指定起点，`git status --short` 与两种 diff stat 无输出，因此没有未提交依赖。如果实施时发现新的本地行为依赖，必须明确纳入范围、按实际 diff 移入任务 worktree，不能默认未提交内容自动复制。

## 验证记录与停止条件

- 每次实际检查在本任务目录 `validation.md` 追加命令、退出结果、代码版本/工作区差异与环境。
- 只有相关代码或环境变化才重跑已通过检查；计划中的命令不算已执行结果。
- GUI、系统授权或测试 runner 环境受限时最多一次针对性修复重试，然后由 Luna 收尾审查决定补充证据或记录限制，不无限重试。
- 真实菜单栏适配未验证时必须明确标注，不用 image.isTemplate 断言冒充视觉验证。多屏/更多系统版本属于补充检查。
- 本阶段交付仅为计划，不代表修复已完成；下一动作是 Luna 执行单元 1 的回归测试及端到端分层接入。
