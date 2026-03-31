# Event Detail Window Enhancement - Design & Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 优化日程详情面板的信息架构和交互体验，使其更适合办公场景的高频使用。

**Architecture:** 新增 `MeetingLinkDetector` 纯函数服务从 event 的 URL/notes/location 中提取会议链接；重构 `EventDetailWindowView` 的信息层级，新增会议快捷入口、参会人列表、备注折叠、底部操作栏四个区域；所有新组件为独立 private struct，保持文件内聚。

**Tech Stack:** Swift, SwiftUI, EventKit, NSWorkspace, NSRegularExpression, XCTest

---

## Design

### 信息层级重构

当前布局（从上到下）：
```
header（标题 + 关闭按钮）
summaryCard（日期时间）
detailScrollView:
  所属日历
  地点
  链接
  备注（无限展开）
```

优化后布局：
```
header（标题 + 关闭按钮）
summaryCard（日期时间）
joinMeetingButton（条件显示：检测到会议链接时）    ← NEW
detailScrollView:
  所属日历
  地点（移除会议平台名称的冗余显示）
  参会人（折叠式，默认显示前3人）                  ← NEW
  链接
  备注（折叠式，默认显示前4行）                    ← ENHANCED
footerActions（在日历中打开）                      ← NEW
```

### 组件设计

#### 1. MeetingLinkDetector（纯逻辑服务）

从 `event.url`、`event.notes`、`event.location` 中提取会议链接：

```
支持的平台：
- Microsoft Teams: teams.microsoft.com/l/meetup-join/...
- Zoom: zoom.us/j/..., zoom.us/my/...
- Google Meet: meet.google.com/...
- Webex: webex.com/meet/..., webex.com/join/...
- 飞书/Lark: meetings.feishu.cn/..., vc.feishu.cn/...
- 腾讯会议: meeting.tencent.com/...
- 钉钉: meeting.dingtalk.com/...
```

返回 `MeetingLink?`（包含 `url: URL` 和 `platform: String`，如 "Microsoft Teams"）。

#### 2. JoinMeetingButton（醒目的操作按钮）

- 全宽圆角按钮，使用日历颜色作为背景
- 显示平台图标 + "加入 Teams 会议" 文案
- 点击后调用 `NSWorkspace.shared.open(url)`

#### 3. AttendeesRow（参会人列表）

- 读取 `event.attendees`（`[EKParticipant]?`）
- 每个参会人显示：姓名 + 出席状态图标（已接受=绿色勾, 待定=灰色问号, 已拒绝=红色叉）
- 默认显示前 3 人，超过 3 人时显示 "还有 N 人..." 可展开

#### 4. CollapsibleNotesRow（可折叠备注）

- 默认显示前 4 行（约 80 字符 x 4）
- 超出时底部叠加渐变遮罩 + "展开" 按钮
- 展开后显示完整内容 + "收起" 按钮
- 保留现有的 AttributedTextView 链接检测能力

#### 5. FooterActions（底部操作栏）

- 「在日历中打开」按钮，调用 `NSWorkspace.shared.open(calendarURL)` 跳转系统日历
- 使用 `calshow:` URL scheme 直接定位到对应事件的日期

---

### Task 1: 创建 MeetingLinkDetector 服务

**Files:**
- Create: `CalendarPro/Features/Events/MeetingLinkDetector.swift`
- Create: `CalendarProTests/Events/MeetingLinkDetectorTests.swift`

**Step 1: 创建 MeetingLinkDetector**

```swift
import EventKit
import Foundation

struct MeetingLink {
    let url: URL
    let platform: String
}

enum MeetingLinkDetector {
    private static let patterns: [(platform: String, regex: String)] = [
        ("Microsoft Teams", #"https?://teams\.microsoft\.com/l/meetup-join/[^\s<>\"]+"#),
        ("Zoom", #"https?://[\w.-]*zoom\.us/[jmy]/[^\s<>\"]+"#),
        ("Google Meet", #"https?://meet\.google\.com/[a-z\-]+"#),
        ("Webex", #"https?://[\w.-]*webex\.com/(meet|join)/[^\s<>\"]+"#),
        ("飞书", #"https?://(meetings|vc)\.feishu\.cn/[^\s<>\"]+"#),
        ("腾讯会议", #"https?://meeting\.tencent\.com/[^\s<>\"]+"#),
        ("钉钉", #"https?://meeting\.dingtalk\.com/[^\s<>\"]+"#),
    ]

    static func detect(in event: EKEvent) -> MeetingLink? {
        // 1. 优先检查 event.url
        if let url = event.url, let link = match(url: url) {
            return link
        }
        // 2. 从 notes 中提取
        if let notes = event.notes, let link = findInText(notes) {
            return link
        }
        // 3. 从 location 中提取
        if let location = event.location, let link = findInText(location) {
            return link
        }
        return nil
    }

    private static func match(url: URL) -> MeetingLink? {
        let urlString = url.absoluteString
        for (platform, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(urlString.startIndex..., in: urlString)
            if regex.firstMatch(in: urlString, range: range) != nil {
                return MeetingLink(url: url, platform: platform)
            }
        }
        return nil
    }

    private static func findInText(_ text: String) -> MeetingLink? {
        for (platform, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text),
               let url = URL(string: String(text[matchRange])) {
                return MeetingLink(url: url, platform: platform)
            }
        }
        return nil
    }
}
```

