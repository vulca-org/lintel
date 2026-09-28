import Testing
@testable import LintelUI

/// 点稿件小岛（作者 09-28 交互测试第 16 条）：悬停 0.3 秒小岛就并进主岛展开，点下去落在主岛上、开的是弹出框，
/// 设计里的「开窗口并选中稿件」永远到不了。从小岛展开的卡，点它就按小岛的设计走。
@MainActor
@Suite("点小岛：从小岛展开的卡开窗口")
struct IslandClickTests {
    @Test("从小岛展开、还显示着那份稿件：开窗口并选中它")
    func islandCard() {
        #expect(StageController.clickTarget(expanded: true, popover: false, pinned: "loop/paper-a", fromIsland: "loop/paper-a") == .window("loop/paper-a"))
    }

    @Test("悬停主岛展开的卡、收起态、弹出框开着：照旧开弹出框")
    func others() {
        #expect(StageController.clickTarget(expanded: true, popover: false, pinned: "willow/a", fromIsland: nil) == .popover)
        #expect(StageController.clickTarget(expanded: false, popover: false, pinned: nil, fromIsland: "loop/paper-a") == .popover)
        #expect(StageController.clickTarget(expanded: true, popover: true, pinned: "loop/paper-a", fromIsland: "loop/paper-a") == .popover)
    }

    @Test("从小岛展开后又换成别的在显示：开弹出框")
    func switched() {
        #expect(StageController.clickTarget(expanded: true, popover: false, pinned: "willow/a", fromIsland: "loop/paper-a") == .popover)
    }
}
