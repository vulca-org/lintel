import Foundation

/// 同一时刻谁上刘海、谁进胶囊、翻页翻到谁。从许愿柳 `UI/FocusRule.swift` 拆出排序与配对的那一半，
/// 改成只看活动字段（阶段、自标不一致、在进行、看过没有），不认识任何许愿柳概念。
///
/// 全部按事实排，没有一条按内容挑：异常最优先，然后等你、刚发生的事、没看过且自标不一致、没看过，否则最近动静的那个。
/// 「看过」压过「自标不一致」：提醒的任务是让你去看，你看过了它就该安静。
@MainActor
public enum Ordering {
    /// 活的在前；再按最近一次动静。
    nonisolated public static func sorted(_ xs: [Hosted]) -> [Hosted] {
        xs.sorted { a, b in
            if a.activity.stale != b.activity.stale { return !a.activity.stale }
            return (a.activity.activityAt ?? .distantPast) > (b.activity.activityAt ?? .distantPast)
        }
    }

    /// 上刘海排队的：活的，且没有嵌进一件开着的活动里（嵌着的画在那件里面，见 `children`）。
    public static func live(_ xs: [Hosted]) -> [Hosted] {
        let a = awake(xs)
        return a.filter { parent(of: $0, among: a) == nil }
    }

    /// 活的，嵌着的也算：钉住的（弹卡、从面板点进去）要从这里找。
    public static func awake(_ xs: [Hosted]) -> [Hosted] { xs.filter { !$0.activity.stale } }

    // MARK: 嵌套（作者 09-24：稿件嵌在正在改它的对话里）

    /// 嵌着 h 的那件：开着、活的；主会话先于历史会话，同一种里取最近动过的。没有就 nil（h 照旧单独上刘海）。
    public static func parent(of h: Hosted, in xs: [Hosted]) -> Hosted? { parent(of: h, among: awake(xs)) }

    static func parent(of h: Hosted, among awake: [Hosted]) -> Hosted? {
        guard let links = h.activity.within, !links.isEmpty else { return nil }
        let hits = links.enumerated().compactMap { i, l -> (Int, Hosted)? in
            awake.first { $0.id == l.hostedId && $0.activity.open && $0.id != h.id }.map { ((l.role ?? .primary) == .primary ? 0 : 1, $0) }
        }
        return hits.min { a, b in
            a.0 != b.0 ? a.0 < b.0 : (a.1.activity.activityAt ?? .distantPast) > (b.1.activity.activityAt ?? .distantPast)
        }?.1
    }

    /// 嵌在 p 里的活动（按上刘海的先后）。
    public static func children(of p: Hosted, in xs: [Hosted]) -> [Hosted] {
        let a = awake(xs)
        return a.filter { $0.id != p.id && parent(of: $0, among: a)?.id == p.id }
    }

    /// 连同嵌在里面的一起算的急缓：稿件跑挂了，嵌着它的对话就按跑挂了排（不然急事藏在胶囊里的对话底下）。
    public static func effectiveRank(_ h: Hosted, in xs: [Hosted]) -> Activity.Rank {
        ([h] + children(of: h, in: xs)).map(\.activity.rank).min { order($0) < order($1) } ?? h.activity.rank
    }

    static func order(_ r: Activity.Rank) -> Int { switch r { case .anomaly: 0; case .waiting: 1; case .event: 2; case .none: 3 } }

    static func effectiveFlagged(_ h: Hosted, in xs: [Hosted]) -> Bool {
        h.activity.flagged || children(of: h, in: xs).contains { $0.activity.flagged }
    }

    public static func focus(_ xs: [Hosted], _ seen: SeenStore, pinned: String? = nil) -> Hosted? {
        let l = live(xs)
        if let pinned, let p = awake(xs).first(where: { $0.id == pinned }) { return p }
        let rank = { (h: Hosted) in effectiveRank(h, in: xs) }
        let rules: [(Hosted) -> Bool] = [
            { rank($0) == .anomaly },
            { rank($0) == .waiting },
            { rank($0) == .event },
            { seen.isUnread($0) && effectiveFlagged($0, in: xs) },
            { seen.isUnread($0) },
        ]
        for rule in rules { if let hit = l.first(where: rule) { return hit } }
        return l.first
    }

