import Foundation
import Testing
@testable import LintelCore

/// F1（负担实测 2026-09-18）：宿主空闲时每 5 秒、每次文件变动都把全部活动重读、重校验一遍，
/// 其中 50 个已关闭的活动不会再变；健康那一项每次扫描都换一个时刻，于是「没变」也被当成「变了」去重绘。
@MainActor
@Suite("F1 扫描的开销")
struct ScanCostTests {
    init() { Lang.current = .zh }

    @Test("增量扫描：没变的文件不重读；改过的文件、该来源的登记变了才重读；结果与全量扫描一致")
    func incremental() throws {
        let h = try TempHome()
        try h.register()
        try h.write(Activity(id: "a"))
        try h.write(Activity(id: "b"))
        let cache = ScanCache()
        let now = Date()
        let first = Scanner.scan(h.paths, now: now, cache: cache)
        #expect(cache.reads == 2)
        let second = Scanner.scan(h.paths, now: now, cache: cache)
        #expect(cache.reads == 2)
        #expect(second == first)
        #expect(second == Scanner.scan(h.paths, now: now))

        var b = Activity(id: "b")
        b.label = .init(text: "改过", tone: .white)
        try h.write(b)
        let third = Scanner.scan(h.paths, now: now, cache: cache)
        #expect(cache.reads == 3)
        #expect(third.activities.first { $0.id == "willow/b" }?.activity.label?.text == "改过")

        try h.register("other", events: [:])       // 别的来源登记变了：willow 的不用重读
        _ = Scanner.scan(h.paths, now: now, cache: cache)
        #expect(cache.reads == 3)
        try h.register("willow", events: ["declaration": .init(attention: true)])   // willow 自己的登记变了：重新校验
        _ = Scanner.scan(h.paths, now: now, cache: cache)
        #expect(cache.reads == 5)

        try FileManager.default.removeItem(at: h.paths.activities("willow").appendingPathComponent("a.json"))
        let gone = Scanner.scan(h.paths, now: now, cache: cache)
        #expect(!gone.activities.contains { $0.id == "willow/a" })
        #expect(cache.entries.count == 1)          // 删掉的文件不在缓存里留着，常驻进程的内存不跟着历史涨
        #expect(gone == Scanner.scan(h.paths, now: now))
    }

    @Test("拒收的文件没变也不重读，拒收照样报")
    func rejectsCached() throws {
        let h = try TempHome()
        try h.register()
        _ = try h.writeRaw("{ not json", file: "bad.json")
        let cache = ScanCache()
        let a = Scanner.scan(h.paths, cache: cache)
        let b = Scanner.scan(h.paths, cache: cache)
        #expect(cache.reads == 1)
        #expect(a.rejects == b.rejects)
        #expect(!b.rejects.isEmpty)
    }

    @Test("原地改写（inode 不变）也认得出：按修改时刻与大小")
    func rewrittenInPlace() throws {
        let h = try TempHome()
        try h.register()
        let url = try h.writeRaw("{ not json", file: "x.json")
        let cache = ScanCache()
        #expect(!Scanner.scan(h.paths, cache: cache).rejects.isEmpty)
        let inode = try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? NSNumber
        let fixed = try JSONEncoder().encode(Activity(id: "x"))
        try fixed.write(to: url)                   // 不走临时文件改名：同一个 inode
        #expect(try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? NSNumber == inode)
        let s = Scanner.scan(h.paths, cache: cache)
        #expect(s.rejects.isEmpty)
        #expect(s.activities.contains { $0.id == "willow/x" })
        #expect(cache.reads == 2)
    }

    @Test("心跳按此刻算，不被缓存冻住")
    func heartbeatNotFrozen() throws {
        let h = try TempHome()
        try h.register()
        var a = Activity(id: "q")
        a.heartbeatSeconds = 60
        a.label = .init(text: "跑实验", tone: .white)
        let url = try h.write(a)
        let now = Date()
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-80)], ofItemAtPath: url.path)
        let cache = ScanCache()
        #expect(Scanner.scan(h.paths, now: now, cache: cache).activities.first?.activity.rank == Activity.Rank.none)
        #expect(Scanner.scan(h.paths, now: now.addingTimeInterval(20), cache: cache).activities.first?.activity.rank == .anomaly)
        #expect(cache.reads == 1)
    }

    @Test("问题没变时健康那一项不随时间变，也不再回调重排（先前每 5 秒一次）")
    func healthStable() throws {
        let h = try TempHome()                     // 没有登记：常亮一项健康问题
        let store = ActivityStore(paths: h.paths)
        var reloads = 0
        store.onReload = { reloads += 1 }
        store.reload(now: t0)
        let before = store.activities
        #expect(before.contains { $0.producer == Health.producer })
        store.reload(now: t0.addingTimeInterval(5))
        #expect(store.activities == before)
        #expect(reloads == 1)
        try h.register()                           // 问题变了：照常更新、回调
        store.reload(now: t0.addingTimeInterval(10))
        #expect(reloads == 2)
    }
}
