import Foundation
import Testing
@testable import LintelCore

/// 从许愿柳 `WingRuleTests` / `MultiSessionTests` 移植：同样的规则，改成按活动字段表达。
@MainActor
@Suite("排序与配对")
struct OrderingTests {
    func hosted(_ id: String, _ build: (inout Activity) -> Void = { _ in }, ago: Double = 0) -> Hosted {
        var a = Activity(id: id)
        a.revision = "\(id)-t"
        a.activityAt = t0.addingTimeInterval(-ago)
        build(&a)
        return Hosted(producer: "willow", activity: a, writtenAt: nil)
    }

    func label(_ text: String) -> Activity.Label { .init(text: text, tone: .white) }

    @Test("主项：异常 > 等你 > 刚发生的事 > 没看过且自标不一致 > 没看过 > 最近动静；钉住优先；过期的不上")
    func focus() {
        let seen = SeenStore(ephemeral: true)
        let plain = hosted("plain", ago: 0)
        let unread = hosted("unread", ago: 5)
        let flagged = hosted("flagged", { $0.flagged = true }, ago: 6)
        let event = hosted("event", { $0.rank = .event }, ago: 7)
        let waiting = hosted("waiting", { $0.rank = .waiting }, ago: 8)
        let anomaly = hosted("anomaly", { $0.rank = .anomaly }, ago: 9)
        let stale = hosted("stale", { $0.rank = .anomaly; $0.stale = true }, ago: 10)
        var xs = Ordering.sorted([plain, unread, flagged, event, waiting, anomaly, stale])
        #expect(xs.last?.id == "willow/stale")
        #expect(Ordering.focus(xs, seen)?.id == "willow/anomaly")
        xs.removeAll { $0.activity.id == "anomaly" }
        #expect(Ordering.focus(xs, seen)?.id == "willow/waiting")
        xs.removeAll { $0.activity.id == "waiting" }
        #expect(Ordering.focus(xs, seen)?.id == "willow/event")
        xs.removeAll { $0.activity.id == "event" }
        #expect(Ordering.focus(xs, seen)?.id == "willow/flagged")
        seen.markSeen(xs.first { $0.activity.id == "flagged" }!)
        seen.markSeen(xs.first { $0.activity.id == "plain" }!)
        #expect(Ordering.focus(xs, seen)?.id == "willow/unread")
        #expect(Ordering.focus(xs, seen, pinned: "willow/plain")?.id == "willow/plain")
        #expect(Ordering.focus(xs, seen, pinned: "willow/stale")?.id == "willow/unread")
    }

    @Test("胶囊：排除主项；异常 > 在进行 > 有胶囊可放的；看过且只在没看过时才有胶囊的不占")
    func secondary() {
        let seen = SeenStore(ephemeral: true)
        var p = Activity.Pill(); p.title = "新声明"
        let main = hosted("main", { $0.label = self.label("主会话"); $0.pill = p; $0.pillUntilSeen = true })
        let fresh = hosted("fresh", { $0.pill = p; $0.pillUntilSeen = true }, ago: 1)
        let run = hosted("run", { $0.inProgress = true }, ago: 2)
        let xs = Ordering.sorted([main, fresh, run])
        #expect(Ordering.secondary(xs, seen, primary: main)?.id == "willow/run")
        #expect(Ordering.secondary(xs, seen, primary: run)?.id == "willow/main")

        let idle = hosted("idle", { $0.pill = p; $0.pillUntilSeen = true }, ago: 1)
        let quiet = Ordering.sorted([main, idle])
        seen.markSeen(idle)
        #expect(Ordering.secondary(quiet, seen, primary: main) == nil)
        #expect(Ordering.secondary(quiet, seen, primary: nil)?.id == "willow/main")
    }

