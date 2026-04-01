# Calendar Pro Release Checklist

- 验证菜单栏在默认模式下按分钟刷新，启用秒后按秒刷新。
- 验证点击菜单栏后可以展开和收起当前月日历面板。
- 校对中国大陆当年法定节假日和调休日期，至少覆盖春节、劳动节、国庆节。
- 校对香港当年公众假期数据，并确认缓存优先级高于内置数据。
- 在中文和英文系统语言下检查菜单栏星期、日期顺序和月历标题显示。
- 在时区切换后检查菜单栏文案和“今天”高亮是否同步刷新。
- 断网状态下执行一次远程节假日刷新，确认会回退到缓存或内置数据。
- 检查设置页中的地区勾选和节假日集合勾选在重启后仍然生效。
- 发布后验证 `https://raw.githubusercontent.com/yelog/calendar-pro/main/docs/appcast.xml` 与 `https://raw.githubusercontent.com/yelog/calendar-pro/main/docs/appcast-beta.xml` 可访问，且包含当前版本条目。
- 如果历史版本使用过其他 Sparkle feed 地址，发布后确认旧地址不会返回 `404`；否则需要明确安排一次手动下载安装迁移。
