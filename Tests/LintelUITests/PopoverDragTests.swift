import AppKit
import Testing
@testable import LintelUI

/// 弹出框拖不出来（09-28 交互测试第 18 条后半，09-30 复现 D1–D5）：lintel 窗口已经开着时，系统不往看得见的窗口里拖。
/// 改法（作者 09-30 选定）：窗口开着时不交给系统，自己拖——拖过几点就关弹出框，开着的窗口跟着鼠标走、提到最前。
@Suite("弹出框：窗口开着时自己拖")
@MainActor
struct PopoverDragTests {
    @Test("窗口开着不交给系统拖；关着照旧交给系统")
    func policy() {
        #expect(ConversationPopover.nativeDetach(windowVisible: true) == false)
        #expect(ConversationPopover.nativeDetach(windowVisible: false) == true)
    }

    @Test("拖不到门槛不算；过了门槛第一次是开始，之后是移动；松手报出刚才真拖过")
    func steps() {
        var d = OwnDrag()
        #expect(d.dragged(to: CGPoint(x: 5, y: 5)) == .none, "没按下不算")
        d.begin(at: CGPoint(x: 100, y: 100))
        #expect(d.dragged(to: CGPoint(x: 103, y: 102)) == .none)
        #expect(d.dragged(to: CGPoint(x: 100, y: 90)) == .start)
        #expect(d.dragged(to: CGPoint(x: 100, y: 60)) == .move)
        #expect(d.end() == true)
        #expect(d.dragged(to: CGPoint(x: 0, y: 0)) == .none, "松手以后不再动窗口")
        d.begin(at: CGPoint(x: 0, y: 0))
        #expect(d.end() == false, "按下没拖就松手：不算拖过")
    }

    @Test("窗口顶边跟着鼠标：鼠标落在窗口顶上居中、顶边往下 14 点处；尺寸不变")
    func grabbed() {
        let f = NSRect(x: 10, y: 20, width: 800, height: 600)
        let g = LintelWindow.grabbed(f, at: NSPoint(x: 900, y: 700))
        #expect(g.size == f.size)
        #expect(g.midX == 900)
        #expect(g.maxY == 714)
    }
}
