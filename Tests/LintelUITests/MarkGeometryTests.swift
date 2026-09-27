import Foundation
import SwiftUI
import Testing
@testable import LintelCore
@testable import LintelUI

/// 标志的几何对回构造图（B-5 第二版，`docs/design/logo-2026-09-22/`）。画布取 34pt，于是 1u = 1pt，数字可以直接比。
@MainActor
@Suite("标志几何")
struct MarkGeometryTests {
    let r = CGRect(x: 0, y: 0, width: 34, height: 34)

    @Test("括号的中心线：外框 19 × 21 减去半个笔画，即 x 9–25、y 8–26")
    func bracketBox() {
        let b = BracketShape().path(in: r).boundingRect
        #expect(abs(b.minX - 9) < 0.01 && abs(b.maxX - 25) < 0.01, "\(b)")
        #expect(abs(b.minY - 8) < 0.01 && abs(b.maxY - 26) < 0.01, "\(b)")
        #expect(abs(BracketShape.lineWidth(34) - 3) < 0.001)
    }

    @Test("两臂尖之间开口 5：左臂尖 x 14.5，右臂尖 x 19.5（没有直臂时括号读成圆括号）")
    func bracketOpening() {
        #expect(MarkGrid.opening == 5)
        var tips: [CGFloat] = []
        BracketShape().path(in: r).forEach { el in
            switch el {
            case .move(let p): tips.append(p.x)
            case .line(let p): if abs(p.y - 8) < 0.01 || abs(p.y - 26) < 0.01 { tips.append(p.x) }
            default: break
            }
        }
        #expect(tips.contains { abs($0 - 14.5) < 0.01 }, "\(tips)")
        #expect(tips.contains { abs($0 - 19.5) < 0.01 }, "\(tips)")
    }

    @Test("四个转角都是圆弧（同心圆 (2, 5) 的中心线，半径 3.5），不是直角")
    func bracketCorner() {
        let path = BracketShape().path(in: r)
        var curves = 0
        path.forEach { if case .curve = $0 { curves += 1 }; if case .quadCurve = $0 { curves += 1 } }
        #expect(curves >= 4, "四个转角都应是圆弧，实际曲线段 \(curves)")
    }

    @Test("每种中心状态都有符号，而且都在中间 8 × 8 的格子里（加半个笔画）")
    func symbolsInBox() {
        let all: [Activity.Center?] = [nil, .idle, .done, .flagged, .broken, .waiting, .live, .withdrawn, .superseded, .assumed]
        for c in all {
            let g = GridSymbol.of(c, in: r)
            #expect(!(g.stroke.isEmpty && g.fill.isEmpty), "\(String(describing: c)) 没有符号")
            let b = g.stroke.boundingRect.union(g.fill.isEmpty ? g.stroke.boundingRect : g.fill.boundingRect)
            #expect(b.minX >= 13 - 1 && b.maxX <= 21 + 1 && b.minY >= 13 - 1 && b.maxY <= 21 + 1, "\(String(describing: c)): \(b)")
        }
    }

    @Test("要你看与跑挂了同形不同色；空闲与来源标记同为横 5")
    func sharedShapes() {
        #expect(GridSymbol.of(.flagged, in: r).stroke.boundingRect == GridSymbol.of(.broken, in: r).stroke.boundingRect)
        let bar = GridSymbol.of(nil, in: r).stroke.boundingRect
        #expect(abs(bar.width - 5) < 0.01 && bar.height < 0.01, "\(bar)")
    }

