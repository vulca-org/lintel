import AppKit
import Testing
@testable import LintelUI

/// 拖出来的窗口挪回屏内（作者 09-28 交互测试第 18 条：872 高的窗口落在 y=397，下半截出屏）。坐标是 AppKit 的，y 朝上。
@MainActor
@Suite("拖出窗口：挪回屏内")
struct WindowFitTests {
    let vis = NSRect(x: 0, y: 0, width: 1470, height: 880)

    @Test("太高：压到可见区高度，整窗在屏内")
    func tooTall() {
        let f = LintelWindow.fitted(NSRect(x: 341, y: -390, width: 797, height: 872), in: vis, min: NSSize(width: 620, height: 400))
        #expect(vis.contains(f))
        #expect(f.width == 797)
    }

    @Test("下半截出屏但不太高：往上挪，尺寸不变")
    func shift() {
        let f = LintelWindow.fitted(NSRect(x: 100, y: -200, width: 780, height: 560), in: vis)
        #expect(f == NSRect(x: 100, y: 0, width: 780, height: 560))
    }

    @Test("本来就在屏内：不动")
    func inside() {
        let r = NSRect(x: 100, y: 100, width: 780, height: 560)
        #expect(LintelWindow.fitted(r, in: vis) == r)
    }

    @Test("拖出判定：来要过窗口、原来看不见、关掉时看得见 = 拖出来了；按下没拖、原来就开着 = 不算")
    func detached() {
        #expect(ConversationPopover.detachedOnClose(requested: true, wasVisible: false, isVisible: true))
        #expect(!ConversationPopover.detachedOnClose(requested: true, wasVisible: false, isVisible: false))
        #expect(!ConversationPopover.detachedOnClose(requested: true, wasVisible: true, isVisible: true))
        #expect(!ConversationPopover.detachedOnClose(requested: false, wasVisible: false, isVisible: true))
    }
}
