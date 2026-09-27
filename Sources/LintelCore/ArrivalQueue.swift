/// 需要你注意的事件排队（从许愿柳 `Model/ArrivalQueue.swift` 原样搬来）。
///
/// 两项先后到达时，后到的不顶掉正在展开的那个——你读到一半的内容不会被换走；当前这个收起后再轮到它。
public struct ArrivalQueue: Equatable, Sendable {
    public private(set) var waiting: [String] = []

    public init() {}

    /// 返回 true = 现在就展示；false = 已排队（或本来就在展示）。
    public mutating func offer(_ id: String, showing: String?) -> Bool {
        guard let showing else { return true }
        if showing == id { return false }
        if !waiting.contains(id) { waiting.append(id) }
        return false
    }

    /// 合并：只取最新那个还值得展示的，其余丢掉（弹卡冷却期间攒下的不逐个弹，作者 09-21：「非常闪烁」）。
    public mutating func latest(alive: Set<String>) -> String? {
        let pick = waiting.last(where: { alive.contains($0) })
        waiting.removeAll()
        return pick
    }

    /// 两个来源各排各的（作者 09-22）：每发一条消息，许愿柳和写作循环都会弹，只取最新一条会吞掉其中一个。
    /// 每次取一个来源：刚弹过的来源（`after`）排到最后，轮流弹，不让一个来源一直插在前面（grill 09-22：许愿柳连弹时写作循环
    /// 一直轮不到）；其余先按 `order`（许愿柳在前），不在 `order` 里的按最早到达。取它排队里最新的那一条（同一来源内仍按 09-21
    /// 只弹最新），丢掉它更早的；别的来源留在队里，下一次冷却到期再弹。
    public mutating func nextBySource(alive: Set<String>, order: [String], after: String? = nil) -> String? {
        waiting.removeAll { !alive.contains($0) }
        guard !waiting.isEmpty else { return nil }
        func rank(_ s: String) -> (Int, Int, Int) {
            (s == after ? 1 : 0, order.firstIndex(of: s) ?? order.count, waiting.firstIndex { Self.source(of: $0) == s } ?? 0)
        }
        let sources = Set(waiting.map(Self.source(of:)))
        guard let pickSource = sources.min(by: { rank($0) < rank($1) }),
              let pick = waiting.last(where: { Self.source(of: $0) == pickSource }) else { return nil }
        waiting.removeAll { Self.source(of: $0) == pickSource }
        return pick
    }

    /// 活动 id 是「来源/活动」（`Hosted.id`）。
    public static func source(of id: String) -> String {
        id.split(separator: "/", maxSplits: 1).first.map(String.init) ?? id
    }

    /// 取下一个还值得展示的；等待期间结束了的直接丢掉。
    public mutating func next(alive: Set<String>) -> String? {
        while let first = waiting.first {
            waiting.removeFirst()
            if alive.contains(first) { return first }
        }
        return nil
    }
}
