# Changelog

All notable changes to CalendarPro will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1-beta.2] - 2026-04-05

### Fixed

- align minute refresh to wall-clock boundary to prevent menu bar clock lag
- add system clock change notification for immediate menu bar resync
- restore manual settings window for reliable opening in menu bar app
- default update channel to stable

### Added

- add chineseFull date format (yyyy年MM月dd日)

## [0.1.1-beta.1] - 2026-04-04

### Added

- add stable and beta channel switching

### Fixed

- deliver system notifications on the main queue

## [0.1.1-beta.0] - 2026-04-02

### Added

- add Chinese almanac (宜忌) display in popover
- add weekend highlight with settings toggle
- use Chinese weekday symbols in calendar grid
- add week start day picker UI
- support solar terms in calendar
- support selecting detail text
- unify events visibility controls
- add dynamic height adjustment for event detail window
- add current-time event timeline
- enhance today cell styling with golden badge and background
- add PopoverDidClose notification listener and check on appear
- send PopoverDidClose notification when popover closes
- add lastClosedTime tracking and auto-reset logic to ViewModel
- add PopoverDidClose notification name

### Changed

- add design plans for removing weather feature
- add tyme dependency and update Xcode project settings
- add unified events settings design
- update appcast URLs to use raw.githubusercontent.com
- extract appcast feed URL logic for testability
- add project README
- add implementation plan for auto-reset-to-today
- add auto-reset-to-today feature design
- add 0.1.0 release entry [skip ci]

### Fixed

- prevent status item disappearance on display changes
- redesign current time marker layout
- simplify selected-day header summary
- place now marker by displayed time
- center resizable window on active screen
- position settings window near popover instead of screen center
- make entire button area clickable in footer buttons
- rebalance settings window layout

## [0.1.0] - 2026-03-31

### Added

- add Sparkle auto-update support and About settings page
- add app icon from calendar-pro.png
- show reminder detail panel on click with content-adaptive sizing
- open reminder in Reminders.app on click
- enhance event detail window with meeting join, attendees, and collapsible notes
- add MeetingLinkDetector for meeting URL extraction
- add configurable lunar display style (day/monthDay/yearMonthDay)
- auto-refresh on external calendar/reminder changes
- enable GitHub-hosted remote holiday feed
- add launch-at-login toggle to general settings
- 菜单栏样式下拉选项显示实时预览
- add year and month picker panels with clickable header
- add checkbox toggle to mark reminders as complete
- auto-scroll event list to ongoing or next upcoming item
- support chinese date format in menu bar
- open event detail in separate window
- improve popover interaction handling and event selection
- add reminders permission description and entitlement
- add CalendarItem enum to unify events and reminders
- add reminders fetching support to EventService
- add reminders settings UI to EventsSettingsView
- display menu bar icon on all screens
- integrate EventService and EventListView into calendar popover
- add date selection interaction to CalendarGridView
- create EventListView for event list display
- create EventCardView for event display
- create EventService for EventKit access
- add event and reminders settings to MenuBarPreferences
- add EventKit permission descriptions
- add today button, improve holiday styling
- add toolbar with settings and quit buttons

### Changed

- redesign settings with custom sidebar and summary cards
- replace TabView with NavigationSplitView sidebar layout
- restructure settings layout with ScrollView and grouped sections
- move lunar format selection to display tokens section
- simplify status bar and improve notes display
- improve event detail window styling
- simplify calendar groups sorting logic
- group calendars by source
- inject EventService via AppDelegate for shared instance
- remove redundant 'showsSeconds' toggle control

### Fixed

- simplify Settings scene and remove deprecated lunarDisplayStyle test param
- default notes to expanded and fix background card sizing
- prevent double event detail window close on popover dismiss
- close event detail window before closing popover
- hide style picker for lunar and holiday tokens
- remove duplicate style option for time token
- correct timer granularity when time style is full
- remove thousand separator from year display in month picker
- show lunar text for months crossing year boundaries
- scroll to last event when no future events today
- sort items by time-of-day instead of full date
- group same-time events into one card and add scroll to prevent overflow
- show lunar text instead of badge for working adjustment days
- align event detail window with popover content top
- fix reminders not showing in event list
- constrain event detail window height to screen bounds
- fix notes not fully displayed in event detail
- avoid clipping holiday badges
- avoid reminder fetch crash on launch
- menu bar style changes not reflecting immediately
- load events immediately after calendar authorization granted
- bring settings window to front when clicking settings button
- auto-grow popover height based on content, add max height for event list
