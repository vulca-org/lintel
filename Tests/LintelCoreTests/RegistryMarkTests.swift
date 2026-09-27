import Foundation
import Testing
@testable import LintelCore

@Suite("登记里的身份：形状与身份色（设计研究 2026-09-18 §6，作者定身份 B）")
struct RegistryMarkTests {
    @Test("登记了括号形与靛蓝的来源，存盘再读回来还是它；没登记形状的读成 nil")
    func roundTrip() throws {
        let h = try TempHome()
        var r = Registry()
        r.producers["awt-loop"] = .init(name: "写作循环", initial: "循", events: [:], mark: .init(shape: .bracket, tint: .indigo))
        r.producers["willow"] = .init(name: "许愿柳", initial: "W", events: [:])
        try r.save(h.paths)
        let back = try Registry.load(h.paths)
        #expect(back.producers["awt-loop"]?.mark == .init(shape: .bracket, tint: .indigo))
        #expect(back.producers["willow"]?.mark == nil)
    }

    @Test("身份 B 之前写的 registry.json 没有 mark 字段，照读，身份为空")
    func oldRegistryStillLoads() throws {
        let h = try TempHome()
        let raw = #"{"schema":1,"producers":{"willow":{"name":"许愿柳","initial":"W","events":{}}}}"#
        try FileManager.default.createDirectory(at: h.paths.home, withIntermediateDirectories: true)
        try raw.data(using: .utf8)!.write(to: h.paths.registry)
        let r = try Registry.load(h.paths)
        #expect(r.producers["willow"]?.initial == "W")
        #expect(r.producers["willow"]?.mark == nil)
    }

    @Test("靛蓝在调色板里：活动字段也能用它，校验表接受")
    func indigoIsASwatch() {
        #expect(Validation.swatches.contains("indigo"))
        #expect(Swatch(rawValue: "indigo") == .indigo)
    }
}
