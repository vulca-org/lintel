import Testing
import Foundation
@testable import LintelCore
@testable import LintelUI

/// 第五版的岛（分镜 ⑨⑨–①⓪①）：只测取数与排法，不测像素（像素看 docs/verification/2026-09-24-nav-v5/）。
@MainActor
@Suite("第五版的岛：取数")
struct IslandV5Tests {
    static let labels = Activity.Chain.Labels(done: "做完", doing: "在做", you: "等你", other: "等别的", later: "以后")

    static func conversation(_ states: [Activity.Chain.State], label: String? = "比较两份清单") -> Hosted {
        var a = Activity(id: "c"); a.open = true
        a.chain = .init(items: states.enumerated().map { i, s in .init(id: "L\(i + 1)", text: "事项 \(i + 1)", state: s, note: nil, approved: nil, idle: nil) },
                        problems: [], labels: labels, error: nil)
        a.label = label.map { .init(text: $0, tone: .white) }
        return Hosted(producer: "willow", activity: a, writtenAt: nil)
    }

    @Test("右翼：有等你的事写「等你 N」（N 只数等你），没有就退回来源写的标签，两样都没有就不长翼")
    func right() {
        let h = Self.conversation([.you, .done, .you, .doing, .you])
        #expect(IslandText.right(h, label: h.activity.label) == .init(text: "等你", count: 3, tone: nil))
        let none = Self.conversation([.done, .doing])
        #expect(IslandText.right(none, label: none.activity.label) == .init(text: "比较两份清单", count: nil, tone: .white))
        let bare = Self.conversation([.done], label: nil)
        #expect(IslandText.right(bare, label: nil) == nil)
    }

    @Test("两侧翼宽相等，按较宽的一侧定，不超过上限")
    func wingWidth() {
        let short = CompactWingsV5.wingWidth(.init(text: "等你", count: 5, tone: nil))
        #expect(short >= CompactWingsV5.markSize + 20)
        #expect(short < StageController.wing, "「等你 5」比旧的最小翼宽 92 窄：少挡菜单栏")
        #expect(CompactWingsV5.wingWidth(.init(text: String(repeating: "长", count: 30), count: nil, tone: nil)) == StageController.wingMax)
    }

    static func manuscript(_ id: String, stale: Int, waiting: Int = 0, within: String? = nil, at: TimeInterval = 0) -> Hosted {
        var a = Activity(id: id); a.open = true; a.activityAt = Date(timeIntervalSince1970: at)
        let segs = (0..<4).map { i in
            Activity.Ring.Segment(key: "s\(i)", name: "环\(i)", state: i < stale ? .stale : .done, sight: .seen, sightNote: "", note: "", items: [])
        }
        a.ring = .init(name: id, since: "", segments: segs, current: nil, latest: nil, latestAt: nil, unhung: [], waiting: waiting, closed: [],
                       labels: .init(title: "", current: "", latest: "", unhung: "", closed: "", waiting: "等你"), error: nil)
        a.within = within.map { [.init(producer: "willow", id: $0)] }
        return Hosted(producer: "awt-loop", activity: a, writtenAt: nil)
    }

