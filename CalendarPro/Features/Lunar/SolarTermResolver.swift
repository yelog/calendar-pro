import Foundation

struct SolarTermResolver {
    // Chinese solar terms conventionally follow China Standard Time.
    func solarTermName(for date: Date, timeZone _: TimeZone = .autoupdatingCurrent) -> String? {
        let calendar = Self.gregorianCalendar(timeZone: Self.referenceTimeZone)
        let localDay = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: localDay)

        let occurrences =
            Self.occurrences(for: year - 1) +
            Self.occurrences(for: year) +
            Self.occurrences(for: year + 1)

        return occurrences.first(where: { calendar.isDate($0.instant, inSameDayAs: localDay) })?.term.displayName
    }

    private static let utc = TimeZone(secondsFromGMT: 0)!
    private static let referenceTimeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cachedOccurrences: [Int: [SolarTermOccurrence]] = [:]

    private static func occurrences(for year: Int) -> [SolarTermOccurrence] {
        cacheLock.lock()
        if let cached = cachedOccurrences[year] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let computed = SolarTerm.allCases.map { term in
            occurrence(for: term, in: year)
        }

        cacheLock.lock()
        cachedOccurrences[year] = computed
        cacheLock.unlock()

        return computed
    }

    private static func occurrence(for term: SolarTerm, in year: Int) -> SolarTermOccurrence {
        let approx = DateComponents(
            calendar: gregorianCalendar(timeZone: utc),
            timeZone: utc,
            year: year,
            month: term.approximateMonth,
            day: term.approximateDay,
            hour: 12
        ).date!

        var lowerBound = julianDay(from: approx) - 3
        var upperBound = julianDay(from: approx) + 3

        while signedAngleDifference(apparentSolarLongitude(julianDay: lowerBound), target: term.targetLongitude) > 0 {
            lowerBound -= 1
        }

        while signedAngleDifference(apparentSolarLongitude(julianDay: upperBound), target: term.targetLongitude) < 0 {
            upperBound += 1
        }

        for _ in 0..<80 {
            let midpoint = (lowerBound + upperBound) / 2
            let difference = signedAngleDifference(
                apparentSolarLongitude(julianDay: midpoint),
                target: term.targetLongitude
            )

            if difference < 0 {
                lowerBound = midpoint
            } else {
                upperBound = midpoint
            }
        }

        return SolarTermOccurrence(
            term: term,
            instant: date(from: (lowerBound + upperBound) / 2)
        )
    }

    private static func apparentSolarLongitude(julianDay: Double) -> Double {
        let julianCentury = (julianDay - 2451545.0) / 36525.0
        let meanLongitude = normalizedAngle(
            280.46646 +
                36000.76983 * julianCentury +
                0.0003032 * julianCentury * julianCentury
        )
        let meanAnomaly = normalizedAngle(
            357.52911 +
                35999.05029 * julianCentury -
                0.0001537 * julianCentury * julianCentury
        )
        let omega = 125.04 - 1934.136 * julianCentury
        let equationOfCenter =
            (1.914602 - 0.004817 * julianCentury - 0.000014 * julianCentury * julianCentury) * sin(radians(from: meanAnomaly)) +
            (0.019993 - 0.000101 * julianCentury) * sin(radians(from: 2 * meanAnomaly)) +
            0.000289 * sin(radians(from: 3 * meanAnomaly))
        let trueLongitude = meanLongitude + equationOfCenter
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(radians(from: omega))

        return normalizedAngle(apparentLongitude)
    }

    private static func signedAngleDifference(_ value: Double, target: Double) -> Double {
        normalizedAngle(value - target + 180) - 180
    }

    private static func normalizedAngle(_ angle: Double) -> Double {
        let value = angle.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }

    private static func radians(from degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func julianDay(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private static func date(from julianDay: Double) -> Date {
        Date(timeIntervalSince1970: (julianDay - 2_440_587.5) * 86_400)
    }

    private static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

private struct SolarTermOccurrence {
    let term: SolarTerm
    let instant: Date
}

private enum SolarTerm: CaseIterable {
    case minorCold
    case majorCold
    case beginningOfSpring
    case rainWater
    case awakeningOfInsects
    case springEquinox
    case pureBrightness
    case grainRain
    case beginningOfSummer
    case grainFull
    case grainInEar
    case summerSolstice
    case minorHeat
    case majorHeat
    case beginningOfAutumn
    case limitOfHeat
    case whiteDew
    case autumnEquinox
    case coldDew
    case frostDescent
    case beginningOfWinter
    case minorSnow
    case majorSnow
    case winterSolstice

    var displayName: String {
        switch self {
        case .minorCold:
            return "小寒"
        case .majorCold:
            return "大寒"
        case .beginningOfSpring:
            return "立春"
        case .rainWater:
            return "雨水"
        case .awakeningOfInsects:
            return "惊蛰"
        case .springEquinox:
            return "春分"
        case .pureBrightness:
            return "清明"
        case .grainRain:
            return "谷雨"
        case .beginningOfSummer:
            return "立夏"
        case .grainFull:
            return "小满"
        case .grainInEar:
            return "芒种"
        case .summerSolstice:
            return "夏至"
        case .minorHeat:
            return "小暑"
        case .majorHeat:
            return "大暑"
        case .beginningOfAutumn:
            return "立秋"
        case .limitOfHeat:
            return "处暑"
        case .whiteDew:
            return "白露"
        case .autumnEquinox:
            return "秋分"
        case .coldDew:
            return "寒露"
        case .frostDescent:
            return "霜降"
        case .beginningOfWinter:
            return "立冬"
        case .minorSnow:
            return "小雪"
        case .majorSnow:
            return "大雪"
        case .winterSolstice:
            return "冬至"
        }
    }

    var targetLongitude: Double {
        switch self {
        case .minorCold:
            return 285
        case .majorCold:
            return 300
        case .beginningOfSpring:
            return 315
        case .rainWater:
            return 330
        case .awakeningOfInsects:
            return 345
        case .springEquinox:
            return 0
        case .pureBrightness:
            return 15
        case .grainRain:
            return 30
        case .beginningOfSummer:
            return 45
        case .grainFull:
            return 60
        case .grainInEar:
            return 75
        case .summerSolstice:
            return 90
        case .minorHeat:
            return 105
        case .majorHeat:
            return 120
        case .beginningOfAutumn:
            return 135
        case .limitOfHeat:
            return 150
        case .whiteDew:
            return 165
        case .autumnEquinox:
            return 180
        case .coldDew:
            return 195
        case .frostDescent:
            return 210
        case .beginningOfWinter:
            return 225
        case .minorSnow:
            return 240
        case .majorSnow:
            return 255
        case .winterSolstice:
            return 270
        }
    }

    var approximateMonth: Int {
        switch self {
        case .minorCold, .majorCold:
            return 1
        case .beginningOfSpring, .rainWater:
            return 2
        case .awakeningOfInsects, .springEquinox:
            return 3
        case .pureBrightness, .grainRain:
            return 4
        case .beginningOfSummer, .grainFull:
            return 5
        case .grainInEar, .summerSolstice:
            return 6
        case .minorHeat, .majorHeat:
            return 7
        case .beginningOfAutumn, .limitOfHeat:
            return 8
        case .whiteDew, .autumnEquinox:
            return 9
        case .coldDew, .frostDescent:
            return 10
        case .beginningOfWinter, .minorSnow:
            return 11
        case .majorSnow, .winterSolstice:
            return 12
        }
    }

    var approximateDay: Int {
        switch self {
        case .minorCold:
            return 5
        case .majorCold:
            return 20
        case .beginningOfSpring:
            return 4
        case .rainWater:
            return 19
        case .awakeningOfInsects:
            return 5
        case .springEquinox:
            return 20
        case .pureBrightness:
            return 4
        case .grainRain:
            return 20
        case .beginningOfSummer:
            return 5
        case .grainFull:
            return 21
        case .grainInEar:
            return 5
        case .summerSolstice:
            return 21
        case .minorHeat:
            return 7
        case .majorHeat:
            return 23
        case .beginningOfAutumn:
            return 7
        case .limitOfHeat:
            return 23
        case .whiteDew:
            return 7
        case .autumnEquinox:
            return 23
        case .coldDew:
            return 8
        case .frostDescent:
            return 23
        case .beginningOfWinter:
            return 7
        case .minorSnow:
            return 22
        case .majorSnow:
            return 7
        case .winterSolstice:
            return 21
        }
    }
}
