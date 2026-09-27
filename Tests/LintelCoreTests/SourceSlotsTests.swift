import Foundation
import Testing
@testable import LintelCore

/// 分镜 ㉝–㉟（作者 09-21）：两个位置各归一个来源。只有一个来源时照旧按活动配对。
@MainActor
@Suite("按来源分槽")
struct SourceSlotsTests {
    func make(_ producer: String, _ id: String, ago: Double = 0, _ build: (inout Activity) -> Void = { _ in }) -> Hosted {
        var a = Activity(id: id)
        a.activityAt = Date(timeIntervalSinceNow: -ago)
        a.label = .init(text: id, tone: .white)
        build(&a)
        return Hosted(producer: producer, activity: a, writtenAt: nil)
    }

    var seen: SeenStore { SeenStore(ephemeral: true) }

    @Test("两个来源：最急的来源的主项上翼，另一个来源的代表进胶囊；卡底那一行只在同一来源里翻")
    func twoSources() {
        let w1 = make("willow", "w1", ago: 10) { $0.running = true }
        let w2 = make("willow", "w2", ago: 20) { $0.running = true }
        let w3 = make("willow", "w3", ago: 30)
        let awt = make("awt-loop", "loop-draft-a", ago: 5) { $0.rank = .event; $0.flagged = true }
        let xs = Ordering.sorted([w1, w2, w3, awt])
        let s = seen
        let pair = Ordering.pair(xs, s, pinned: nil)
        #expect(pair.primary?.activity.id == "loop-draft-a")
        #expect(pair.secondary?.producer == "willow")
        // 卡底那一行 = 同一来源里的下一个（作者 09-21 改口）：AWT 只有一份稿件就没有；许愿柳里是下一个会话，不是 AWT
        #expect(Ordering.flipTarget(xs, after: pair.primary) == nil)
        #expect(Ordering.flipTarget(xs, after: w1)?.activity.id == "w2")
        #expect(Ordering.flipTarget(xs, after: w3)?.activity.id == "w1")
    }

    @Test("胶囊上是来源自己的数：多个活动 = 在跑的个数；只有一个活动 = 那个活动自己的胶囊")
    func slotPill() {
        let w1 = make("willow", "w1") { $0.running = true }
        let w2 = make("willow", "w2") { $0.running = true }
        let w3 = make("willow", "w3")
        var p = Activity(id: "loop-draft-a"); p.activityAt = Date()
        p.pill = Activity.Pill.count(15)
        let awt = Hosted(producer: "awt-loop", activity: p, writtenAt: nil)
        let xs = Ordering.sorted([w1, w2, w3, awt])
        #expect(Ordering.slotPill(xs, seen, w1)?.title == "2")
        #expect(Ordering.slotPill(xs, seen, awt)?.title == "15")
    }

    @Test("有稿件的环：同一来源开着几份也写这一篇自己的胶囊（稿名 · 等你 N），不并成一个数")
    func ringKeepsOwnPill() {
        func loop(_ id: String, ring: Bool) -> Hosted {
            var a = Activity(id: id); a.activityAt = Date()
            var pill = Activity.Pill(); pill.title = "\(id) · 等你 3"; a.pill = pill
            if ring {
                a.ring = .init(name: id, since: "从头算起", segments: [], current: nil, latest: nil, latestAt: nil, unhung: [], waiting: 3,
                               closed: [], labels: .init(title: "这一轮", current: "当前", latest: "最近动静", unhung: "没挂上环节", closed: "已关的门", waiting: "等你"),
                               error: nil)
            }
            return Hosted(producer: "awt-loop", activity: a, writtenAt: nil)
        }
        let a = loop("draft-a", ring: true), b = loop("v9", ring: true)
        #expect(Ordering.slotPill(Ordering.sorted([a, b]), seen, a)?.title == "draft-a · 等你 3")
        let c = loop("draft-a", ring: false), d = loop("v9", ring: false)
        #expect(Ordering.slotPill(Ordering.sorted([c, d]), seen, c)?.title == "2", "没有环：照旧并成个数")
    }

    @Test("同一来源里的兄弟：第几个、共几个、下一个；只有一个时没有下一个")
    func siblings() {
        let w1 = make("willow", "w1", ago: 1), w2 = make("willow", "w2", ago: 2), w3 = make("willow", "w3", ago: 3)
        let awt = make("awt-loop", "loop-draft-a")
        let xs = Ordering.sorted([w1, w2, w3, awt])
        let s = Ordering.siblings(xs, of: w2)
        #expect(s.count == 3 && s.next?.activity.id == "w3")
        #expect(Ordering.siblings(xs, of: w3).next?.activity.id == "w1")
        #expect(Ordering.siblings(xs, of: awt).next == nil)
    }

    @Test("钉住的活动决定主来源；三个来源时胶囊只放其余里最急的")
    func pinnedAndThree() {
        let w = make("willow", "w1") { $0.running = true }
        let awt = make("awt-loop", "loop-draft-a") { $0.rank = .event }
        let q = make("queue", "q1") { $0.rank = .anomaly }
        let xs = Ordering.sorted([w, awt, q])
        let s = seen
        #expect(Ordering.pair(xs, s, pinned: nil).primary?.producer == "queue")
        #expect(Ordering.pair(xs, s, pinned: nil).secondary?.producer == "awt-loop")   // event 比 running 急
        let pinned = Ordering.pair(xs, s, pinned: w.id)   // Hosted.id = 来源/活动
        #expect(pinned.primary?.activity.id == "w1" && pinned.secondary?.producer == "queue")
    }

    @Test("只有一个来源：照旧按活动配对，胶囊是同来源的另一个活动，翻页行循环")
    func singleSourceUnchanged() {
        let a = make("willow", "a", ago: 1) { $0.running = true; $0.inProgress = true }
        let b = make("willow", "b", ago: 2) { $0.running = true; $0.inProgress = true }
        let xs = Ordering.sorted([a, b])
        let pair = Ordering.pair(xs, seen, pinned: nil)
        #expect(pair.primary?.activity.id == "a" && pair.secondary?.activity.id == "b")
        #expect(Ordering.flipTarget(xs, after: a)?.activity.id == "b")
        #expect(Ordering.slotPill(xs, seen, b)?.title == "2")
    }
}
