import Testing
@testable import LintelUI

/// 弹出框的「你钉住的」（作者 09-28 交互测试第 15 条）：悬停小岛、悬停主岛、到达闪现都会改刘海正在显示的那一场（pinned），
/// 原来弹出框直接拿它当「你钉住的」——鼠标只是经过，面板却说是你钉的。
@MainActor
@Suite("你钉住的：只认亲手点选")
struct ChosenPinTests {
    @Test("悬停或闪现改了显示的那一场，没点选过：不算钉住")
    func hoverIsNotPin() {
        #expect(StageController.chosenPin(pinned: "willow/b", chosen: nil) == nil)
    }

    @Test("亲手点选、还在显示它：算钉住")
    func clickIsPin() {
        #expect(StageController.chosenPin(pinned: "willow/b", chosen: "willow/b") == "willow/b")
    }

    @Test("点选过的已经换成别的在显示：不算")
    func stale() {
        #expect(StageController.chosenPin(pinned: "loop/x", chosen: "willow/b") == nil)
        #expect(StageController.chosenPin(pinned: nil, chosen: "willow/b") == nil)
    }
}
