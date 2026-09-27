import Testing
import Foundation
@testable import LintelCore
@testable import LintelUI

/// 对话的长清单怎么排（åé¨ spec 2026-09-24 对话层 V1–V6，分镜 ⑦④ ⑦⑦ ⑦⑨）：只测排法，不测像素。
@MainActor
@Suite("对话的长清单：排法")
struct ChainLayoutTests {
    private func chain(_ states: [Activity.Chain.State]) -> Activity.Chain {
        .init(items: states.enumerated().map { i, s in .init(id: "L\(i + 1)", text: "事项 \(i + 1)", state: s, note: nil, approved: nil, idle: nil) },
              problems: [], labels: .init(done: "做完", doing: "在做", you: "等你", other: "等别的", later: "以后"), error: nil)
    }

    @Test("一行的主行是标题、第二行是现在那句：新写法读 now；旧写法（只有 was）把 was 当标题；都没写就只有标题（第二轮 N3）")
    func titleAndCurrent() {
        var x = Activity.Chain.Item(id: "L1", text: "合 #78 与 #80", state: .you, note: nil, approved: nil, idle: nil)
        #expect(x.title == "合 #78 与 #80" && x.current == nil)
        x.now = "CI 绿了合 #78"
        #expect(x.title == "合 #78 与 #80" && x.current == "CI 绿了合 #78")
        var old = Activity.Chain.Item(id: "L2", text: "CI 绿了合 #78", state: .you, note: nil, approved: nil, idle: nil)
        old.was = "合 #78 与 #80"
        #expect(old.title == "合 #78 与 #80" && old.current == "CI 绿了合 #78")
    }

    @Test("旁注：等什么、几轮没动、你认可过、依据，任一有就画（第二轮 N1/N2：这一行在 753715f 后没人画）")
    func metaHas() {
        var x = Activity.Chain.Item(id: "L1", text: "事项", state: .other, note: nil, approved: nil, idle: nil)
        #expect(!ChainMeta.has(x))
        x.wait = "CI"
        #expect(ChainMeta.has(x))
        var y = Activity.Chain.Item(id: "L2", text: "事项", state: .you, note: nil, approved: nil, idle: 23)
        #expect(ChainMeta.has(y))
        y.idle = nil; y.approved = true
        #expect(ChainMeta.has(y))
    }

    @Test("收起态方块：按做完 → 在做 → 等你 → 等别的 → 以后排，读起来像一条进度")
    func squaresOrder() {
        let c = chain([.you, .done, .later, .doing, .other, .done])
        #expect(ChainLayout.squares(c) == [.done, .done, .doing, .you, .other, .later])
    }

    @Test("收起态最多 6 格：先留开着的，做完的只补剩下的格")
    func squaresCap() {
        let c = chain(Array(repeating: .done, count: 20) + [.doing, .you, .you])
        let sq = ChainLayout.squares(c)
        #expect(sq.count == 6)
        #expect(sq == Array(repeating: .done, count: 3) + [.doing, .you, .you])
        let many = chain(Array(repeating: .you, count: 15) + [.done])
        #expect(ChainLayout.squares(many) == Array(repeating: .you, count: 6))
    }

    @Test("悬停「此刻」：在做的（最多 2）加等你的前几项，一共最多 3 行、有等你的至少一项（统一高的展开卡里放得下时间轴）")
    func now() {
        let c = chain([.done, .you, .doing, .you, .you, .you, .other])
        #expect(ChainLayout.now(c).map(\.id) == ["L3", "L2", "L4"])
        let two = chain([.doing, .you, .doing, .you, .you, .doing])
        #expect(ChainLayout.now(two).map(\.id) == ["L1", "L3", "L2"], "两项在做：等你只带一项")
        #expect(ChainLayout.now(chain([.you, .you, .you, .you])).count == 3, "没有在做：等你照旧最多三项")
    }

    @Test("点开：在做 → 等你 → 等别的 → 以后 → 做完，空的组不画")
    func groups() {
        let c = chain([.done, .later, .you, .doing])
        #expect(ChainLayout.groups(c).map(\.0) == [.doing, .you, .later, .done])
    }

    @Test("条数行按做完、在做、等你、等别的、以后的次序，零也写")
    func counts() {
        let c = chain([.done, .done, .you])
        #expect(ChainLayout.counts(c).map { "\($0.0.rawValue)\($0.1)" } == ["done2", "doing0", "you1", "other0", "later0"])
    }

    @Test("方块不把两翼撑宽：满格加状态符号不超过没有清单时的翼宽（作者 09-24：静止时刘海挡住了菜单栏）")
    func fitsWing() {
        // 两个来源同时在刘海上时左翼还有来源字母（14pt）：09-24 实拍 8 格加字母把右翼的 6 字标签挤成「减刘海补…」。
        #expect(ChainLayout.wingWidth(squares: ChainLayout.maxSquares, initial: true) <= StageController.wing)
        #expect(ChainLayout.wingWidth(squares: 0, initial: true) == 0)
    }

    @Test("几轮没动：在做的卡住了用橙色；等你、等别的、以后没动只用灰字（09-24 面板上 11 行等你全是橙色）")
    func idleTint() {
        #expect(ChainMeta.idleTint(.doing) == Tone.orange)
        for s in [Activity.Chain.State.you, .other, .later, .done] { #expect(ChainMeta.idleTint(s) == Tone.secondary) }
    }
}
