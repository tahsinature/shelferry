import Foundation

struct BuildInfo {
    let channel: String
    let date: Date?

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        channel = info["ShelferryBuildChannel"] as? String == "prod" ? "Prod" : "Dev"
        date = (info["ShelferryBuildDate"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    var exactDate: String {
        guard let date else { return "Build date unavailable" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        return "Built " + formatter.string(from: date)
    }

    func menuTitle(now: Date = Date()) -> String {
        "About Shelferry · \(channel) · \(age(now: now))"
    }

    private func age(now: Date) -> String {
        guard let date else { return "Build date unavailable" }
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 0 else { return "Build date is in the future" }
        if seconds < 60 { return "Built just now" }
        if seconds < 3_600 { return "Built \(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "Built \(Int(seconds / 3_600))h ago" }
        return "Built \(Int(seconds / 86_400))d ago"
    }
}
