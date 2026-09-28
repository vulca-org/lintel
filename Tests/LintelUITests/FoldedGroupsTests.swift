import Testing
@testable import LintelUI

/// 清单折叠组（作者 09-28 交互测试第 3 条）：「以后」「做完」原来共用一个开关——点开一组两组都开，而且收不回去。
@Suite("折叠组：各组各记，能收回")
struct FoldedGroupsTests {
    @Test("默认只折以后与做完；点开以后，做完仍折着")
    func separate() {
        var f = FoldedGroups()
        #expect(f.folded("a", .later) && f.folded("a", .done))
        #expect(!f.folded("a", .you) && !f.folded("a", .doing))
        f.toggle("a", .later)
        #expect(!f.folded("a", .later))
        #expect(f.folded("a", .done))
    }

    @Test("再点一次收回去")
    func refold() {
        var f = FoldedGroups()
        f.toggle("a", .done)
        f.toggle("a", .done)
        #expect(f.folded("a", .done))
    }

    @Test("换一场对话，另一场点开的组不跟过来；不折的组点了也没反应")
    func perActivity() {
        var f = FoldedGroups()
        f.toggle("a", .later)
        #expect(f.folded("b", .later))
        f.toggle("a", .you)
        #expect(!f.folded("a", .you))
    }
}
