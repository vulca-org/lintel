import Testing
@testable import LintelUI

/// 弹出框里「还有 N 件」原来点不动：动作没传下去，按钮是灰的（09-28 交互测试第 9 条）。
@Suite("弹出框：还有 N 件开窗口")
@MainActor
struct PopoverMoreTests {
    @Test("清单页开这场对话，稿件页开那份稿件")
    func target() {
        #expect(PopoverView.moreTarget(tab: .list, conversation: "c", draft: "d") == "c")
        #expect(PopoverView.moreTarget(tab: .draft, conversation: "c", draft: "d") == "d")
        #expect(PopoverView.moreTarget(tab: .draft, conversation: "c", draft: nil) == "c")
    }

    @Test("接了窗口就有动作，点了开的是给定那一项；没接窗口就没有动作")
    func action() {
        var opened: [String] = []
        let a = PopoverView.moreAction(open: "d", onOpenWindow: { opened.append($0) })
        #expect(a != nil)
        a?()
        #expect(opened == ["d"])
        #expect(PopoverView.moreAction(open: "d", onOpenWindow: nil) == nil)
    }
}
