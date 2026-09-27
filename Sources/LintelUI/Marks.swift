import SwiftUI
import LintelCore

/// 两个标志的构造网格（B-5 第二版，作者 2026-09-22 采用；构造图与推导在 `docs/design/logo-2026-09-22/`）。
///
/// 所有坐标都写成网格单位 u，画的时候按 `rect` 的边长 ÷ 34 换算，所以每一笔都能对回构造图：
/// - 画布 34u，笔画 3u，长度只取斐波那契数；
/// - 括号：外框 19 × 21，转角是同心圆对 (2, 5)（中心线半径 3.5），圆弧之后接直臂 2，两臂尖之间开口 5；
/// - 状态符号：放在中心 8 × 8 的格子里，笔画 2u，圆头；
/// - 24 pt 以下（刘海上的 14、18、20 pt 全在这一档）用小尺寸版：画布降一级到 21u，笔画与符号的长度不跟着缩，
///   转角只用圆接头。括号外框 19 × 21 撑满画布（sheet-10 的 B），W 框 13 × 8（sheet-9 的 B）。
///   实拍发现第二版原样在 14 pt 读成 ( )：(2, 5) 转角吃掉臂的 5/7，括号又只占画布 62%。
enum MarkGrid {
    static let smallBelow: CGFloat = 24
    static let canvas: CGFloat = 34
    static let stroke: CGFloat = 3
    static let symbolStroke: CGFloat = 2

    // 括号外框与转角
    static let left: CGFloat = 7.5, right: CGFloat = 26.5, top: CGFloat = 6.5, bottom: CGFloat = 27.5
    static let cornerOuter: CGFloat = 5
    static let centreRadius: CGFloat = 3.5   // (2 + 5) / 2
    static let arm: CGFloat = 2

    /// 左臂尖与右臂尖之间的距离（构造图上的「开口 5」）。
    static var opening: CGFloat { (right - cornerOuter - arm) - (left + cornerOuter + arm) }

    // 小尺寸括号（21u 画布）：外框 3 + 13 + 3 = 19 宽、21 高，臂从外沿量 5，直角圆接头
    static let smallLeft: CGFloat = 1, smallRight: CGFloat = 20, smallTop: CGFloat = 0, smallBottom: CGFloat = 21
    static let smallArm: CGFloat = 5
    static var smallOpening: CGFloat { (smallRight - smallArm) - (smallLeft + smallArm) }

    // 许愿柳小尺寸 W
    static let smallCanvas: CGFloat = 21
    static let smallBoxX: CGFloat = 4, smallBoxY: CGFloat = 6.5
    static let smallPoints: [CGPoint] = [(0, 0), (3, 8), (6.5, 3), (10, 8), (13, 0)]
        .map { CGPoint(x: smallBoxX + $0.0, y: smallBoxY + $0.1) }

    /// 网格坐标 → `rect` 里的点：34u（或 `canvas`）画布居中放进 `rect` 的内切正方形。
    static func mapper(_ r: CGRect, canvas c: CGFloat = canvas) -> (CGFloat, CGFloat) -> CGPoint {
        let side = min(r.width, r.height)
        let k = side / c
        let ox = r.midX - side / 2, oy = r.midY - side / 2
        return { x, y in CGPoint(x: ox + x * k, y: oy + y * k) }
    }
}

/// 括号形（身份 B，作者 2026-09-18；几何按 B-5 第二版）：画的是笔画中心线，调用方用 3u 的笔画描边、端头平切。
/// `small`：24 pt 以下的小尺寸版（21u 画布、直角圆接头）。
struct BracketShape: Shape {
    var small = false

