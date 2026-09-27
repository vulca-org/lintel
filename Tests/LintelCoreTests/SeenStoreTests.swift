import Foundation
import Testing
@testable import LintelCore

/// 看过记一组（设计 2026-09-22-awt-live M1）：刘海在几件事之间切换再切回来时，看过的那件不再重新亮起。
/// 旧宿主只认 `seen.json`（活动 id → 一个版本），所以那个文件照写最后看过的一个，一组另存 `seen-v2.json`。
@MainActor
@Suite("看过记一组")
struct SeenStoreTests {
    func home() -> LintelPaths {
        LintelPaths(home: FileManager.default.temporaryDirectory.appendingPathComponent("seen-\(UUID().uuidString)", isDirectory: true))
    }

    func hosted(_ id: String, _ rev: String) -> Hosted {
        var a = Activity(id: id)
        a.revision = rev
        return Hosted(producer: "awt-loop", activity: a, writtenAt: nil)
    }

    @Test("看过 A，再看过 B，切回 A 时 A 仍算看过；重开宿主也一样")
    func backAndForth() {
        let paths = home()
        let seen = SeenStore(paths: paths)
        seen.markSeen(hosted("loop-x", "A"))
        #expect(seen.isUnread(hosted("loop-x", "B")))
        seen.markSeen(hosted("loop-x", "B"))
        #expect(!seen.isUnread(hosted("loop-x", "A")))
        #expect(!SeenStore(paths: paths).isUnread(hosted("loop-x", "A")))
        #expect(SeenStore(paths: paths).isUnread(hosted("loop-x", "C")))
    }

    @Test("一组最多 32 个，按最近使用淘汰；再看一次算刷新")
    func leastRecentlyUsedGoesFirst() {
        let seen = SeenStore(paths: home())
        for i in 0..<SeenStore.perActivity { seen.markSeen(hosted("loop-x", "r\(i)")) }
        seen.markSeen(hosted("loop-x", "r0"))
        seen.markSeen(hosted("loop-x", "new"))
        #expect(!seen.isUnread(hosted("loop-x", "r0")))
        #expect(seen.isUnread(hosted("loop-x", "r1")))
        #expect(!seen.isUnread(hosted("loop-x", "new")))
    }

    @Test("只有旧格式 seen.json 时照读；写完之后旧宿主的读法读 seen.json 仍然完整")
    func oldFileStillWorks() throws {
        let paths = home()
        try LintelJSON.writeAtomically(try JSONEncoder().encode(["willow/s1": "t1", "awt-loop/loop-x": "A"]), to: paths.seen)
        let seen = SeenStore(paths: paths)
        #expect(!seen.isUnread(hosted("loop-x", "A")))
        seen.markSeen(hosted("loop-x", "B"))
        let old = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: paths.seen))
        #expect(old == ["willow/s1": "t1", "awt-loop/loop-x": "B"])
        #expect(!SeenStore(paths: paths).isUnread(hosted("loop-x", "A")))
    }

    @Test("旧宿主在两次之间写过 seen.json：它记下的那一版并进一组")
    func olderHostWroteInBetween() throws {
        let paths = home()
        SeenStore(paths: paths).markSeen(hosted("loop-x", "A"))
        try LintelJSON.writeAtomically(try JSONEncoder().encode(["awt-loop/loop-x": "Z"]), to: paths.seen)
        let seen = SeenStore(paths: paths)
        #expect(!seen.isUnread(hosted("loop-x", "Z")))
        #expect(!seen.isUnread(hosted("loop-x", "A")))
    }

    @Test("不落盘的一份照样记一组")
    func ephemeral() {
        let seen = SeenStore(ephemeral: true)
        seen.markSeen(hosted("loop-x", "A"))
        seen.markSeen(hosted("loop-x", "B"))
        #expect(!seen.isUnread(hosted("loop-x", "A")))
    }
}