    @Test("右翼：看过之后按开关缩回；不按开关的看过也照样显示")
    func labelUntilSeen() {
        let seen = SeenStore(ephemeral: true)
        let ended = hosted("b", { $0.label = self.label("改岛动效"); $0.labelUntilSeen = true })
        let running = hosted("a", { $0.label = self.label("回答中"); $0.labelUntilSeen = false })
        #expect(Ordering.label(ended, seen)?.text == "改岛动效")
        seen.markSeen(ended); seen.markSeen(running)
        #expect(Ordering.label(ended, seen) == nil)
        #expect(Ordering.label(running, seen)?.text == "回答中")
        // 没有版本的活动永远算看过
        let noRev = Hosted(producer: "willow", activity: { var a = Activity(id: "n"); a.label = label("x"); a.labelUntilSeen = true; return a }(), writtenAt: nil)
        #expect(Ordering.label(noRev, seen) == nil)
    }

    @Test("右翼：看过之后有 labelSeen 就换成它（常驻「等你 N」），没有才缩回")
    func labelSeenAfterSeen() {
        let seen = SeenStore(ephemeral: true)
        let waiting = hosted("w", { $0.label = self.label("画清单"); $0.labelUntilSeen = true
                                    $0.labelSeen = .init(text: "等你", tone: .white, count: 7) })
        #expect(Ordering.label(waiting, seen)?.text == "画清单")
        seen.markSeen(waiting)
        #expect(Ordering.label(waiting, seen)?.text == "等你")
        #expect(Ordering.label(waiting, seen)?.count == 7)
    }

    @Test("主项无话可说而另一项在进行：把在进行的提成主项；钉住的不换")
    func pairPromotes() {
        let seen = SeenStore(ephemeral: true)
        let done = hosted("done", { $0.label = self.label("看过了"); $0.labelUntilSeen = true })
        let run = hosted("run", { $0.inProgress = true; $0.label = self.label("回答中") }, ago: 3)
        let xs = Ordering.sorted([done, run])
        seen.markSeen(done); seen.markSeen(run)
        #expect(Ordering.focus(xs, seen)?.id == "willow/done")
        let p = Ordering.pair(xs, seen, pinned: nil)
        #expect(p.primary?.id == "willow/run")
        #expect(p.secondary == nil)
        #expect(Ordering.pair(xs, seen, pinned: "willow/done").primary?.id == "willow/done")
    }

    @Test("翻页循环；在跑 / 空闲按同一来源程序里开着的活动数")
    func flipAndParallel() {
        let a = hosted("a", { $0.running = true })
        let b = hosted("b", ago: 1)
        let c = hosted("c", { $0.open = false }, ago: 2)
        let other = Hosted(producer: "queue", activity: { var x = Activity(id: "q"); x.running = true; return x }(), writtenAt: nil)
        let xs = Ordering.sorted([a, b, c])
        #expect(Ordering.flipTarget(xs, after: a)?.id == "willow/b")
        #expect(Ordering.flipTarget(xs, after: c)?.id == "willow/a")
        #expect(Ordering.flipTarget([a], after: a) == nil)
        let par = Ordering.parallel(xs + [other], producer: "willow")
        #expect(par.running == 1 && par.idle == 1)
    }

    @Test("排队：没在展示就立刻展示；正在展示同一个不排；别的排在后面、不重复；取下一个时跳过不值得展示的")
    func arrivalQueue() {
        var q = ArrivalQueue()
        #expect(q.offer("a", showing: nil) == true)
        #expect(q.offer("a", showing: "a") == false)
        #expect(q.waiting.isEmpty)
        #expect(q.offer("b", showing: "a") == false)
        #expect(q.offer("c", showing: "a") == false)
        #expect(q.offer("b", showing: "a") == false)
        #expect(q.waiting == ["b", "c"])
        #expect(q.next(alive: ["c"]) == "c")
        #expect(q.next(alive: ["c"]) == nil)
        // A（作者 09-21）：冷却到期只弹最新的一条，其余丢掉
        var r = ArrivalQueue()
        _ = r.offer("b", showing: "a"); _ = r.offer("c", showing: "a"); _ = r.offer("d", showing: "a")
        #expect(r.latest(alive: ["b", "c"]) == "c")
        #expect(r.waiting.isEmpty)
        #expect(r.latest(alive: ["x"]) == nil)
    }

