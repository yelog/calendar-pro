# Repository Guidelines

## Project Structure & Module Organization
`CalendarPro/` 是主应用源码，按职责拆分为 `App/`、`Features/`、`Infrastructure/Data/`、`Settings/`、`Views/` 与 `Resources/`。单元测试放在 `CalendarProTests/`，UI 测试放在 `CalendarProUITests/`，目录结构通常与生产代码一一对应。设计与实现记录集中在 `docs/plans/`，发布相关文件位于 `docs/`，节假日远程数据样例在 `feed/holidays/`，打包与签名脚本在 `scripts/build/`。

## Build, Test, and Development Commands
使用 Xcode 打开工程：`open CalendarPro.xcodeproj`。命令行构建：`xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`。完整测试：`xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`。打包 DMG：`bash scripts/build/package-app.sh`。如果新增或删除源码/测试文件，运行 `ruby tools/generate_xcodeproj.rb` 以重建 `CalendarPro.xcodeproj`。

## Coding Style & Naming Conventions
项目使用 Swift 6、4 空格缩进，遵循现有 SwiftUI 与 AppKit 混合架构。类型名使用 `UpperCamelCase`，方法、属性和局部变量使用 `lowerCamelCase`，测试辅助方法常用 `makeDate`、`makePreview` 这类命名。将桌面壳层逻辑保留在 `App/`，业务逻辑放入对应 `Features/` 子目录，避免跨模块堆放文件。仓库未接入强制格式化工具，提交前按周边代码风格手动整理。

## Testing Guidelines
测试框架为 `XCTest`，共享 scheme 会同时运行单元测试和 UI 测试。新增功能时，优先在对应目录补测试，例如 `CalendarPro/Features/Calendar/` 对应 `CalendarProTests/Calendar/`。测试名采用 `test<Behavior>` 形式，并尽量注入固定日期、时区和依赖，避免脆弱用例。涉及菜单栏、弹层、设置页、权限或更新通道的改动，除自动化测试外还应补充手动验证说明。

## Commit & Pull Request Guidelines
提交信息遵循 Conventional Commits，参考历史：`feat(updates): ...`、`fix(menu-bar): ...`、`chore: release v0.1.1-beta.1`。每个 PR 应聚焦单一主题，并同时包含相关测试与必要文档更新。PR 描述至少写清变更摘要、验证方式、关联 issue；涉及菜单栏、月历弹层、设置页或详情窗口的 UI 改动，请附截图或录屏。若修改节假日源、Sparkle 更新或发布流程，同步检查 `feed/holidays/`、`docs/appcast*.xml`、`CHANGELOG.md` 与相关脚本。

## Release & Configuration Notes
应用依赖日历、提醒事项和登录项权限，改动相关功能时请在说明中写清需要的系统授权与回归步骤。`scripts/build/package-app.sh` 可完成本地打包，正式签名与公证依赖 `CODESIGN_ENABLED`、`APPLE_TEAM_ID`、`APPLE_ID` 与 `APPLE_APP_PASSWORD`。Sparkle 更新源固定为 `docs/appcast.xml` 与 `docs/appcast-beta.xml`；调整发布通道、版本号或下载地址时，务必同时校对 appcast 内容与发布清单。

## Documentation & Planning
较大的交互或行为变更通常会在 `docs/plans/` 下维护成对文档：`YYYY-MM-DD-<topic>-design.md` 与实现记录。变更若影响现有设计假设，更新对应计划文档，而不是只改代码不留背景。
