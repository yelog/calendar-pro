# Menu Bar Event Indicator Two-Row Design

## Context

CalendarPro renders its menu bar text and upcoming event indicators into a single `NSImage` through `MenuBarTextImageRenderer`. Upcoming and ongoing events are represented as colored circular dots to the right of the date and time text. The event monitor already caps visible dots at three active items.

The current horizontal dot layout consumes unnecessary menu bar width when two or three events are active.

## Requirements

- Keep the existing maximum of three visible event dots.
- Keep the existing event filtering, color, filled/outlined status, tooltip, and accessibility behavior.
- Keep the single-dot layout unchanged.
- When at least two dots are present, render dots in two rows.
- Preserve the visual order as column-major: first top, second bottom, third top in the next column.
- Reduce horizontal space used by two or three dots without adding user-facing settings.

## Recommended Design

Change only `MenuBarTextImageRenderer` so the indicator layout becomes responsive to dot count:

- `0` dots: no indicator width.
- `1` dot: one centered dot, matching current behavior.
- `2` dots: one column with top and bottom dots.
- `3` dots: two columns, with the first column filled top-to-bottom and the second column starting at the top.

The dot size stays at `6pt`. The gap between text and indicators stays at `6pt`. Column spacing stays close to the current dot spacing. Row spacing should be small enough to fit within normal macOS status bar image height while still making the two rows visually distinct.

## Alternatives Considered

### Reduce Horizontal Spacing Only

This has the smallest code change, but it does not solve the core problem because the dots still grow horizontally with event count.

### Replace Multiple Dots With A Count Badge

This saves the most width, but loses per-event calendar colors and ongoing/upcoming state. That weakens the current glanceable indicator semantics.

### Two-Row Column-Major Layout

This is the chosen option because it preserves the existing semantics while reducing width for multiple active events.

## Implementation Notes

- Main file: `CalendarPro/Features/MenuBar/ClockRenderService.swift`.
- Tests: `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`.
- The change should stay local to image rendering.
- No preference schema changes are needed.
- No Xcode project regeneration is needed because no source or test files are added.

## Validation

- Add renderer tests for multi-dot width behavior.
- Run `xcodebuild test -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS'`.
