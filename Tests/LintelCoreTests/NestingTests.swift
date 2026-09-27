import Foundation
import Testing
@testable import LintelCore

/// 嵌套（作者 09-24：写作循环和许愿柳看起来像两个平行的 app，应该做成嵌套）：
/// 一份稿件嵌在正在改它的对话里。对话开着，稿件就画进对话、不再单独占位子；对话不在，稿件照旧单独上刘海。
@MainActor
@Suite("嵌套：稿件嵌在对话里")
struct NestingTests {
    var seen: SeenStore { SeenStore(ephemeral: true) }

    func session(_ id: String, ago: Double = 0, open: Bool = true, stale: Bool = false, _ build: (inout Activity) -> Void = { _ in }) -> Hosted {
        var a = Activity(id: id)
        a.activityAt = Date(timeIntervalSinceNow: -ago); a.open = open; a.stale = stale
        a.label = .init(text: id, tone: .white)
        build(&a)
        return Hosted(producer: "willow", activity: a, writtenAt: nil)
    }

    func draft(_ id: String, in parents: [(String, Activity.Link.Role)], ago: Double = 0, _ build: (inout Activity) -> Void = { _ in }) -> Hosted {
        var a = Activity(id: id)
        a.activityAt = Date(timeIntervalSinceNow: -ago)
        a.label = .init(text: id, tone: .white)
        a.within = parents.map { .init(producer: "willow", id: $0.0, role: $0.1) }
        build(&a)
        return Hosted(producer: "awt-loop", activity: a, writtenAt: nil)
    }

    @Test("对话开着：稿件画进对话，不再单独占位子；刘海上只剩一个来源")
    func absorbed() {
        let s = session("s-draft-a", ago: 30), other = session("s-other", ago: 10) { $0.running = true }
        let d = draft("loop-draft-a", in: [("s-draft-a", .primary)], ago: 1) { $0.rank = .event }
        let xs = Ordering.sorted([s, other, d])
        #expect(!Ordering.live(xs).contains { $0.id == d.id })
        #expect(Ordering.sources(xs) == ["willow"])
        #expect(!Ordering.multiSource(xs))
        let pair = Ordering.pair(xs, seen, pinned: nil)
        #expect(pair.primary?.id != d.id && pair.secondary?.id != d.id)
        #expect(Ordering.children(of: s, in: xs).map(\.id) == [d.id])
        #expect(Ordering.children(of: other, in: xs).isEmpty)
        #expect(Ordering.parent(of: d, in: xs)?.id == s.id)
    }

    @Test("对话不在（没有、关了、过期了）：稿件照旧单独上刘海")
    func standaloneWithoutParent() {
        let d = draft("loop-draft-a", in: [("s-draft-a", .primary)])
        for parent in [nil, session("s-draft-a", open: false), session("s-draft-a", stale: true)] {
            let xs = Ordering.sorted([parent, session("s-other")].compactMap { $0 } + [d])
            #expect(Ordering.live(xs).contains { $0.id == d.id })
            #expect(Ordering.parent(of: d, in: xs) == nil)
            #expect(Ordering.multiSource(xs))
        }
    }

    @Test("钉住的稿件（弹卡、从面板点进去）照样能上主项")
    func pinnedChild() {
        let s = session("s-draft-a"), d = draft("loop-draft-a", in: [("s-draft-a", .primary)])
        let xs = Ordering.sorted([s, d])
        #expect(Ordering.pair(xs, seen, pinned: d.id).primary?.id == d.id)
        #expect(Ordering.focus(xs, seen, pinned: d.id)?.id == d.id)
    }

    @Test("几场对话都开着：主会话先于历史会话，同一种里取最近动过的")
    func whichParent() {
        let hist = session("s-old", ago: 1), prim = session("s-new", ago: 100), prim2 = session("s-new2", ago: 5)
        let d = draft("loop-draft-a", in: [("s-old", .history), ("s-new", .primary), ("s-new2", .primary)])
        let xs = Ordering.sorted([hist, prim, prim2, d])
        #expect(Ordering.parent(of: d, in: xs)?.id == prim2.id)
    }

    @Test("稿件有急事，嵌着它的对话就跟着急：跑挂了的稿件把对话顶上主项")
    func urgencyPropagates() {
        let s = session("s-draft-a", ago: 100), busy = session("s-busy", ago: 1) { $0.rank = .event }
        let d = draft("loop-draft-a", in: [("s-draft-a", .primary)]) { $0.rank = .anomaly; $0.flagged = true }
        let xs = Ordering.sorted([s, busy, d])
        #expect(Ordering.pair(xs, seen, pinned: nil).primary?.id == s.id)
        #expect(Ordering.effectiveRank(s, in: xs) == .anomaly)
    }
}