    @Test("看过之后的胶囊（作者 09-22）：给了 pillSeen 就换成它、胶囊不撤；没给照旧撤；没看过照旧用 pill")
    func pillSeen() {
        let seen = SeenStore(ephemeral: true)
        var p = Activity.Pill(); p.title = "4"
        var after = Activity.Pill(); after.agoSince = t0
        let loop = Hosted(producer: "awt-loop", activity: { var a = Activity(id: "loop-draft-a"); a.revision = "r1"
            a.pill = p; a.pillUntilSeen = true; a.pillSeen = after; a.activityAt = t0; return a }(), writtenAt: t0)
        let plain = Hosted(producer: "awt-loop", activity: { var a = Activity(id: "other"); a.revision = "r1"
            a.pill = p; a.pillUntilSeen = true; return a }(), writtenAt: t0)
        #expect(Ordering.pill(loop, seen) == p)
        seen.markSeen(loop); seen.markSeen(plain)
        #expect(Ordering.pill(loop, seen) == after)
        #expect(Ordering.pill(plain, seen) == nil)
        // 两个来源时胶囊放写作循环：看过之后仍然有东西可画（胶囊宽度不归零）
        let willow = Hosted(producer: "willow", activity: { var a = Activity(id: "s1"); a.revision = "t1"; a.activityAt = t0.addingTimeInterval(60)
            a.label = .init(text: "改稿", tone: .white); return a }(), writtenAt: t0)
        let pair = Ordering.pair([willow, loop], seen, pinned: nil)
        #expect(pair.secondary?.id == "awt-loop/loop-draft-a")
        #expect(Ordering.slotPill([willow, loop], seen, pair.secondary!) == after)
    }

    @Test("两个来源各排各的（作者 09-22）：先许愿柳、后写作循环，都弹；同一来源内仍只弹最新一条")
    func arrivalQueueBySource() {
        var q = ArrivalQueue()
        // 写作循环先到、许愿柳后到，都排在正在展示的 x 后面
        for id in ["awt-loop/loop-draft-a", "willow/s1", "willow/s2"] { _ = q.offer(id, showing: "willow/x") }
        let alive: Set<String> = ["awt-loop/loop-draft-a", "willow/s1", "willow/s2"]
        #expect(q.nextBySource(alive: alive, order: ["willow"]) == "willow/s2")        // 许愿柳在前，取它最新的
        #expect(q.waiting == ["awt-loop/loop-draft-a"])                                     // 写作循环没被吞
        #expect(q.nextBySource(alive: alive, order: ["willow"]) == "awt-loop/loop-draft-a")
        #expect(q.nextBySource(alive: alive, order: ["willow"]) == nil)
        // 已经不值得展示的直接丢掉，不挡别的来源
        var r = ArrivalQueue()
        for id in ["willow/s1", "awt-loop/a"] { _ = r.offer(id, showing: "x") }
        #expect(r.nextBySource(alive: ["awt-loop/a"], order: ["willow"]) == "awt-loop/a")
        #expect(r.waiting.isEmpty)
        // 都不在 order 里：按最早到达的来源
        var s = ArrivalQueue()
        for id in ["b/1", "a/1", "b/2"] { _ = s.offer(id, showing: "x") }
        #expect(s.nextBySource(alive: ["b/1", "a/1", "b/2"], order: []) == "b/2")
        #expect(ArrivalQueue.source(of: "awt-loop/loop-draft-a") == "awt-loop")
    }

    @Test("轮流弹（grill 09-22）：刚弹过许愿柳，许愿柳又来一条，写作循环先弹，不会一直轮不到")
    func arrivalQueueTakesTurns() {
        var q = ArrivalQueue()
        for id in ["awt-loop/a", "willow/s3"] { _ = q.offer(id, showing: "cooldown") }
        let alive: Set<String> = ["awt-loop/a", "willow/s3"]
        #expect(q.nextBySource(alive: alive, order: ["willow"], after: "willow") == "awt-loop/a")
        #expect(q.nextBySource(alive: alive, order: ["willow"], after: "awt-loop") == "willow/s3")
        // 只有刚弹过的那个来源在等：照样弹它
        var r = ArrivalQueue()
        _ = r.offer("willow/s4", showing: "cooldown")
        #expect(r.nextBySource(alive: ["willow/s4"], order: ["willow"], after: "willow") == "willow/s4")
    }
}

