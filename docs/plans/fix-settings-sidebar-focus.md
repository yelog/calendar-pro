# 设置导航焦点消歧 Implementation Plan

**执行角色：** Astra 完成此计划；Luna 负责后续实现、验证、审查及获准阶段的提交合并。
**Goal：** 点击设置导航后消除旧项焦点残留，同时让页面选中与键盘焦点有明确不同的视觉含义。
**Architecture：** 保留现有自定义侧边栏和单一 `selectedItem`；通过局部 `FocusState` 在按钮激活时迁移焦点；页面选中使用浅底和短竖标记，原生外圈仅表达键盘焦点。
**Tech Stack：** Swift 6、SwiftUI、AppKit，最低 macOS 14.0。

---

## 基线与执行约束

- 工作区：`/Users/yelog/workspace/swift/calendar-pro`。
- 目标分支：`main`；指定起点：`95c07082f3b188399a25ae618e57977f878cd0d2`。
- 分析时 HEAD 与起点一致，工作区/index 干净；没有依赖未提交修改。实施前重新检查真实状态，如出现本地变更不得覆盖、stash 或直接带入其他 worktree。
- 推荐任务名称：**设置导航焦点消歧**；推荐分支：`fix/settings-sidebar-focus`。由 Luna 在计划后按工作流创建，本阶段未创建。
- 原因与方案比较见同目录 `analysis.md`；本计划落实已选方案，不重复调查全部代码。
- 本阶段任务目录中没有 `checkpoint.json`，不创建或修改它。报告、计划、截图和验证记录仅写本任务目录；不修改 `state.json`。
- 本轮 plan 完成回执：`plan-e889d125-a9f0-476e-bed1-bd24bc6cf06e.json`，token 为 `e889d125-a9f0-476e-bed1-bd24bc6cf06e`；最后写入，不覆盖历史回执。
- 本轮重新读取 analysis 并调用 writing-plans 技能；重新检查 HEAD 仍为指定起点、工作区/index 干净。没有未提交依赖需要带入任务 worktree。
- `change-scope.json` 列出实施阶段预计变更的仓库文件，仅 `CalendarPro/Views/Settings/SettingsRootView.swift`。任务目录内的报告/计划/回执属于工作流产物，不作为待提交源文件列入；本轮不新增 `docs/plans/` 文档。

## 验证分级：必需项与补充建议

此分级细化并优先于 analysis 中较宽泛的验收矩阵，不把设计师新提出的人工检查自动升级为项目门禁。

| 级别与依据 | 要求 | 完成/限制处理 |
| --- | --- | --- |
| 用户需求，产品验收 | 点击日程后显示日程，通用无误导性旧焦点强调；当前页选中提示明确；提供并落实设计改进 | 必须实施；用可获得的定向证据评估，源码推断不能写成已实测 |
| 项目约定与本工作流验证要求 | 执行构建；功能齐备后执行现有全量测试；设置页改动提供手动验证说明；提交 PR 时按 AGENTS.md 附截图或录屏 | 记录真实退出码和结果；环境受限项单独标出，由 Luna 收尾审查，不隐瞒或无限重试 |
| 所选方案的代码复核要求 | 保留 Button 语义与原生焦点；Tab 不被绑定成自动切页；不抢详情焦点；唯一 selected trait；装饰不拦截点击 | 复核实际 diff，属于保证修复不引入回退的实现质量要求 |
| 补充建议验证，非新强制门禁 | Tab/Space 的完整人工路径、全部六项和留白点击、VoiceOver/Inspector、浅深色和非蓝强调色/提高对比度、最小窗口、重开窗口、多系统版本 | 有条件执行；缺少环境可记录未执行，不为这些建议引入额外批准流程或反复要求用户操作 |

项目要求的手动验证说明应至少交代“通用→日程”的复现步骤、预期结果和实际验证状态。第二张键盘对比截图、固定截图数量及完整人工矩阵是补充建议，不是用户新增的必需门禁。无法采集 UI 证据时明确限制，不能声称已证明焦点环消失。

## 唯一端到端单元：页面选择与焦点语义一致

完成下面步骤后，交付一个可独立验收的修复，不拆出需要后续拼接才能工作的半成品。

### 步骤 1：确认基线与运行现象

执行：

```sh
git status --porcelain=v1 --untracked-files=all
git rev-parse HEAD
```

记录当前提交与本地差异，确认实施文件是否被用户修改。

在可用的本地 App 中打开设置，点击“通用→日程”，确认旧通用蓝圈是否仍存在；记录系统版本、系统键盘导航设置与实际焦点目标。用户图片没有随上下文提供，分析阶段尚未实测，不能声称已复现。

若没有可用 App，将运行确认与步骤 4 的构建后检查合并，不为收集基线反复启动环境。无 GUI/权限时明确记录限制，继续可执行工作。

### 步骤 2：修复按钮激活时焦点迁移

**修改文件：** `CalendarPro/Views/Settings/SettingsRootView.swift`。

在 `SettingsRootView` 的 `selectedItem` 附近增加：

```swift
@FocusState private var focusedSidebarItem: SettingsSidebarItem?
```

将侧边栏 `ForEach` 中的 Button 调整为：

```swift
Button {
    selectedItem = item
    focusedSidebarItem = item
} label: {
    SettingsSidebarButton(item: item, isSelected: item == selectedItem)
}
.buttonStyle(.plain)
.focused($focusedSidebarItem, equals: item)
.accessibilityAddTraits(item == selectedItem ? [.isSelected] : [])
```

设计契约：