    /// 一项为什么被选成主项：与 `focus` 同一套规则，说出命中的是哪一条（09-28 面板 grill 第三轮 R6：弹出框落在哪场对话看起来会跳，
    /// 其实是「没看过的新一轮」把它拉了过去，面板上没有任何记号说明）。都不命中是 nil：只是排在前面。
    /// 要在标记「看过」之前算——点开弹出框就把一切标成看过了。
    public enum FocusReason: String, Sendable, Equatable { case pinned, anomaly, waiting, event, unread }

    public static func reason(_ h: Hosted, in xs: [Hosted], _ seen: SeenStore, pinned: String? = nil) -> FocusReason? {
        if let pinned, pinned == h.id { return .pinned }
        switch effectiveRank(h, in: xs) {
        case .anomaly: return .anomaly
        case .waiting: return .waiting
        case .event: return .event
        case .none: break
        }
        return ([h] + children(of: h, in: xs)).contains { seen.isUnread($0) } ? .unread : nil
    }

    /// 第二项：进胶囊的那个。只挑有话说的：看过且空闲的不占胶囊。
    public static func secondary(_ xs: [Hosted], _ seen: SeenStore, primary: Hosted?) -> Hosted? {
        let l = live(xs).filter { $0.id != primary?.id }
        let rank = { (h: Hosted) in effectiveRank(h, in: xs) }
        let rules: [(Hosted) -> Bool] = [
            { rank($0) == .anomaly },
            { rank($0) == .waiting },
            { rank($0) == .event },
            { $0.activity.inProgress },
            { pill($0, seen) != nil },
        ]
        for rule in rules { if let hit = l.first(where: rule) { return hit } }
        return nil
    }

    // MARK: 按来源分槽（分镜 ㉝–㉟，作者 09-21：「两个位置各归一个来源」）

    /// 活着的活动分属哪几个来源，按上刘海的顺序。
    public static func sources(_ xs: [Hosted]) -> [String] {
        var out: [String] = []
        for h in live(xs) where !out.contains(h.producer) { out.append(h.producer) }
        return out
    }

    public static func ofSource(_ xs: [Hosted], _ producer: String) -> [Hosted] { live(xs).filter { $0.producer == producer } }

    /// 紧急度，越小越急；与 `focus` 的规则同一个顺序。
    static func urgency(_ h: Hosted, _ seen: SeenStore) -> Int {
        switch h.activity.rank {
        case .anomaly: return 0
        case .waiting: return 1
        case .event: return 2
        case .none: break
        }
        if seen.isUnread(h) { return h.activity.flagged ? 3 : 4 }
        return 5
    }

    static func moreUrgent(_ a: Hosted, _ b: Hosted, _ seen: SeenStore) -> Bool {
        let ua = urgency(a, seen), ub = urgency(b, seen)
        if ua != ub { return ua < ub }
        return (a.activity.activityAt ?? .distantPast) > (b.activity.activityAt ?? .distantPast)
    }

    /// 一个来源的代表：它自己的主项。
    public static func sourceFocus(_ xs: [Hosted], _ seen: SeenStore, producer: String, pinned: String? = nil) -> Hosted? {
        focus(ofSource(xs, producer), seen, pinned: pinned)
    }

    /// 其余来源里最急的那个的代表（多于两个来源时胶囊只放这一个：问题 4，作者 09-21 按默认）。面板顶上的「切到」也用它。
    public static func otherSource(_ xs: [Hosted], _ seen: SeenStore, than producer: String) -> Hosted? {
        sources(xs).filter { $0 != producer }.compactMap { sourceFocus(xs, seen, producer: $0) }
            .min { moreUrgent($0, $1, seen) }
    }

    /// 收起态的一对。两个及以上来源时：主项 = 最急的来源的主项（钉住的来源优先），胶囊 = 另一个来源的代表；
    /// 只有一个来源时照旧按活动配对（许愿柳单独用时一字不变）。
    /// 主项无话可说（右翼缩回）而另一项有话说时，把那项提成主项；钉住的不换。
    public static func pair(_ xs: [Hosted], _ seen: SeenStore, pinned: String?) -> (primary: Hosted?, secondary: Hosted?) {
        let srcs = sources(xs)
        if srcs.count >= 2 {
            let pinnedLive = pinned.flatMap { id in awake(xs).first { $0.id == id } }
            let primaryProducer = pinnedLive?.producer
                ?? srcs.compactMap { sourceFocus(xs, seen, producer: $0) }.min { moreUrgent($0, $1, seen) }?.producer
            guard let pp = primaryProducer, let p = pinnedLive ?? sourceFocus(xs, seen, producer: pp) else { return (nil, nil) }
            let s = otherSource(xs, seen, than: pp)
            if pinned == nil, label(p, seen) == nil, let s, label(s, seen) != nil {
                return (s, otherSource(xs, seen, than: s.producer))
            }
            return (p, s)
        }
        let p = focus(xs, seen, pinned: pinned)
        let s = secondary(xs, seen, primary: p)
        if pinned == nil, let p, label(p, seen) == nil, let s {
            return (s, secondary(xs, seen, primary: s))
        }
        return (p, s)
    }