**Step 2: 创建单元测试**

```swift
import XCTest
@testable import CalendarPro

final class MeetingLinkDetectorTests: XCTestCase {
    func testDetectsTeamsLinkInNotes() {
        let url = MeetingLinkDetector.findInText(
            "Join: https://teams.microsoft.com/l/meetup-join/abc123"
        )
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.platform, "Microsoft Teams")
    }

    func testDetectsZoomLink() {
        let url = MeetingLinkDetector.findInText(
            "https://us02web.zoom.us/j/1234567890"
        )
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.platform, "Zoom")
    }

    func testDetectsGoogleMeetLink() {
        let url = MeetingLinkDetector.findInText(
            "https://meet.google.com/abc-defg-hij"
        )
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.platform, "Google Meet")
    }

    func testReturnsNilForPlainText() {
        let url = MeetingLinkDetector.findInText("Just a regular note")
        XCTAssertNil(url)
    }
}
```

**Step 3: 编译运行测试**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MeetingLinkDetectorTests -quiet`

**Step 4: Commit**

```bash
git add CalendarPro/Features/Events/MeetingLinkDetector.swift CalendarProTests/Events/MeetingLinkDetectorTests.swift
git commit -m "feat(events): add MeetingLinkDetector for extracting meeting URLs"
```

---

### Task 2: 重构 NotesDetailRow 为可折叠备注

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:226-268`

将现有的 `NotesDetailRow` 改为可折叠版本：

- 新增 `@State private var isExpanded: Bool = false`
- 默认 collapsed 状态显示 `lineLimit(4)` 的纯文本预览
- expanded 状态使用现有的 `AttributedTextView`（保留链接检测）
- 底部显示 "展开 / 收起" 切换按钮
- 使用渐变遮罩实现折叠态的视觉截断效果

**Step 1: 替换 NotesDetailRow 实现**

（完整代码见实施阶段）

**Step 2: 编译验证**

**Step 3: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift
git commit -m "feat(events): add collapsible notes with expand/collapse toggle"
```

---

### Task 3: 添加参会人列表组件

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift`

新增 `AttendeesDetailRow` private struct：

- 接收 `[EKParticipant]` 数组
- 每行显示：状态图标 + 姓名（`participant.name ?? participant.url.resourceSpecifier`）
- 状态映射：`.accepted` → green checkmark, `.tentative`/`.pending` → gray questionmark, `.declined` → red xmark
- 默认显示前 3 人，可展开

**Step 1: 实现 AttendeesDetailRow**

（完整代码见实施阶段）

**Step 2: 编译验证**

**Step 3: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift
git commit -m "feat(events): add attendees list with status indicators"
```

---

### Task 4: 添加会议快捷入口和底部操作栏

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:8-18` (body)

**Step 1: 在 summaryCard 和 detailScrollView 之间添加 joinMeetingButton**

条件显示：当 `MeetingLinkDetector.detect(in: event)` 返回非 nil 时，渲染按钮。

**Step 2: 在 detailScrollView 之后添加 footerActions**

显示「在日历中打开」按钮，使用 `calshow:` URL scheme + 事件日期的 timeIntervalSinceReferenceDate。

**Step 3: 编译验证**

**Step 4: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift
git commit -m "feat(events): add join meeting button and open-in-calendar action"
```

---

### Task 5: 整合布局并调整 detailScrollView 内容顺序

**Files:**
- Modify: `CalendarPro/Views/Popover/EventDetailWindowView.swift:75-100`

调整 detailScrollView 内部顺序为：
1. 所属日历
2. 地点（保留）
3. 参会人（新增，条件: `event.attendees?.isEmpty == false`）
4. 链接（保留）
5. 备注（使用折叠版本）

**Step 1: 更新 detailScrollView**

**Step 2: 编译验证**

**Step 3: Commit**

```bash
git add CalendarPro/Views/Popover/EventDetailWindowView.swift
git commit -m "refactor(events): reorganize detail view layout with new components"
```

---

### Task 6: 全量编译 + 测试验证

**Step 1: 编译**

Run: `xcodebuild build -scheme CalendarPro -destination 'platform=macOS' -quiet`

**Step 2: 运行全量测试**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -quiet`

**Step 3: Final commit (if any fixes needed)**