- `selectedItem` 仍是唯一页面状态，详情标题、内容路由不变。
- 激活按钮才切页；Tab/Shift-Tab 只移动焦点。
- 不添加焦点变化→选中变化的监听，不在 onAppear 强制聚焦，不把焦点绑到 label 容器。
- 保留原生 Button 与原生焦点效果；不禁用可聚焦性，不调用窗口级 first responder 清空，不新增输入设备事件监听。
- 若编译对 trait 字面量推断有异议，使用显式 `AccessibilityTraits` 类型修正，保持仅选中按钮具有 `.isSelected` 的语义。

### 步骤 3：让页面选中和键盘焦点使用不同形状

**同一文件：** `SettingsSidebarButton.body` 与 `SettingsWindowPalette`。

保留现有选中浅色填充、图标配色和 14pt 圆角；将现有 selectedStroke 外围 overlay 替换为：

```swift
.overlay(alignment: .leading) {
    if isSelected {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 3, height: 18)
            .padding(.leading, 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
```

删除不再使用的 `SettingsWindowPalette.selectedStroke`。

- 选中为“浅底＋短竖标记”，焦点为系统轮廓，二者可同时出现在同一行。
- Tab 聚焦其他项时，当前页面标记留在原项，焦点圈可移动到新项。这是预期行为，不是新的双选缺陷。
- 标记不占用布局空间，不阻挡鼠标，不单独被辅助技术朗读。
- 保持系统动态 accentColor，禁止硬编码蓝色；保持原有 sidebar 宽度、间距、标题及详情布局。

预计只改一个已有 Swift 文件，不新增/删除源码文件，因此不需重建 Xcode project。无需修改 AppDelegate、SettingsStore、EventService 或其他设置分区。

### 步骤 4：构建与定向交互验证

执行：

```sh
xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

预期退出 0。普通编译失败就地修复后重跑相关构建。

定向检查清单（第 2 项直接对应用户问题；其余为方案回归建议，是否完成分别记录）：

1. 打开设置默认通用，只有通用有选中短标记。
2. 点击日程：标题/内容与日程一致，日程唯一选中，通用无残留焦点圈。
3. 点击全部六项，点击当前项，以及分别点击文字、图标、留白；行为一致。
4. 系统键盘导航开启时 Tab/Shift-Tab 顺序合理，有可见焦点，不自动切页；Space 激活后页面切换正确。
5. 焦点进入详情输入控件后不被 sidebar 抢回，页面选中短标记仍正确。

补充视觉/可访问性回归（不新增强制人工门禁）：

- 浅色、深色、非蓝强调色、提高对比度状态下区分两种提示。
- VoiceOver 检查按钮名称、唯一 selected 语义和装饰隐藏。
- 最小窗口 760×520 下无布局位移或遮挡。
- 窗口失焦再激活、关闭重开没有错误残留。
- 日历权限未授予时仍能切换导航；不为本修复引入新权限要求。

按项目 UI 改动要求，在可用环境采集当前修改后的 App 截图或录屏到任务目录，优先展示鼠标选中日程。建议额外采集 Tab 聚焦另一项但未激活的对比图，不规定必须两张；无法采集时记录限制供 Luna 收尾审查。

### 步骤 5：现有测试回归

功能齐备后执行一次：

```sh
xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'
```

预期退出 0。共享 scheme 包括单元与 UI 测试。现有 UI 测试仅覆盖月历烟测，测试通过不能替代步骤 4 对设置焦点的实测。

该修复是局部、可逆的 UI 状态绑定和样式调整，不新增镜像实现的枚举赋值测试，不为一次修复引入完整设置 UI 测试启动架构。若实际实现扩大到自定义焦点控制器或复杂状态逻辑，应先审查扩大原因，再为真实行为增加对应测试。

### 步骤 6：审查与收尾

检查实际 diff：

- 修改局限于必要的视图状态、焦点绑定、selected trait 与选中标记。
- 无全局焦点禁用，无窗口焦点重置，无 Tab 即切页，无详情焦点抢夺。
- 无未使用 palette 属性，无布局尺寸变化，无新增持久化/权限逻辑。
- 无依赖只存在原工作区的未提交行为。

更新本任务目录 `validation.md`，记录每条实际命令、退出码、提交/工作区差异、环境、截图路径以及未执行项。不得把分析阶段工具链查询或源码推断当作修复验证。

后续提交/合并仅在工作流进入相应阶段时由 Luna 执行。建议提交主题：

```text
fix(settings): distinguish sidebar selection from keyboard focus
```

## 环境限制与修正边界

- 用户需求、项目约定和工作流验证要求按上方分级表逐项记录完成或限制；必需的是实现正确且如实交代证据，不是把所有新提议的人工路径逐一跑完。
- Accessibility Inspector、VoiceOver 人工验证与更广泛的外观/系统矩阵属于补充证据，不因缺少这些环境把任务自动判为 blocked。
- GUI、PTY 或系统权限限制最多做一次有针对性的环境修复重试，再由 Luna 收尾审查决定替代证据和剩余限制，不持续无限 progress。
- 若目标系统上 `.focused` 绑定没有按预期迁移原生 Button 焦点，先确认绑定挂在真实 Button、系统键盘导航状态和实际焦点对象，再做局部纠正；不能用隐藏所有焦点圈作为通过验收的捷径。
- 普通实现错误不是阻塞，继续修正。只有缺少必要外部输入、权限或互斥产品决定才按工作流报告阻塞。
- 验证通过后不重复全量检查，除非代码、环境或新失败使旧结果失效。

## 完成定义

鼠标切页后旧项无误导性焦点残留；页面选中、键盘焦点具有不同视觉形状；键盘与辅助技术语义不回退；相关构建、回归和交互检查有真实证据或明确限制；业务逻辑保持原有行为。最终是否验收由 Luna 根据实现证据审查决定。
