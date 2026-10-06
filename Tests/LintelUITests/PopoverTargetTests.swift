import Foundation
import Testing
@testable import LintelCore
@testable import LintelUI

/// 点刘海开什么（作者 10-06「点击不开了」）：夜里许愿柳的对话全关了，刘海上只剩写作循环的稿件。
/// 弹出框只讲对话，主位稿件所在的对话已关、也没有别的开着的对话，先前静默返回，点几次都没反应（宿主日志 09:27 六次点击）。
@MainActor
@Suite("点刘海：没有开着的对话时开什么")
struct PopoverTargetTests {
    static func conversation(_ id: String, open: Bool, stale: Bool = false, at: TimeInterval = 0) -> Hosted {
        var a = Activity(id: id); a.open = open; a.stale = stale; a.activityAt = Date(timeIntervalSince1970: at)
        return Hosted(producer: "willow", activity: a, writtenAt: nil)
    }

    static func manuscript(_ id: String, within: [String], at: TimeInterval = 0) -> Hosted {
        var a = Activity(id: id); a.open = true; a.activityAt = Date(timeIntervalSince1970: at)
        a.ring = .init(name: id, since: "", segments: [], current: nil, latest: nil, latestAt: nil, unhung: [], waiting: 0, closed: [],
                       labels: .init(title: "", current: "", latest: "", unhung: "", closed: "", waiting: "等你"), error: nil)
        a.within = within.map { .init(producer: "willow", id: $0, role: .history) }
        return Hosted(producer: "awt-loop", activity: a, writtenAt: nil)
    }

    @Test("对话全关、主位是稿件：开窗口并选中这份稿件（照点稿件小岛的设计），不再什么都不开")
    func onlyManuscripts() {
        let xs = Ordering.sorted([
            Self.conversation("c-closed", open: false, stale: true, at: 10),
            Self.conversation("c-old", open: false, stale: true, at: 5),
            Self.manuscript("paper-a", within: ["c-closed"], at: 30),
            Self.manuscript("paper-b", within: ["c-old"], at: 20),
        ])
        let primary = Ordering.pair(xs, SeenStore(ephemeral: true), pinned: nil).primary
        #expect(primary?.producer == "awt-loop", "复现前提：主位是稿件（日志 shown=awt-loop/…）")
        #expect(PopoverScope.conversations(xs).isEmpty, "复现前提：一场开着的对话都没有")
        #expect(StageController.popoverTarget(primary: primary, in: xs) == .window(primary!.id))
    }

    @Test("有对话可讲时照旧：主位对话、稿件所在的对话、都不是就最近的对话")
    func conversationsUnchanged() {
        let open = Self.conversation("c-open", open: true, at: 40)
        let nested = Self.manuscript("paper-a", within: ["c-open"], at: 30)
        let loose = Self.manuscript("paper-b", within: ["c-closed"], at: 20)
        let xs = Ordering.sorted([open, nested, loose, Self.conversation("c-closed", open: false, stale: true)])
        #expect(StageController.popoverTarget(primary: open, in: xs) == .conversation(open))
        #expect(StageController.popoverTarget(primary: nested, in: xs) == .conversation(open))
        #expect(StageController.popoverTarget(primary: loose, in: xs) == .conversation(open))
    }

    @Test("什么都没有：不开")
    func nothing() {
        #expect(StageController.popoverTarget(primary: nil, in: []) == PopoverTarget.none)
    }
}

private typealias PopoverTarget = StageController.PopoverTarget
