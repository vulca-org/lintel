import Testing
import Foundation
@testable import LintelCore
@testable import LintelUI

/// 到了日子的「等别的」「以后」项露在哪（10-06 spec「刘海上露出到了日子的项」D4–D6）。
/// 天数和字是来源写好的（`due`），这里只测 lintel 怎么排：只测取数与排法，不测像素。
/// 形状照 10-06 实见：等你 8 项占满弹出框和悬停，一项已过 18 天的「以后」、一项约在当天的「等别的」只在窗口里，而且「以后」折着。
@MainActor
@Suite("到了日子的项：排法")
struct ChainDueTests {
    init() { Lang.current = .zh }

    typealias Item = Activity.Chain.Item
    static let labels = Activity.Chain.Labels(done: "做完", doing: "在做", you: "等你", other: "等别的", later: "以后")

    static func item(_ id: String, _ s: Activity.Chain.State, due days: Int? = nil) -> Item {
        var x = Item(id: id, text: "合成事项 \(id)", state: s, note: nil, approved: nil, idle: nil)
        x.due = days.map { .init(days: $0, text: $0 < 0 ? "已过 \(-$0) 天" : $0 == 0 ? "今天" : "还有 \($0) 天") }
        return x
    }

    static func chain(_ xs: [Item]) -> Activity.Chain { .init(items: xs, problems: [], labels: labels, error: nil) }

    /// 事故形状（合成标题）：等你 8，在做 0，到日子 5（L15 以后已过 18 天、L17 等别的今天、L2/L3/L9 等别的还有几天）。
    static let incident: Activity.Chain = chain([
        item("L1", .you), item("L2", .other, due: 2), item("L3", .other, due: 4), item("L4", .other), item("L5", .other),
        item("L6", .you), item("L7", .later), item("L8", .you), item("L9", .other, due: 5), item("L10", .you),
        item("L11", .you), item("L12", .you), item("L13", .you), item("L14", .later), item("L15", .later, due: -18),
        item("L16", .you), item("L17", .other, due: 0),
    ])

    /// 没有等你、在做的同一份：弹出框主组退到等别的。
    static let othersOnly: Activity.Chain = chain(incident.items.filter { $0.state == .other || $0.state == .later })

    static func hosted(_ c: Activity.Chain) -> Hosted {
        var a = Activity(id: "c"); a.open = true; a.chain = c
        a.label = .init(text: "合成标签", tone: .white)
        return Hosted(producer: "willow", activity: a, writtenAt: nil)
    }

    @Test("到日子的项：日子越早越先，一样早按清单顺序；没带 due 的、做完的不算")
    func order() {
        #expect(ChainLayout.due(Self.incident).map(\.id) == ["L15", "L17", "L2", "L3", "L9"])
        let tie = Self.chain([Self.item("L1", .other, due: 3), Self.item("L2", .later, due: 3), Self.item("L3", .done, due: -1), Self.item("L4", .later)])
        #expect(ChainLayout.due(tie).map(\.id) == ["L1", "L2"])
    }

    @Test("悬停两行：有等你时头一行照旧「等你 8」，后面跟「到日子 5」，有已过的用警示色")
    func hoverSuffix() throws {
        let l = try #require(MinimumLines.lines(Self.hosted(Self.incident)))
        #expect(l.head == "等你 8" && l.body == "合成事项 L1")
        #expect(l.due == "到日子 5")
        #expect(l.dueTone == Swatch.orange.color)
        var future = Self.incident
        future.items = future.items.map { var x = $0; if let d = x.due, d.days < 0 { x.due = .init(days: 1, text: "还有 1 天") }; return x }
        #expect(try #require(MinimumLines.lines(Self.hosted(future))).dueTone == Ink.secondary, "都没过：不用警示色")
    }

    @Test("悬停两行：没有等你、在做时，头一行是「到日子 N · 最早那项的天数」，第二行是最早那项，不再退到来源标签")
    func hoverFallback() throws {
        let l = try #require(MinimumLines.lines(Self.hosted(Self.othersOnly)))
        #expect(l.head == "到日子 5")
        #expect(l.due == "已过 18 天")
        #expect(l.body == "合成事项 L15")
        #expect(l.headTone == Swatch.orange.color)
    }

    @Test("悬停两行：没有到日子的项，和原来逐字一样")
    func hoverUnchanged() throws {
        let plain = Self.chain([Self.item("L1", .doing), Self.item("L2", .other), Self.item("L3", .later)])
        let l = try #require(MinimumLines.lines(Self.hosted(plain)))
        #expect(l.head == "在做 1" && l.body == "合成事项 L1" && l.due == nil)
        let none = Self.chain([Self.item("L1", .other), Self.item("L2", .later)])
        let m = try #require(MinimumLines.lines(Self.hosted(none)))
        #expect(m.head == "合成标签" && m.due == nil, "没到日子的等别的、以后：照旧退到来源标签")
    }

