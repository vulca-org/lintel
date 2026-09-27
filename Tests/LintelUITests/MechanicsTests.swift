import CoreGraphics
import Foundation
import Testing
@testable import LintelCore
@testable import LintelUI

/// 从许愿柳 f4d6690 `WingWidthTests` 与 `MidTurnAndDodgeTests` 移植的刘海机制测试：断言逐字不变，被测对象换成 lintel 里搬过来的那一份。
@MainActor
@Suite("刘海机制（移植）")
struct MechanicsTests {
    @Test("两翼宽度：中文 6 字 = 92；英文 14 字符放得下且不超过上限；空标签 = 92；超长封顶")
    func widths() {
        #expect(StageController.wingWidth(label: "修上传测试") == StageController.wing)
        #expect(StageController.wingWidth(label: nil) == StageController.wing)
        #expect(StageController.wingWidth(label: "") == StageController.wing)
        let english = StageController.wingWidth(label: "Fix upload tes")
        #expect(english > StageController.wing)
        #expect(english <= StageController.wingMax)
        #expect(StageController.wingWidth(label: String(repeating: "Withdrawn ", count: 6)) == StageController.wingMax)
    }

    @Test("菜单栏让路·开始：鼠标在带子里、不在岛上才去查菜单栏；菜单栏窗口出现才让")
    func dodgeStart() {
        let band = DodgeRule.band(screen: CGRect(x: 0, y: 0, width: 1280, height: 832), height: 28)
        #expect(band == CGRect(x: 0, y: 804, width: 1280, height: 28))
        let island = CGRect(x: 440, y: 804, width: 520, height: 28)
        func wants(_ p: CGPoint, active: Bool = true) -> Bool {
            DodgeRule.wantsMenuBarCheck(active: active, pointer: p, band: band, island: island)
        }
        #expect(wants(CGPoint(x: 200, y: 832)))
        #expect(wants(CGPoint(x: 1100, y: 831.5)))
        #expect(wants(CGPoint(x: 1100, y: 815)))
        #expect(!wants(CGPoint(x: 600, y: 831)))
        #expect(!wants(CGPoint(x: 200, y: 700)))
        #expect(!wants(CGPoint(x: 200, y: 831), active: false))
        #expect(!DodgeRule.shouldStart(menuBarY: nil))
        #expect(DodgeRule.shouldStart(menuBarY: -17))
        #expect(DodgeRule.shouldStart(menuBarY: 0))
    }

    @Test("让路形状：不让路时凹肩贴屏幕上沿；让到底时颈顶回到上沿、倒角填上、两端全圆；中途与窄岛不出错")
    func dodgeShape() {
        let rect = CGRect(x: 0, y: 0, width: 352, height: 28)
        let rest = NotchShape(topRadius: 6, bottomRadius: 14).path(in: rect)
        #expect(rest.boundingRect.minY == 0)
        #expect(rest.contains(CGPoint(x: 4, y: 0.5)))
        #expect(!rest.contains(CGPoint(x: 176, y: -5)))

        let down = NotchShape(topRadius: 6, bottomRadius: 14, drop: 28, dropDepth: 28, capsule: 1, stemWidth: 156).path(in: rect)
        #expect(down.boundingRect.minY <= -28)
        #expect(down.contains(CGPoint(x: 176, y: -14)))
        #expect(down.contains(CGPoint(x: 97, y: -0.5)))
        #expect(down.contains(CGPoint(x: 255, y: -0.5)))
        #expect(!down.contains(CGPoint(x: 97, y: -9)))
        #expect(!down.contains(CGPoint(x: 4, y: 0.5)))
        #expect(!down.contains(CGPoint(x: 7, y: 1)))
        #expect(down.contains(CGPoint(x: 20, y: 14)))

        let midway = NotchShape(topRadius: 6, bottomRadius: 14, drop: 10, dropDepth: 28, capsule: 1, stemWidth: 156).path(in: rect)
        #expect(midway.boundingRect.minY <= -10)
        #expect(midway.contains(CGPoint(x: 176, y: -5)))

        let landing = NotchShape(topRadius: 6, bottomRadius: 14, drop: 1, dropDepth: 28, capsule: 1, stemWidth: 156).path(in: rect)
        #expect(landing.boundingRect.minX >= 6 - 0.01)
        let merged = NotchShape(topRadius: 6, bottomRadius: 14, drop: 0, dropDepth: 28, capsule: 0, stemWidth: 156).path(in: rect)
        #expect(merged.contains(CGPoint(x: 4, y: 0.5)))

        let narrow = NotchShape(topRadius: 6, bottomRadius: 14, drop: 28, dropDepth: 28, capsule: 1, stemWidth: 156)
            .path(in: CGRect(x: 0, y: 0, width: 156, height: 28))
        #expect(narrow.contains(CGPoint(x: 78, y: 14)))
        #expect(narrow.boundingRect.width <= 156.01)
    }