    func path(in r: CGRect) -> Path {
        let g = MarkGrid.self
        var path = Path()
        if small {
            let p = g.mapper(r, canvas: g.smallCanvas)
            let lx = g.smallLeft + g.stroke / 2, rx = g.smallRight - g.stroke / 2
            let ty = g.smallTop + g.stroke / 2, by = g.smallBottom - g.stroke / 2
            let la = g.smallLeft + g.smallArm, ra = g.smallRight - g.smallArm
            path.move(to: p(la, ty)); path.addLine(to: p(lx, ty)); path.addLine(to: p(lx, by)); path.addLine(to: p(la, by))
            path.move(to: p(ra, ty)); path.addLine(to: p(rx, ty)); path.addLine(to: p(rx, by)); path.addLine(to: p(ra, by))
            return path
        }
        let p = g.mapper(r)
        let k = min(r.width, r.height) / g.canvas
        let lx = g.left + g.stroke / 2, rx = g.right - g.stroke / 2
        let ty = g.top + g.stroke / 2, by = g.bottom - g.stroke / 2
        let lArm = g.left + g.cornerOuter + g.arm, rArm = g.right - g.cornerOuter - g.arm
        // 左括号：臂尖 → 上转角 → 竖笔 → 下转角 → 臂尖
        path.move(to: p(lArm, ty))
        path.addArc(tangent1End: p(lx, ty), tangent2End: p(lx, by), radius: g.centreRadius * k)
        path.addArc(tangent1End: p(lx, by), tangent2End: p(lArm, by), radius: g.centreRadius * k)
        path.addLine(to: p(lArm, by))
        // 右括号：对称
        path.move(to: p(rArm, ty))
        path.addArc(tangent1End: p(rx, ty), tangent2End: p(rx, by), radius: g.centreRadius * k)
        path.addArc(tangent1End: p(rx, by), tangent2End: p(rArm, by), radius: g.centreRadius * k)
        path.addLine(to: p(rArm, by))
        return path
    }

    static func isSmall(_ size: CGFloat) -> Bool { size < MarkGrid.smallBelow }
    static func lineWidth(_ size: CGFloat) -> CGFloat {
        size * MarkGrid.stroke / (isSmall(size) ? MarkGrid.smallCanvas : MarkGrid.canvas)
    }
}

/// 状态符号，画在括号中间（大尺寸是 8 × 8 的格子）。坐标写成离画布中心的偏移，长度在两种画布上相同（不跟着缩）。
/// 描边部分与实心部分分开给，调用方各自上色。
struct GridSymbol {
    let stroke: Path
    let fill: Path

    static func of(_ c: Activity.Center?, in r: CGRect, canvas: CGFloat = MarkGrid.canvas) -> GridSymbol {
        let m = MarkGrid.mapper(r, canvas: canvas)
        let h = canvas / 2
        let p = { (dx: CGFloat, dy: CGFloat) in m(h + dx, h + dy) }
        let k = min(r.width, r.height) / canvas
        var s = Path(), f = Path()
        func dot(_ dx: CGFloat, _ dy: CGFloat, _ radius: CGFloat) {
            let q = p(dx, dy)
            f.addEllipse(in: CGRect(x: q.x - radius * k, y: q.y - radius * k, width: 2 * radius * k, height: 2 * radius * k))
        }
        switch c {
        case nil, .idle?:
            // 横 5
            s.move(to: p(-2.5, 0)); s.addLine(to: p(2.5, 0))
        case .done?:
            // 短边 2、长边 5，都是 45°
            s.move(to: p(-3, 0)); s.addLine(to: p(-1, 2)); s.addLine(to: p(4, -3))
        case .flagged?, .broken?:
            // 竖 3 · 空 2 · 点 2
            s.move(to: p(0, -3.5)); s.addLine(to: p(0, -0.5)); dot(0, 3.5, 1)
        case .waiting?:
            // 半径 2.5 的圆弧 · 点 2
            s.move(to: p(-2.5, -1.5))
            s.addArc(center: p(0, -1.5), radius: 2.5 * k, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: false)
            dot(0, 4, 1)
        case .live?:
            // 直径 5 的实心点
            dot(0, 0, 2.5)
        case .withdrawn?:
            // 回折箭头：箭头 2、横 5、半径 2.5 的回弯
            s.move(to: p(-1.5, -3.5)); s.addLine(to: p(-3.5, -1.5)); s.addLine(to: p(-1.5, 0.5))
            s.move(to: p(-3.5, -1.5)); s.addLine(to: p(1.5, -1.5))
            s.addArc(center: p(1.5, 1), radius: 2.5 * k, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            s.addLine(to: p(-1, 3.5))
        case .superseded?:
            // ◇：半对角线 2.5
            s.move(to: p(0, -2.5)); s.addLine(to: p(2.5, 0)); s.addLine(to: p(0, 2.5)); s.addLine(to: p(-2.5, 0)); s.closeSubpath()
        case .assumed?:
            // ◌：半径 2.5 的虚线圆，调用方用虚线描
            let q = p(-2.5, -2.5)
            s.addEllipse(in: CGRect(x: q.x, y: q.y, width: 5 * k, height: 5 * k))
        }
        return GridSymbol(stroke: s, fill: f)
    }

    static func lineWidth(_ size: CGFloat) -> CGFloat {
        size * MarkGrid.symbolStroke / (BracketShape.isSmall(size) ? MarkGrid.smallCanvas : MarkGrid.canvas)
    }

    /// ◌ 的虚线：半径 2.5 的圆分成 4 段实 4 段空，平头，一圈正好闭合。圆头会把空隙两边各吃掉半个笔画，
    /// 原来的 [0.9, 1.1] × 笔画配圆头，看得见的空隙只剩 0.1 个笔画，读成实心圈（grill 09-22）。
    static let ringDashes: CGFloat = 4
    static func dash(_ c: Activity.Center?, size: CGFloat) -> (pattern: [CGFloat], cap: CGLineCap) {
        guard c == .assumed else { return ([], .round) }
        let k = size / (BracketShape.isSmall(size) ? MarkGrid.smallCanvas : MarkGrid.canvas)
        let seg = 2 * .pi * 2.5 * k / (2 * ringDashes)
        return ([seg, seg], .butt)
    }
}

struct GridSymbolView: View {
    let center: Activity.Center?
    var tint: Color
    var size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let r = CGRect(origin: .zero, size: sz)
            let side = min(sz.width, sz.height)
            let g = GridSymbol.of(center, in: r, canvas: BracketShape.isSmall(side) ? MarkGrid.smallCanvas : MarkGrid.canvas)
            let lw = GridSymbol.lineWidth(side)
            let dash = GridSymbol.dash(center, size: side)
            ctx.stroke(g.stroke, with: .color(tint), style: StrokeStyle(lineWidth: lw, lineCap: dash.cap, lineJoin: .round, dash: dash.pattern))
            ctx.fill(g.fill, with: .color(tint))
        }
        .frame(width: size, height: size)
    }
}

