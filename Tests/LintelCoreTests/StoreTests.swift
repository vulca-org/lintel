import Foundation
import Testing
@testable import LintelCore

@MainActor
@Suite("来源、拒收日志、心跳、事件")
struct StoreTests {
    init() { Lang.current = .zh }

    @Test("1.4 来源由目录决定：放在 a 目录里、文字自称来自 b 的活动，宿主记的来源仍是 a")
    func provenanceByDirectory() throws {
        let h = try TempHome()
        try h.register("a", events: [:])
        try h.register("b", events: [:])
        var fake = Activity(id: "x")
        fake.label = .init(text: "来自 b", tone: .white)
        fake.group = .init(id: "b", name: "b")
        try h.write(fake, producer: "a")
        let s = Scanner.scan(h.paths)
        #expect(s.activities.map(\.producer) == ["a"])
        #expect(s.activities.first?.id == "a/x")
    }

    @Test("没登记的来源程序目录里的活动被拒收，写进 rejects.jsonl，同一原因只记一次；健康状态里有它")
    func rejectLog() throws {
        let h = try TempHome()
        try h.register("willow")
        try h.write(Activity(id: "ok"))
        try h.write(Activity(id: "nope"), producer: "stranger")
        let store = ActivityStore(paths: h.paths)
        store.reload()
        store.reload()
        #expect(store.activities.filter { $0.producer != Health.producer }.map(\.id) == ["willow/ok"])
        #expect(store.activities.contains { $0.id == "lintel/health" })
        #expect(store.rejects.count == 1)
        #expect(store.issues.contains { $0.kind == .rejected && $0.producer == "stranger" })
        let lines = try String(contentsOf: h.paths.rejects, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 1)
        #expect(lines.first?.contains("没有登记") == true)
    }

    @Test("没有登记文件：健康状态常亮，不是空白")
    func missingRegistry() throws {
        let h = try TempHome()
        let s = Scanner.scan(h.paths)
        #expect(s.issues.contains { $0.kind == .registryUnreadable })
    }

    @Test("2.3 心跳：声明 60 秒，写入 80 秒后正常，91 秒后变异常、写「没有消息，不代表已经结束」")
    func heartbeat() throws {
        let h = try TempHome()
        try h.register()
        var a = Activity(id: "q")
        a.heartbeatSeconds = 60
        a.label = .init(text: "跑实验", tone: .white)
        let url = try h.write(a)
        let now = Date()
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-80)], ofItemAtPath: url.path)
        var s = Scanner.scan(h.paths, now: now)
        #expect(s.activities.first?.activity.rank == Activity.Rank.none)
        #expect(!s.issues.contains { $0.kind == .heartbeat })
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-91)], ofItemAtPath: url.path)
        s = Scanner.scan(h.paths, now: now)
        #expect(s.activities.first?.activity.rank == .anomaly)
        #expect(s.activities.first?.activity.status?.center == .broken)
        #expect(s.issues.contains { $0.kind == .heartbeat && $0.text.contains("不代表已经结束") })
    }

    @Test("事件：启动时文件里已有的不算新到；之后新增的只触发一次；没登记为事件的不触发")
    func events() throws {
        let h = try TempHome()
        try h.register()
        var a = Activity(id: "s")
        a.events = [.init(id: "declaration|t1", type: "declaration", at: t0)]
        try h.write(a)
        let store = ActivityStore(paths: h.paths)
        var fired: [String] = []
        store.onEvent = { _, e, spec in fired.append("\(e.id)|\(spec.attention)") }
        store.reload()
        #expect(fired.isEmpty)
        a.events.append(.init(id: "choice|q1", type: "choice", at: t0.addingTimeInterval(5)))
        try h.write(a)
        store.reload()
        store.reload()
        #expect(fired == ["choice|q1|true"])
    }
}

@MainActor
@Suite("宿主健康状态常亮")
struct HealthTests {
    init() { Lang.current = .zh }

    @Test("没有登记：刘海上多出一项来源为 lintel 的异常，排在最前；问题消失后这一项也消失")
    func healthActivity() throws {
        let h = try TempHome()
        var s = Scanner.scan(h.paths)
        let seen = SeenStore(ephemeral: true)
        #expect(s.activities.first?.producer == "lintel")
        #expect(Ordering.focus(s.activities, seen)?.activity.rank == .anomaly)
        #expect(s.activities.first.flatMap { Ordering.label($0, seen) }?.text.isEmpty == false)
        try h.register()
        var a = Activity(id: "ok"); a.label = .init(text: "x", tone: .white)
        try h.write(a)
        s = Scanner.scan(h.paths)
        #expect(!s.activities.contains { $0.producer == "lintel" })
    }

    @Test("拒收也常亮：写明哪个来源程序被拒了几份")
    func rejectShows() throws {
        let h = try TempHome()
        try h.register()
        try h.write(Activity(id: "nope"), producer: "stranger")
        let s = Scanner.scan(h.paths)
        let health = s.activities.first { $0.producer == "lintel" }
        #expect(health?.activity.popup.first?.text.contains("stranger") == true)
    }
}