    @Test("弹出框「到日子」段：最多 2 行，主组里画过的不重复；事故形状是 L15、L17，还有 3")
    func popover() {
        let (state, lead) = PopoverView.leadGroup(Self.incident)
        #expect(state == .you)
        let shown = Array(lead.prefix(PopoverView.youRows))
        let d = PopoverView.dueRows(Self.incident, shown: shown)
        #expect(d.rows.map(\.id) == ["L15", "L17"])
        #expect(d.total == 5)
        // 主组是等别的时，L2、L3 已在主组的三行里，不再出现在到日子段。
        let (s2, lead2) = PopoverView.leadGroup(Self.othersOnly)
        #expect(s2 == .other)
        let d2 = PopoverView.dueRows(Self.othersOnly, shown: Array(lead2.prefix(PopoverView.youRows)))
        #expect(d2.rows.map(\.id) == ["L15", "L17"])
        #expect(d2.total == 3)
        #expect(PopoverView.dueRows(Self.chain([Self.item("L1", .you), Self.item("L2", .later)]), shown: []).total == 0, "没有到日子的：整段不画")
    }

    /// 久过期的让位（10-06 增补 spec「只认截止日期，久过期的让位」D10）：一件已过 33 天、一件已过 8 天、一件今天、一件还有 4 天。
    static let stale: Activity.Chain = chain([
        item("L1", .you), item("L2", .later, due: -33), item("L3", .other, due: -8), item("L4", .other, due: 0), item("L5", .later, due: 4),
    ])

    @Test("弹出框「到日子」段：已过的最多占一行，取过得最少的，另一行给今天；只有已过的取过得最少的两项；只有没过的照旧取最近的")
    func popoverYields() {
        let d = PopoverView.dueRows(Self.stale, shown: [Self.stale.items[0]])
        #expect(d.rows.map(\.id) == ["L3", "L4"])
        #expect(d.total == 4)
        let past = Self.chain([Self.item("L1", .later, due: -33), Self.item("L2", .later, due: -18), Self.item("L3", .other, due: -8)])
        #expect(PopoverView.dueRows(past, shown: []).rows.map(\.id) == ["L2", "L3"])
        let tie = Self.chain([Self.item("L1", .later, due: -8), Self.item("L2", .other, due: -8), Self.item("L3", .other, due: -20)])
        #expect(PopoverView.dueRows(tie, shown: []).rows.map(\.id) == ["L1", "L2"], "一样的天数按清单顺序")
        let next = Self.chain([Self.item("L1", .other, due: 4), Self.item("L2", .other, due: 0), Self.item("L3", .later, due: 2)])
        #expect(PopoverView.dueRows(next, shown: []).rows.map(\.id) == ["L2", "L3"])
    }

    @Test("悬停退路：有好几件已过时，第二行是过得最少的那件，不是最老的那件；仍用警示色")
    func hoverFallbackYields() throws {
        let c = Self.chain(Self.stale.items.filter { $0.state != .you })
        let l = try #require(MinimumLines.lines(Self.hosted(c)))
        #expect(l.head == "到日子 4")
        #expect(l.body == "合成事项 L3")
        #expect(l.due == "已过 8 天")
        #expect(l.headTone == Swatch.orange.color)
    }

    @Test("窗口：以后组折着时，到了日子的项照样露出；点开以后全列")
    func windowFold() {
        let later = Self.incident.items.filter { $0.state == .later }
        #expect(FoldedGroups.visible(later, folded: true).map(\.id) == ["L15"])
        #expect(FoldedGroups.visible(later, folded: false).map(\.id) == ["L7", "L14", "L15"])
        #expect(FoldedGroups.visible([Self.item("L1", .later)], folded: true).isEmpty, "折起的组没有到日子的：照旧一项不露")
    }

    @Test("旁注：只带 due 也要画那一行；已过用警示色，今天和还有几天用次要色")
    func meta() {
        #expect(ChainMeta.has(Self.item("L1", .later, due: 3)))
        #expect(!ChainMeta.has(Self.item("L1", .later)))
        #expect(ChainMeta.dueTint(-1) == Tone.orange)
        #expect(ChainMeta.dueTint(0) == Tone.secondary)
        #expect(ChainMeta.dueTint(9) == Tone.secondary)
    }
}
