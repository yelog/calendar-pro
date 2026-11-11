# Calendar Pro Release Checklist

- 验证菜单栏在默认模式下按分钟刷新，启用秒后按秒刷新。
- 验证点击菜单栏后可以展开和收起当前月日历面板。
- 校对中国大陆当年法定节假日和调休日期，至少覆盖春节、劳动节、国庆节。
- 每年第四季度核对下一年度是否已进入 `feed/holidays/manifest.json`，并运行 `python3 tools/sync_holidays.py --dry-run`。
- 确认仓库允许 GitHub Actions 创建 Pull Request，且 `sync-holidays` 工作流已成功创建或更新数据 PR；PR 合并后检查线上 `manifest.json` 包含目标年份。
- 验证线上 `manifest.json` 使用带时间的版本号，并确认 `mainland-cn-2027.json` 为 29 个放假日和 5 个调休上班日。
- 在 2027 年 2 月日历中确认 2 月 6 日显示春节、2 月 14 日显示调休上班。
- 校对香港当年公众假期数据，并确认缓存优先级高于内置数据。
- 在中文和英文系统语言下检查菜单栏星期、日期顺序和月历标题显示。
- 在时区切换后检查菜单栏文案和“今天”高亮是否同步刷新。
- 断网状态下执行一次远程节假日刷新，确认会回退到缓存或内置数据。
- 在设置页检查后台刷新成功、使用缓存和失败三种状态都有准确文案，不会把未联网说成“远程数据未更新”。
- 检查缺失年份会显示“尚未同步”提示，而不是“尚未发布”，且农历与周末仍正常显示。
- 检查设置页中的地区勾选和节假日集合勾选在重启后仍然生效。
- 发布后验证 `https://raw.githubusercontent.com/yelog/calendar-pro/main/docs/appcast.xml` 与 `https://raw.githubusercontent.com/yelog/calendar-pro/main/docs/appcast-beta.xml` 可访问，且包含当前版本条目。
- 如果历史版本使用过其他 Sparkle feed 地址，发布后确认旧地址不会返回 `404`；否则需要明确安排一次手动下载安装迁移。