/// 许愿柳的 W，小尺寸版（24 pt 以下）：21u 画布里 13 × 8 的 W，圆接头，两端沿框顶切平。
struct WillowSmallShape: Shape {
    func path(in r: CGRect) -> Path {
        let g = MarkGrid.self
        let p = g.mapper(r, canvas: g.smallCanvas)
        var pts = g.smallPoints
        // 两端顺着线段各延长 3u，再由 `topCut` 在框顶切平（端头不是斜的圆头）
        func extend(_ a: CGPoint, from b: CGPoint) -> CGPoint {
            let dx = a.x - b.x, dy = a.y - b.y, n = (dx * dx + dy * dy).squareRoot()
            return CGPoint(x: a.x + dx / n * 3, y: a.y + dy / n * 3)
        }
        pts[0] = extend(pts[0], from: pts[1])
        pts[pts.count - 1] = extend(pts[pts.count - 1], from: pts[pts.count - 2])
        var path = Path()
        path.move(to: p(pts[0].x, pts[0].y))
        for q in pts.dropFirst() { path.addLine(to: p(q.x, q.y)) }
        return path
    }

    /// 框顶在 `rect` 里的纵坐标：W 从这里往下才画。
    static func topCut(in r: CGRect) -> CGFloat { MarkGrid.mapper(r, canvas: MarkGrid.smallCanvas)(0, MarkGrid.smallBoxY).y }
    static func lineWidth(_ size: CGFloat) -> CGFloat { size * MarkGrid.stroke / MarkGrid.smallCanvas }
}

/// 来源标记里的许愿柳：白 12% 的圆盘加小尺寸 W（作者 2026-09-22：W 用白色）。
struct WillowMark: View {
    var size: CGFloat = 14

    var body: some View {
        Canvas { ctx, sz in
            let r = CGRect(origin: .zero, size: sz)
            ctx.fill(Path(ellipseIn: r), with: .color(Color.white.opacity(0.12)))
            var clipped = ctx
            let cut = WillowSmallShape.topCut(in: r)
            clipped.clip(to: Path(CGRect(x: 0, y: cut, width: sz.width, height: sz.height - cut)))
            clipped.stroke(WillowSmallShape().path(in: r), with: .color(.white),
                           style: StrokeStyle(lineWidth: WillowSmallShape.lineWidth(min(sz.width, sz.height)), lineCap: .butt, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}