    @Test("小尺寸括号（21u）：中心线 x 2.5–18.5、y 1.5–19.5，臂尖 6 与 15，直角没有圆弧")
    func smallBracket() {
        let s = CGRect(x: 0, y: 0, width: 21, height: 21)
        let path = BracketShape(small: true).path(in: s)
        let b = path.boundingRect
        #expect(abs(b.minX - 2.5) < 0.01 && abs(b.maxX - 18.5) < 0.01 && abs(b.minY - 1.5) < 0.01 && abs(b.maxY - 19.5) < 0.01, "\(b)")
        var xs: [CGFloat] = [], curves = 0
        path.forEach { el in
            switch el {
            case .move(let q): xs.append(q.x)
            case .curve, .quadCurve: curves += 1
            default: break
            }
        }
        #expect(xs.contains { abs($0 - 6) < 0.01 } && xs.contains { abs($0 - 15) < 0.01 }, "\(xs)")
        #expect(curves == 0)
        #expect(MarkGrid.smallOpening == 9)
    }

    @Test("刘海上的三个尺寸（14、18、20 pt）都走小尺寸版，24 pt 起走第二版")
    func notchSizesAreSmall() {
        for pt: CGFloat in [14, 18, 20] { #expect(BracketShape.isSmall(pt), "\(pt)") }
        #expect(!BracketShape.isSmall(24))
        #expect(abs(BracketShape.lineWidth(21) - 3) < 0.001)       // 21u 画布上笔画仍是 3u
        #expect(abs(GridSymbol.lineWidth(21) - 2) < 0.001)         // 符号笔画仍是 2u
    }

    @Test("小画布上的符号长度不缩：横 5 仍是 5u，居中在 (10.5, 10.5)")
    func smallSymbols() {
        let s = CGRect(x: 0, y: 0, width: 21, height: 21)
        let bar = GridSymbol.of(.idle, in: s, canvas: 21).stroke.boundingRect
        #expect(abs(bar.width - 5) < 0.01 && abs(bar.midX - 10.5) < 0.01 && abs(bar.midY - 10.5) < 0.01, "\(bar)")
    }

    @Test("◌ 的虚线看得出空隙（grill 09-22）：平头、4 实 4 空、一圈闭合，空隙不小于 0.9 个笔画")
    func assumedRingDash() {
        for size: CGFloat in [14, 18, 20, 24, 34] {
            let d = GridSymbol.dash(.assumed, size: size)
            let k = size / (BracketShape.isSmall(size) ? MarkGrid.smallCanvas : MarkGrid.canvas)
            #expect(d.cap == .butt)
            #expect(abs(d.pattern.reduce(0, +) * GridSymbol.ringDashes - 2 * .pi * 2.5 * k) < 0.001)
            #expect(d.pattern[1] >= 0.9 * GridSymbol.lineWidth(size), "size \(size): gap \(d.pattern[1])")
        }
        #expect(GridSymbol.dash(.done, size: 14).pattern.isEmpty)
    }

    @Test("来源标记按来源认：只有 willow 拿到画出来的 W，首字母是 W 的别的来源不拿")
    func willowMarkByProducer() {
        let reg = Registry(producers: ["willow": .init(name: "许愿柳", initial: "W", events: [:]), "wiki": .init(name: "Wiki", initial: "W", events: [:])])
        #expect(sourceRef(reg, "willow").producer == "willow")
        #expect(sourceRef(reg, "wiki").producer == "wiki")
        #expect(sourceRef(reg, "wiki").initial == "W")
    }

    @Test("许愿柳小尺寸 W：21u 画布，笔画 3u，W 框 13 × 8，框顶切平")
    func willowSmall() {
        let s = CGRect(x: 0, y: 0, width: 21, height: 21)
        #expect(abs(WillowSmallShape.lineWidth(21) - 3) < 0.001)
        #expect(abs(WillowSmallShape.topCut(in: s) - 6.5) < 0.001)
        let b = WillowSmallShape().path(in: s).boundingRect
        // 两端延长 3u 后越过框顶，由切线截平；底部落在框底 14.5
        #expect(b.minY < 6.5 && abs(b.maxY - 14.5) < 0.01, "\(b)")
        #expect(MarkGrid.smallPoints.map(\.x) == [4, 7, 10.5, 14, 17])
    }
}