/// 2.5 假的第二来源：与许愿柳的活动同时存在时，排序与胶囊分配仍按 2.2 的规则，不按来源程序分先后。
@MainActor
@Suite("两个来源程序同时在")
struct TwoProducerTests {
    init() { Lang.current = .zh }

    func make(_ producer: String, _ id: String, ago: Double, _ build: (inout Activity) -> Void) -> Hosted {
        var a = Activity(id: id)
        a.revision = "\(id)-r1"
        a.activityAt = t0.addingTimeInterval(-ago)
        build(&a)
        return Hosted(producer: producer, activity: a, writtenAt: nil)
    }

    @Test("队列停了心跳（异常）压过许愿柳没看过的声明；队列恢复在跑后，许愿柳没看过的占两翼、队列进胶囊；在跑计数各算各的")
    func mixed() throws {
        let h = try TempHome()
        try h.register("willow")
        try h.register("fake-queue", events: ["job-done": .init(attention: true)])
        var willow = Activity(id: "sess-a")
        willow.revision = "t1"; willow.activityAt = t0; willow.flagged = true; willow.running = false
        willow.label = .init(text: "审计仓库", tone: .white); willow.labelUntilSeen = true
        var p = Activity.Pill(); p.dot = .orange; p.title = "新声明"; willow.pill = p; willow.pillUntilSeen = true
        try h.write(willow)
        var queue = Activity(id: "night-run")
        queue.revision = "3of8"; queue.activityAt = t0.addingTimeInterval(-60); queue.running = true; queue.inProgress = true
        queue.heartbeatSeconds = 60
        queue.label = .init(text: "实验 3/8", tone: .white)
        var qp = Activity.Pill(); qp.symbol = "ellipsis"; qp.pulse = true; qp.title = "3/8"; queue.pill = qp
        let url = try h.write(queue, producer: "fake-queue")
        let seen = SeenStore(ephemeral: true)
        let now = Date()

        // 队列 100 秒没写：心跳超时 → 异常，排在最前；许愿柳进胶囊
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-100)], ofItemAtPath: url.path)
        var s = Scanner.scan(h.paths, now: now)
        var pair = Ordering.pair(s.activities, seen, pinned: nil)
        #expect(pair.primary?.id == "fake-queue/night-run")
        #expect(pair.primary?.activity.rank == .anomaly)
        #expect(pair.secondary?.id == "willow/sess-a")

        // 队列刚写过：不异常。许愿柳没看过且自标不一致 → 两翼；队列在进行 → 胶囊
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
        s = Scanner.scan(h.paths, now: now)
        pair = Ordering.pair(s.activities, seen, pinned: nil)
        #expect(pair.primary?.id == "willow/sess-a")
        #expect(pair.secondary?.id == "fake-queue/night-run")
        #expect(Ordering.parallel(s.activities, producer: "fake-queue").running == 1)
        #expect(Ordering.parallel(s.activities, producer: "willow").running == 0)

        // 看过许愿柳那一项：它缩回，队列提成主项
        seen.markSeen(s.activities.first { $0.id == "willow/sess-a" }!)
        pair = Ordering.pair(s.activities, seen, pinned: nil)
        #expect(pair.primary?.id == "fake-queue/night-run")
    }
}

@MainActor
@Suite("多来源")
struct MultiSourceTests {
    func hosted(_ producer: String, _ id: String) -> Hosted {
        var a = Activity(id: id)
        a.revision = "\(id)-t"
        return Hosted(producer: producer, activity: a, writtenAt: nil)
    }

    @Test("只有一个来源程序时不算多来源；两个及以上才算（收起态与胶囊据此决定画不画来源标记）")
    func multiSource() {
        #expect(!Ordering.multiSource([]))
        #expect(!Ordering.multiSource([hosted("willow", "a"), hosted("willow", "b")]))
        #expect(Ordering.multiSource([hosted("willow", "a"), hosted("awt-loop", "draft")]))
    }
}
