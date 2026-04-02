import Foundation
import tyme

struct AlmanacDescriptor: Equatable {
    let recommends: [String]
    let avoids: [String]
    let dutyName: String
    let naYin: String

    var hasContent: Bool {
        !recommends.isEmpty || !avoids.isEmpty
    }

    var recommendsText: String {
        recommends.joined(separator: "·")
    }

    var avoidsText: String {
        avoids.joined(separator: "·")
    }
}

struct AlmanacService {
    func describe(date: Date) -> AlmanacDescriptor {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        guard let solarDay = try? SolarDay.fromYmd(year, month, day) else {
            return AlmanacDescriptor(recommends: [], avoids: [], dutyName: "", naYin: "")
        }

        let cycleDay = solarDay.sixtyCycleDay

        let recommends = cycleDay.recommends.map { $0.getName() }
        let avoids = cycleDay.avoids.map { $0.getName() }
        let dutyName = cycleDay.duty.getName()
        let naYin = cycleDay.naYin.getName()

        return AlmanacDescriptor(
            recommends: recommends,
            avoids: avoids,
            dutyName: dutyName,
            naYin: naYin
        )
    }
}
