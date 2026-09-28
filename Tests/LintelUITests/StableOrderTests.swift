import Testing
@testable import LintelUI

/// 侧栏顺序钉住（作者 09-28 交互测试第 13 条）：两场在跑的对话按最近动静来回换位，点下去那一刻行已经换了——实测点错三次。
@Suite("侧栏顺序：见过的不再换位")
struct StableOrderTests {
    @Test("第一次按给的顺序；之后最近动静互换，位置不变")
    func stays() {
        let o = StableOrder()
        #expect(o.arrange(["A", "B", "C"]) == ["A", "B", "C"])
        #expect(o.arrange(["B", "A", "C"]) == ["A", "B", "C"])
        #expect(o.arrange(["C", "B", "A"]) == ["A", "B", "C"])
    }

    @Test("新出现的插到最上面，新的之间按最近动静；没了的不列，其余不动")
    func newOnTop() {
        let o = StableOrder()
        _ = o.arrange(["A", "B", "C"])
        #expect(o.arrange(["E", "D", "B", "A"]) == ["E", "D", "A", "B"])
        #expect(o.arrange(["A", "E", "B", "D"]) == ["E", "D", "A", "B"])
    }

    @Test("回来的旧项回到它原来的位置")
    func comesBack() {
        let o = StableOrder()
        _ = o.arrange(["A", "B", "C"])
        _ = o.arrange(["A", "C"])
        #expect(o.arrange(["B", "C", "A"]) == ["A", "B", "C"])
    }
}