    @Test("让路时右边胶囊保持 24pt，只把顶边对齐到主体顶边；不让路时在刘海高度里居中")
    func pillFlush() {
        #expect(StageController.pillHeight == 24)
        #expect(StageController.dodgedPillCenterY(dodge: 0, depth: 28, notchHeight: 28) == 14)
        #expect(StageController.dodgedPillCenterY(dodge: 28, depth: 28, notchHeight: 28) == 12)
        #expect(StageController.dodgedPillCenterY(dodge: 14, depth: 28, notchHeight: 28) == 13)
    }

    @Test("每个词都有图形，且「图形 + 颜色」两两不同（flagged 与 broken 同形不同色，靠颜色分）")
    func everyCenterDrawn() {
        var seen: Set<String> = []
        for c in Activity.Center.allCases {
            let s = DuoGlyph.symbol(c, live: 0.5)
            #expect(!s.name.isEmpty, "\(c.rawValue) 没有图形")
            let key = "\(s.name)|\(s.tint.description)"
            #expect(!seen.contains(key), "\(c.rawValue) 的图形与颜色和前面某个词撞了：\(key)")
            seen.insert(key)
        }
        #expect(Activity.Center.allCases.count == 9)
    }

    @Test("awt-loop 的两个词各自有形状：批准的是旧版 ◇、我替你定的 ◌")
    func awtLoopCenters() {
        #expect(DuoGlyph.symbol(.superseded, live: 0).name == "diamond")
        #expect(DuoGlyph.symbol(.assumed, live: 0).name == "circle.dotted")
    }
}

/// 从许愿柳 `DuoGlyphTests` 移植（2026-09-19 许愿柳来源分支删掉画刘海的界面后，这两条只剩 lintel 有对应代码）。断言逐字不变。
@MainActor
@Suite("Duo 状态图标几何（移植）")
struct DuoGeometryTests {
    @Test("几何：外圈弧跨 230°、缺口居中在正下方；四个点全在缺口里、从左到右、等距")
    func geometry() {
        let half = (360 - DuoGeometry.arcSpan) / 2
        #expect(DuoGeometry.arcSpan == 230)
        #expect(DuoGeometry.arcStartDegrees == 90 + half)
        #expect(DuoGeometry.dotAngles.count == 4)
        #expect(DuoGeometry.dotAngles.allSatisfy { abs($0) < half })
        #expect(DuoGeometry.dotAngles == DuoGeometry.dotAngles.sorted(by: >))
        let gaps = zip(DuoGeometry.dotAngles, DuoGeometry.dotAngles.dropFirst()).map { $0 - $1 }
        #expect(Set(gaps).count == 1)
    }

    @Test("底部四点 = 并行在跑的会话数：0 个不亮，1–4 亮对应个数，超过 4 个亮满")
    func dotsCountSessions() {
        #expect(DuoGeometry.litDots(running: 0) == 0)
        #expect(DuoGeometry.litDots(running: 1) == 1)
        #expect(DuoGeometry.litDots(running: 3) == 3)
        #expect(DuoGeometry.litDots(running: 4) == 4)
        #expect(DuoGeometry.litDots(running: 9) == 4)
    }
}