    /// 悬停展开态底部那一行 = 「另一个去处」：**同一来源里的下一个**（许愿柳：下一个会话；写作循环：下一份稿件）。
    /// 作者 09-21：在许愿柳的卡里点它只该在许愿柳里切，在 稿件 A 的卡里只该在写作循环里切。
    /// 跨来源不在这里：收起态悬停胶囊、面板顶上「切到」。同来源只有一个活动时没有这一行。
    public static func flipTarget(_ xs: [Hosted], after primary: Hosted?) -> Hosted? {
        guard let primary else { return nil }
        return siblings(xs, of: primary).next
    }

    static func rankOrder(_ h: Hosted) -> Int {
        switch h.activity.rank { case .anomaly: 0; case .waiting: 1; case .event: 2; case .none: 3 }
    }

    /// 同一来源里的兄弟：第几个、共几个、下一个（耳朵右端「2 / 4 ▸」，分镜 ㉟）。
    public static func siblings(_ xs: [Hosted], of h: Hosted) -> (index: Int, count: Int, next: Hosted?) {
        let l = ofSource(xs, h.producer)
        guard l.count > 1, let i = l.firstIndex(where: { $0.id == h.id }) else { return (0, l.count, nil) }
        return (i, l.count, l[(i + 1) % l.count])
    }

    /// 胶囊 / 翻页行上那个来源的数：一个来源有多个活动时是它在跑的个数（一个都没在跑就是开着的个数），
    /// 只有一个活动时用那个活动自己的胶囊（写作循环：要看的句数）。
    public static func slotPill(_ xs: [Hosted], _ seen: SeenStore, _ h: Hosted) -> Activity.Pill? {
        let mine = ofSource(xs, h.producer)
        // 有稿件的环的：胶囊写这一篇自己的「稿名 · 等你 N」（spec 第 4 步）。同一来源开着几份，并成一个数就读不出是哪一篇。
        if mine.count > 1, h.activity.ring == nil {
            let par = parallel(xs, producer: h.producer)
            return Activity.Pill.count(par.running > 0 ? par.running : mine.count)
        }
        return pill(h, seen)
    }

    /// 在跑 / 空闲，按同一来源程序数：开着的里面在跑的算在跑，其余算空闲。
    public static func parallel(_ xs: [Hosted], producer: String?) -> (running: Int, idle: Int) {
        let open = xs.filter { ($0.producer == producer || producer == nil) && $0.activity.open }
        let running = open.filter(\.activity.running).count
        return (running, open.count - running)
    }

    public static func label(_ h: Hosted, _ seen: SeenStore) -> Activity.Label? {
        guard let l = h.activity.label else { return nil }
        return h.activity.labelUntilSeen && !seen.isUnread(h) ? h.activity.labelSeen : l
    }

    public static func pill(_ h: Hosted, _ seen: SeenStore) -> Activity.Pill? {
        guard let p = h.activity.pill else { return nil }
        guard h.activity.pillUntilSeen, !seen.isUnread(h) else { return p }
        return h.activity.pillSeen
    }

    /// 刘海上同时有不止一个来源程序的活动。只有这时收起态与胶囊才画来源标记：
    /// 一个来源时画了不增加信息、只占宽度；两个来源时（许愿柳与 AWT 平行接入，作者 09-18）不画就分不清是谁的事（L8 修订）。
    /// 嵌着的不算一个来源：写作循环嵌进对话以后，刘海上只有许愿柳一个来源（作者 09-24：不该像两个平行的 app）。
    public static func multiSource(_ xs: [Hosted]) -> Bool {
        let l = xs.filter { h in !(h.activity.within?.isEmpty ?? true) ? parent(of: h, in: xs) == nil : true }
        guard let first = l.first?.producer else { return false }
        return l.contains { $0.producer != first }
    }

    /// 收起之后还值得轮到它：没看过，或者还在进行。
    public static func stillWorthShowing(_ h: Hosted, _ seen: SeenStore) -> Bool {
        seen.isUnread(h) || h.activity.inProgress
    }
}
