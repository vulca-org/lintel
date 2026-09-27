import SwiftUI
import LintelCore

/// 稿件的环（Activity.ring）怎么画（åé¨ spec 2026-09-24 W1–W4 加「设计」一环，分镜 ⑦⑥ ⑦⑧ ⑧⓪）。
/// 字都是来源写好的；这里只决定形状和颜色。颜色与对话清单同一套（`ChainTone`）：
/// 青 = 等你（台账里要你裁的事挂在这环）、橙 = 过期（检查或读者组比稿子旧）、灰阶 = 做过 / 还没到、虚线 = 这一环看不见。
/// 青与橙正是 HIG Accessibility 点名色盲难分的一对（蓝—橙），所以每格都另写字（「等你 1」「过期」），
/// 挂着的事前面也用不同形状（空心方块 / 刷新箭头），不单靠颜色。
enum RingTone {
    typealias State = Activity.Ring.State

    static func tint(_ s: State) -> Color {
        switch s {
        case .waiting: Ink.accent
        case .stale: Swatch.orange.color
        case .done: Ink.secondary
        case .open: Ink.quaternary
        case .unseen: Ink.tertiary
        }
    }

    static func fill(_ s: State) -> Color {
        switch s {
        case .waiting: Ink.accent.opacity(0.14)
        case .stale: Swatch.orange.color.opacity(0.14)
        case .done: Ink.fill
        case .open, .unseen: .clear
        }
    }
}

enum RingLayout {
    typealias Segment = Activity.Ring.Segment

    /// 收起态左翼里环形小图标的边长；左翼要的宽 = 两侧内边距 12 + 状态符号 18 + 间距 4 + 它（有来源字母时再加 14 + 4）。
    static let wingGlyph: CGFloat = 15
    static func wingWidth(initial: Bool) -> CGFloat { 12 + (initial ? 14 + 4 : 0) + 18 + 4 + wingGlyph }

    /// 面板里默认看哪一环挂着的事：当前环；没有当前环就第一个挂着事的环。
    static func focus(_ r: Activity.Ring) -> String? {
        r.current ?? r.segments.first { !$0.items.isEmpty }?.key
    }

    /// 已关的门写成一行：最近两天各一段，更早的只写几天（「09-24 W6（1a2b3c4d） · 09-23 B1、B2 · 更早 3 天」）。
    static func closedLine(_ r: Activity.Ring) -> String? {
        guard !r.closed.isEmpty else { return nil }
        let recent = r.closed.prefix(2).map { g in "\(g.date.suffix(5)) \(g.items.joined(separator: "、"))" }
        let more = r.closed.count > 2 ? [L("更早 \(r.closed.count - 2) 天", "\(r.closed.count - 2) earlier days")] : []
        return (recent + more).joined(separator: " · ")
    }

    /// 环形小图标里一环占多少角度：环数等分，留 gap 度的缝（14 度在 14pt 上几乎连成一圈，09-24 实拍）。
    static func arcs(count n: Int, gap: Double = 20) -> [(start: Double, end: Double)] {
        guard n > 0 else { return [] }
        let step = 360.0 / Double(n)
        return (0..<n).map { i in (-90 + Double(i) * step + gap / 2, -90 + Double(i + 1) * step - gap / 2) }
    }
}

/// 环形小图标：几环几段弧，按状态着色，当前环加粗、看不见的环淡。胶囊、收起态左翼、面板标题行都用它。
struct RingGlyph: View {
    let ring: Activity.Ring
    var size: CGFloat = 14

    var body: some View {
        let arcs = RingLayout.arcs(count: ring.segments.count)
        ZStack {
            ForEach(Array(zip(ring.segments, arcs).enumerated()), id: \.offset) { _, pair in
                let (seg, a) = pair
                let cur = seg.key == ring.current
                RingArc(start: a.start, end: a.end)
                    .stroke(cur ? Ink.primary : RingTone.tint(seg.state),
                            style: StrokeStyle(lineWidth: size * (cur ? 0.19 : 0.12), lineCap: .round))
                    .opacity(seg.sight == .seen || cur ? 1 : 0.7)
            }
        }
        .padding(size * 0.1)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ring.segments.first { $0.key == ring.current }.map { L("当前在「\($0.name)」", "now at \($0.name)") } ?? "")
    }
}

struct RingArc: Shape {
    let start: Double
    let end: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: min(r.width, r.height) / 2,
                 startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        return p
    }
}

/// 标题行：环形小图标、「这一轮 · 稿名」，右边当前环、最近动静、等你 N。
struct RingHeader: View {
    let ring: Activity.Ring
    var glyph: CGFloat = 14

    var body: some View {
        let l = ring.labels
        let cur = ring.segments.first { $0.key == ring.current }?.name
        let latest = ring.segments.first { $0.key == ring.latest }?.name
        HStack(alignment: .center, spacing: 4) {
            RingGlyph(ring: ring, size: glyph)
            Text([l.title, ring.name].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.secondary)
                .lineLimit(1).fixedSize()
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                if let cur { pair(l.current, cur, Ink.primary) }
                if let latest {
                    HStack(spacing: 4) {
                        Circle().fill(Ink.primary).frame(width: 4, height: 4)
                        pair(l.latest, latest + (ring.latestAt.map { " " + Self.clock($0) } ?? ""), Ink.secondary)
                    }
                }
                pair(l.waiting, "\(ring.waiting)", ring.waiting > 0 ? Ink.accent : Ink.tertiary, number: true)
            }
            .fixedSize()
        }
    }

    private func pair(_ k: String, _ v: String, _ tint: Color, number: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(k).font(.system(size: 11)).foregroundStyle(Ink.tertiary)
            Text(v).font(number ? Ink.number(11, .semibold) : .system(size: 11, weight: .semibold)).foregroundStyle(tint)
        }
    }

    static func clock(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(d) ? "HH:mm" : "MM-dd HH:mm"
        return f.string(from: d)
    }
}

enum Nesting {
    /// 嵌在 h 里、带稿件的环的第一件（v1 一场对话只画一份稿件）。
    @MainActor
    static func ring(in h: Hosted, _ xs: [Hosted]) -> (child: Hosted, ring: Activity.Ring)? {
        for c in Ordering.children(of: h, in: xs) { if let r = c.activity.ring { return (c, r) } }
        return nil
    }
}
