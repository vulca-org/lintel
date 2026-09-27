import Testing
import Foundation
@testable import LintelCore
@testable import LintelUI

/// 稿件的环怎么排（åé¨ spec 2026-09-24 W1–W4 加「设计」一环，分镜 ⑦⑥ ⑦⑧ ⑧⓪）：只测排法，不测像素。
@MainActor
@Suite("稿件的环：排法")
struct RingLayoutTests {
    typealias Seg = Activity.Ring.Segment
    static let keys = ["comment", "design", "rewrite", "check", "readers", "review", "land"]

    func ring(current: String? = "design", items: [String: Int] = ["design": 1], closed: Int = 0) -> Activity.Ring {
        .init(name: "合成稿", since: "这一轮从 2026-09-24 算起（台账只记日期，精确到日）",
              segments: Self.keys.map { k in
                  let n = items[k] ?? 0
                  return Seg(key: k, name: k, state: n > 0 ? .waiting : .open, sight: k == "land" ? .commits : .seen, sightNote: "看得见",
                             note: n > 0 ? "等你 \(n)" : "还没到",
                             items: (0..<n).map { .init(id: "\(k)\($0)", text: "合成事项 \($0)", you: true) })
              },
              current: current, latest: "comment", latestAt: nil, unhung: [], waiting: items.values.reduce(0, +),
              closed: (0..<closed).map { .init(date: "2026-09-2\($0)", items: ["B\($0)（abcd1234）"]) },
              labels: .init(title: "这一轮", current: "当前", latest: "最近动静", unhung: "没挂上环节", closed: "已关的门", waiting: "等你"),
              error: nil)
    }

    @Test("环形小图标：几环几段弧，从 12 点起顺时针等分，段与段之间留缝")
    func arcs() {
        let a = RingLayout.arcs(count: 7, gap: 14)
        #expect(a.count == 7)
        #expect(abs(a[0].start - (-90 + 7)) < 1e-9)
        let spans = a.map { $0.end - $0.start }
        #expect(spans.allSatisfy { abs($0 - (360.0 / 7 - 14)) < 1e-9 })
        #expect(abs(a[6].end - (270 - 7)) < 1e-9)
        #expect(RingLayout.arcs(count: 0).isEmpty)
    }

    @Test("面板默认看哪一环：当前环；没有当前环就第一个挂着事的环")
    func focus() {
        #expect(RingLayout.focus(ring()) == "design")
        #expect(RingLayout.focus(ring(current: nil, items: ["check": 1, "review": 2])) == "check")
        #expect(RingLayout.focus(ring(current: nil, items: [:])) == nil)
    }

    @Test("已关的门一行：最近两天各一段，更早的只写几天")
    func closedLine() {
        #expect(RingLayout.closedLine(ring(closed: 0)) == nil)
        let line = RingLayout.closedLine(ring(closed: 4)) ?? ""
        #expect(line.hasPrefix("09-20 B0（abcd1234） · 09-21 B1（abcd1234）"))
        #expect(line.contains("2"), "更早 2 天")
    }

}