    @Test("小岛：最近动过的稿件出岛，所在对话在不在主位都一样；主位上的稿件不出岛；多份取最近动过的（L9）")
    func detached() {
        let now = Date(timeIntervalSince1970: 100)
        var conv = Activity(id: "c"); conv.open = true
        let parent = Hosted(producer: "willow", activity: conv, writtenAt: nil)
        var other = Activity(id: "o"); other.open = true
        let elsewhere = Hosted(producer: "willow", activity: other, writtenAt: nil)
        let nested = Self.manuscript("draft-a", stale: 2, within: "c", at: 30)
        let loose = Self.manuscript("fw", stale: 2, at: 10)
        let newer = Self.manuscript("fw2", stale: 1, at: 20)
        #expect(Detached.manuscript([parent, nested, loose], primary: parent, now: now)?.id == nested.id,
                "所在对话就在主位也出岛：悬停主岛只有两行，看不到稿件（09-24 实拍：稿件 A 会话在主位时刘海上没有写作循环）")
        #expect(Detached.manuscript([parent, elsewhere, nested, loose], primary: elsewhere, now: now)?.id == nested.id,
                "所在对话不在主位：出岛，且比没嵌的更近（09-24 作者：悬停写作循环应该是 draft-a）")
        #expect(Detached.manuscript([parent, loose], primary: loose, now: now) == nil, "主位上的不再出岛")
        #expect(Detached.manuscript([parent, loose, newer], primary: parent, now: now)?.id == newer.id)
    }

    @Test("小岛：超过 3 天没动的稿件不占岛，没写 activityAt 的也不占（09-24：draft-b 一周没动却占着小岛）")
    func dormant() {
        let day: TimeInterval = 24 * 3600
        var conv = Activity(id: "c"); conv.open = true
        let parent = Hosted(producer: "willow", activity: conv, writtenAt: nil)
        let old = Self.manuscript("fw", stale: 2, at: 0)
        let now = Date(timeIntervalSince1970: 7 * day)
        #expect(Detached.manuscript([parent, old], primary: parent, now: now) == nil)
        #expect(Detached.manuscript([parent, old], primary: parent, now: Date(timeIntervalSince1970: 2 * day))?.id == old.id)
        var bare = Self.manuscript("x", stale: 1, at: 0); bare.activity.activityAt = nil
        #expect(Detached.manuscript([parent, bare], primary: parent, now: Date(timeIntervalSince1970: 1)) == nil)
    }

    @Test("括号里：要重跑的环数；没有就等你几件；都没有只画括号")
    func number() {
        #expect(Detached.number(Self.manuscript("a", stale: 2).activity.ring!)?.n == 2)
        #expect(Detached.number(Self.manuscript("b", stale: 0, waiting: 3).activity.ring!)?.n == 3)
        #expect(Detached.number(Self.manuscript("c", stale: 0).activity.ring!) == nil)
    }

    @Test("航班卡：等你裁 = 挂着要你裁的 + 没挂上环节的；要重跑 = 挂着不要你裁的；胶囊取「论文」格、投稿取「投稿…」格")
    func flight() throws {
        var h = Self.manuscript("draft-a", stale: 2)
        h.activity.ring!.segments[0].items = [.init(id: "a", text: "裁这个", you: true), .init(id: "b", text: "读者组", you: nil)]
        h.activity.ring!.segments[1].items = [.init(id: "c", text: "检查", you: false)]
        h.activity.ring!.unhung = [.init(id: "d", text: "没挂上", you: true)]
        h.activity.ring!.current = "s1"
        let json = #"{"days":{"title":"","bars":[]},"stages":[],"selected":0,"todo":{"title":"待办","cells":[{"title":"论文","text":"未就绪","value":"未就绪","tone":"orange"},{"title":"投稿构建","text":"x","value":"待填 1"}]}}"#
        var d = Activity.Detail(listTitle: "", dot: .white, history: [], chart: nil, stats: [])
        d.overview = try JSONDecoder().decode(Activity.Overview.self, from: Data(json.utf8))
        h.activity.detail = d
        let m = try #require(FlightModel.make(h, registry: nil))
        #expect(m.you == 2)
        #expect(m.rerun == 2)
        #expect(m.status == "论文未就绪" && m.statusUrgent)
        #expect(m.submit == "待填 1")
        #expect(m.current == 1)
        #expect(m.position == 1, "来源没给最近动静：位置退回当前")
        h.activity.ring!.latest = "s3"
        h.activity.ring!.latestAt = Date(timeIntervalSince1970: 1_790_000_000)
        let moved = try #require(FlightModel.make(h, registry: nil))
        #expect(moved.position == 3 && moved.current == 1, "位置跟最近动静走，当前仍是等你的第一环（09-24：draft-a 当前设计、最近动静检查）")
        #expect(moved.positionAt != nil)
        h.activity.ring!.reached = "s2"
        let reached = try #require(FlightModel.make(h, registry: nil))
        #expect(reached.position == 2 && reached.positionAt == nil, "来源给了最远做到哪：位置按它；它不是最近动静那环时不写时刻")
    }

    @Test("等你裁里最久没动的那条：取挂着要你裁的事与没挂上环节的事里最早的进展日期；都没写就没有")
    func oldest() throws {
        var h = Self.manuscript("draft-a", stale: 0)
        h.activity.ring!.segments[1].items = [.init(id: "W8", text: "x", you: true, moved: "09-24"), .init(id: "c", text: "检查", you: false, moved: "09-01")]
        h.activity.ring!.unhung = [.init(id: "R1", text: "y", you: true, moved: "09-22")]
        #expect(try #require(FlightModel.make(h, registry: nil)).youOldest == "09-22", "不要你裁的（检查）不算")
        h.activity.ring!.unhung = []
        h.activity.ring!.segments[1].items[0].moved = nil
        #expect(try #require(FlightModel.make(h, registry: nil)).youOldest == nil)
    }

    @Test("航线下的名字：起点、当前、终点；当前在第 0、1 站时不写起点（挨得太近）")
    func namedStops() {
        func m(_ cur: Int?, _ n: Int) -> FlightModel {
            FlightModel(source: "", name: "", status: nil, statusUrgent: false,
                        stops: (0..<n).map { .init(name: "\($0)", state: .done) }, current: cur, position: cur, positionAt: nil,
                        youOldest: nil, you: 0, rerun: 0, submit: nil)
        }
        #expect(m(1, 7).namedStops() == [1, 6])
        #expect(m(3, 7).namedStops() == [0, 3, 6])
        #expect(m(6, 7).namedStops() == [0, 6])
        #expect(m(nil, 7).namedStops() == [0, 6])
    }

    @Test("投稿那一格的颜色跟来源走：来源标白的「可上传」不是警示，标橙或红的才是，没标的不是（09-27 面板 grill 9）")
    func submitTone() throws {
        func model(_ cell: String) throws -> FlightModel {
            var h = Self.manuscript("draft-a", stale: 0)
            let json = #"{"days":{"title":"","bars":[]},"stages":[],"selected":0,"todo":{"title":"待办","cells":["# + cell + #"]}}"#
            var d = Activity.Detail(listTitle: "", dot: .white, history: [], chart: nil, stats: [])
            d.overview = try JSONDecoder().decode(Activity.Overview.self, from: Data(json.utf8))
            h.activity.detail = d
            return try #require(FlightModel.make(h, registry: nil))
        }
        let ok = try model(#"{"title":"投稿构建","text":"失败 0 项","value":"可上传","tone":"white"}"#)
        #expect(ok.submit == "可上传" && !ok.submitUrgent)
        let todo = try model(#"{"title":"投稿构建","text":"x","value":"待填 6","tone":"orange"}"#)
        #expect(todo.submitUrgent)
        let bare = try model(#"{"title":"投稿构建","text":"x","value":"待填 1"}"#)
        #expect(!bare.submitUrgent)
    }

    @Test("航线图例：只列这条航线上出现的记号；做到的那一站排第一、写「做到这里」，它自己的状态不另算一项（09-27 面板 grill 13）")
    func routeLegend() {
        let states: [Activity.Ring.State] = [.done, .unseen, .waiting, .done, .done, .open, .unseen]
        let m = FlightModel(source: "", name: "", status: nil, statusUrgent: false,
                            stops: states.enumerated().map { .init(name: "\($0.offset)", state: $0.element) }, current: 2, position: 4, positionAt: nil,
                            youOldest: nil, you: 0, rerun: 0, submit: nil)
        let keys = RouteLegend.keys(m)
        #expect(keys.first.map { $0.current } == true)
        #expect(keys.dropFirst().map(\.state) == [.done, .waiting, .open, .unseen], "没有过期的，不列过期")
        #expect(RouteNode.word(.stale, current: false) == L("过期", "stale"))
        var none = m; none.position = nil
        #expect(RouteLegend.keys(none).allSatisfy { !$0.current })
    }

    @Test("窗口侧栏：对话一组（嵌着的稿件做它的下一层），没嵌进对话的稿件另一组；弹出框能换到的对话不含稿件")
    func sidebar() {
        var conv = Activity(id: "c"); conv.open = true; conv.activityAt = Date(timeIntervalSince1970: 5)
        let parent = Hosted(producer: "willow", activity: conv, writtenAt: nil)
        let nested = Self.manuscript("draft-a", stale: 2, within: "c", at: 30)
        let loose = Self.manuscript("fw", stale: 2, at: 10)
        let xs = [parent, nested, loose]
        let convs = SidebarModel.conversations(xs)
        #expect(convs.map(\.id) == [parent.id])
        #expect(convs.first?.children?.map(\.id) == [nested.id])
        #expect(SidebarModel.drafts(xs).map(\.id) == [loose.id])
        #expect(PopoverScope.conversations(xs).map(\.id) == [parent.id])
    }

    @Test("侧栏骨架：稿件换了所在的对话、对话换了顺序，骨架就变（侧栏整个重建）；只改标题或数字，骨架不变")
    func sidebarShape() {
        func conv(_ id: String, at: Double, label: String, stale: Bool = false) -> Hosted {
            var a = Activity(id: id); a.open = true; a.activityAt = Date(timeIntervalSince1970: at); a.stale = stale
            a.label = .init(text: label, tone: .white)
            return Hosted(producer: "willow", activity: a, writtenAt: nil)
        }
        var ms = Self.manuscript("draft-a", stale: 2, within: "a", at: 30)
        ms.activity.within?.append(.init(producer: "willow", id: "b", role: .history))
        let awake = [conv("a", at: 5, label: "改稿"), conv("b", at: 4, label: "写规格"), ms]
        let asleep = [conv("a", at: 5, label: "改稿", stale: true), conv("b", at: 4, label: "写规格"), ms]
        let relabelled = [conv("a", at: 5, label: "查图表"), conv("b", at: 4, label: "写规格"), ms]
        #expect(SidebarModel.conversations(awake).first?.children?.map(\.id) == [ms.id])
        #expect(SidebarModel.conversations(asleep).last?.children?.map(\.id) == [ms.id])
        #expect(SidebarModel.shape(awake) != SidebarModel.shape(asleep))
        #expect(SidebarModel.shape(awake) == SidebarModel.shape(relabelled))
        let reordered = [conv("a", at: 5, label: "改稿"), conv("b", at: 6, label: "写规格"), ms]
        #expect(SidebarModel.shape(awake) != SidebarModel.shape(reordered))
    }

    @Test("对话的标题用来源给的 name，不用这一轮的标签；没有 name 才退回标签（09-27 grill 4）")
    func titleUsesName() {
        var a = Activity(id: "s1"); a.open = true
        a.label = .init(text: "对齐三份配置", tone: .white)
        let noName = Hosted(producer: "willow", activity: a, writtenAt: nil)
        #expect(PopoverScope.title(noName) == "对齐三份配置")
        a.name = "三条工具线的进展"
        let named = Hosted(producer: "willow", activity: a, writtenAt: nil)
        #expect(PopoverScope.title(named) == "三条工具线的进展")
        #expect(SidebarModel.node(named, draft: false).title == "三条工具线的进展")
    }

    @Test("理解到达的那几秒画来源的弹出几行；悬停（非 compact）、稿件、没有弹出几行时不画（09-27 作者选 A）")
    func arrivalLines() {
        var a = Activity(id: "c"); a.open = true
        a.popup = [.init(label: "你说的", text: "只查原因，不改代码", tone: .secondary, lines: 1),
                   .init(label: "读成了", text: "重写重试逻辑", tone: .primary, lines: 2)]
        let conv = Hosted(producer: "willow", activity: a, writtenAt: nil)
        #expect(ArrivalLines.lines(conv, compact: true)?.map(\.label) == ["你说的", "读成了"])
        #expect(ArrivalLines.lines(conv, compact: false) == nil, "悬停时是最矮两行")
        var empty = a; empty.popup = []
        #expect(ArrivalLines.lines(Hosted(producer: "willow", activity: empty, writtenAt: nil), compact: true) == nil)
        var draft = a; draft.ring = Self.manuscript("m", stale: 0, within: nil, at: 0).activity.ring
        #expect(ArrivalLines.lines(Hosted(producer: "awt-loop", activity: draft, writtenAt: nil), compact: true) == nil, "稿件直接是航班卡")
    }

    @Test("环上的一件事：去掉来源写在前面的「风险 编号 」，编号另放一列；没有这个前缀的原样")
    func itemText() {
        #expect(PopoverScope.itemText(.init(id: "W8", text: "风险 W8 正文各节没有设计过", you: true)) == "正文各节没有设计过")
        #expect(PopoverScope.itemText(.init(id: "readers", text: "读者组 · 过期", you: false)) == "读者组 · 过期")
    }
}
