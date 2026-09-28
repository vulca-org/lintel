import Testing
@testable import LintelUI

/// 打开弹出框要激活本 app，激活会把本 app 的普通窗口一起提到最前（作者 09-28 报点悬停卡时全部面板一起出来）。
/// 这里只测「记下哪些窗口要放回去」这一步；放回去本身靠真实窗口，实测记在 docs/evidence/2026-09-28-interaction-test。
@Suite("弹出框激活：普通窗口放回原位")
struct WindowOrderTests {
    let us: Int32 = 100, other: Int32 = 200
    func e(_ n: Int, _ p: Int32, _ layer: Int = 0) -> WindowOrder.Entry { .init(number: n, pid: p, layer: layer) }

    @Test("本 app 的窗口压在别的 app 后面：记下它和前面那个窗口")
    func behind() {
        let order = [e(1, us, 27), e(2, other), e(3, us), e(4, other)]
        let k = WindowOrder.behindOthers(order, ours: us)
        #expect(k?.anchor == 2)
        #expect(k?.windows == [3])
    }

    @Test("本 app 的窗口本来就在最前：不动")
    func front() {
        let order = [e(1, us, 27), e(3, us), e(2, other)]
        #expect(WindowOrder.behindOthers(order, ours: us) == nil)
    }

    @Test("没有普通窗口、或只有别的 app：不动")
    func none() {
        #expect(WindowOrder.behindOthers([e(1, us, 27), e(2, other)], ours: us) == nil)
        #expect(WindowOrder.behindOthers([e(1, us, 27)], ours: us) == nil)
    }

    @Test("舞台与弹出框不在普通层：不算进来")
    func layers() {
        let order = [e(9, us, 28), e(1, us, 27), e(2, other), e(5, us, 28)]
        #expect(WindowOrder.behindOthers(order, ours: us) == nil)
    }

    @Test("核对次序：被提到前面时不算放好，排回那个窗口后面才算（09-28 闪烁：放好之前不显示）")
    func inPlace() {
        let keep = (anchor: 2, windows: [3])
        #expect(!WindowOrder.inPlace([e(1, us, 27), e(3, us), e(2, other)], keep))
        #expect(WindowOrder.inPlace([e(1, us, 27), e(2, other), e(3, us)], keep))
        #expect(WindowOrder.inPlace([e(3, us)], keep))   // 那个窗口不在屏上了：没法比，别一直藏着
    }
}
