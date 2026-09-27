import Foundation
import Testing
@testable import LintelCore

/// 候选 B（作者 09-21：只收目录，PDF 先不收）：拖到刘海上的东西，lintel 只判断收不收、只写收件文件。
@Suite("拖放收件")
struct DropTests {
    func paths() -> LintelPaths {
        LintelPaths(home: FileManager.default.temporaryDirectory.appendingPathComponent("lintel-drop-\(UUID().uuidString)", isDirectory: true))
    }

    func registry(accepts: [String]? = ["folder"]) -> Registry {
        var r = Registry()
        r.producers["awt-loop"] = .init(name: "写作循环", initial: "循", events: [:], accepts: accepts)
        r.producers["willow"] = .init(name: "许愿柳", initial: "W", events: [:])
        return r
    }

    func tempDir() throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("dropped-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    @Test("目录：交给登记了 accepts folder 的来源，收件文件写路径、时刻、schema，先写临时文件再改名")
    func folderHanded() throws {
        let p = paths(), dir = try tempDir()
        let at = Date(timeIntervalSince1970: 1_789_700_000)
        let out = Drop.receive(url: dir, registry: registry(), paths: p, now: at)
        #expect(out.kind == .handed)
        #expect(out.producer == "awt-loop" && out.name == "写作循环")
        let file = try #require(out.file)
        #expect(file.deletingLastPathComponent() == p.inbox("awt-loop"))
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        #expect(obj["schema"] as? Int == 1 && obj["kind"] as? String == "drop" && obj["from"] as? String == "lintel")
        #expect(obj["path"] as? String == dir.standardizedFileURL.path)
        #expect(obj["at"] as? String == ISO8601DateFormatter().string(from: at))
        let left = try FileManager.default.contentsOfDirectory(atPath: p.inbox("awt-loop").path)
        #expect(left.filter { $0.hasSuffix(".tmp") }.isEmpty)
    }

    @Test("面板动作：写进那个来源的收件目录，kind action，带活动 id 与动作 id，原样不改")
    func actionWritten() throws {
        let p = paths()
        let at = Date(timeIntervalSince1970: 1_789_700_000)
        let url = try #require(Drop.act(producer: "awt-loop", activity: "loop-paper", action: "credit|z1934=report bootstrap intervals", paths: p, now: at))
        #expect(url.deletingLastPathComponent() == p.inbox("awt-loop"))
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        #expect(obj["kind"] as? String == "action")
        #expect(obj["activity"] as? String == "loop-paper")
        #expect(obj["action"] as? String == "credit|z1934=report bootstrap intervals")
        #expect(obj["schema"] as? Int == 1)
        #expect(obj["from"] as? String == "lintel")
        let left = try FileManager.default.contentsOfDirectory(atPath: p.inbox("awt-loop").path)
        #expect(left == [url.lastPathComponent], "临时文件不留下：\(left)")
    }

    @Test("文件（PDF）：拒收，说明只收目录，收件目录里什么都不写")
    func fileRefused() throws {
        let p = paths()
        let pdf = FileManager.default.temporaryDirectory.appendingPathComponent("x-\(UUID().uuidString).pdf")
        try Data("pdf".utf8).write(to: pdf)
        let out = Drop.receive(url: pdf, registry: registry(), paths: p)
        #expect(out.kind == .refused)
        #expect(out.reason.contains("目录") || out.reason.contains("Folders"))
        #expect(out.file == nil)
        #expect(!FileManager.default.fileExists(atPath: p.inbox("awt-loop").path))
    }

    @Test("没有来源登记 accepts folder（或没有登记表）：拒收并说明")
    func noTaker() throws {
        let dir = try tempDir()
        #expect(Drop.receive(url: dir, registry: registry(accepts: nil), paths: paths()).kind == .refused)
        #expect(Drop.receive(url: dir, registry: nil, paths: paths()).kind == .refused)
        #expect(Drop.taker(registry(accepts: [])) == nil)
    }

    @Test("几个来源都收目录时给 id 最小的那个")
    func smallestId() {
        var r = registry()
        r.producers["aaa"] = .init(name: "甲", initial: "A", events: [:], accepts: ["folder"])
        #expect(Drop.taker(r)?.id == "aaa")
    }

    @Test("登记表里的 accepts 存得进读得出；旧登记表没有这一项也照读")
    func registryRoundTrip() throws {
        let p = paths()
        try FileManager.default.createDirectory(at: p.home, withIntermediateDirectories: true)
        try registry().save(p)
        let back = try Registry.load(p)
        #expect(back.producers["awt-loop"]?.accepts == ["folder"])
        #expect(back.producers["willow"]?.accepts == nil)
        try Data(#"{"schema":1,"producers":{"old":{"name":"旧","initial":"O","events":{}}}}"#.utf8).write(to: p.registry)
        #expect(try Registry.load(p).producers["old"]?.accepts == nil)
    }
}
