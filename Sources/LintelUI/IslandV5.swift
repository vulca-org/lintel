import AppKit
import LintelCore
import SwiftUI

// 第五版的岛（分镜 ⑨⑨–①⓪①，作者 09-24「可以没问题」），照 Apple Live Activities 模板（evidence/refs-2026-09-24-macos/NOTES.md）：
// 收起态两边各一样（Compact）；没嵌进对话的稿件是一颗脱开的小岛（Minimal）；悬停是最矮的展开（Expanded, Minimum Height）；
// 稿件要紧时照航班样例（Expanded - Passenger's View - In Flight）。

/// 右翼写什么：这场对话有等你的事就写「等你 N」（字取来源给的组名），没有就退回来源写的标签。
@MainActor
enum IslandText {
    struct Right: Equatable {
        var text: String
        /// 青色的数；nil = 这是来源写的标签，不带数。
        var count: Int?
        var tone: Swatch?
    }

    /// 等你的事：对话清单里的「等你」，没有清单的稿件看环上挂着的「等你」。
    static func waiting(_ a: Activity) -> (label: String, count: Int)? {
        if let c = a.chain {
            let n = c.items.filter { $0.state == .you }.count
            return n > 0 ? (c.labels.you, n) : nil
        }
        if let r = a.ring, r.waiting > 0 { return (r.labels.waiting, r.waiting) }
        return nil
    }

    static func right(_ h: Hosted, label: Activity.Label?) -> Right? {
        if let w = waiting(h.activity) { return Right(text: w.label, count: w.count, tone: nil) }
        guard let label else { return nil }
        return Right(text: label.text, count: nil, tone: label.tone)
    }

    static var font: NSFont { .systemFont(ofSize: 12, weight: .semibold) }
    static var numberFont: NSFont { .monospacedDigitSystemFont(ofSize: 12, weight: .semibold) }

    /// 右翼字的宽：字、空格、数。
    static func width(_ r: Right) -> CGFloat {
        let t = (r.text as NSString).size(withAttributes: [.font: font]).width
        let n = r.count.map { (" \($0)" as NSString).size(withAttributes: [.font: numberFont]).width } ?? 0
        return ceil(t + n)
    }
}

/// 收起态左边：来源的标志。许愿柳是圆里一个 W，外圈一道弧是上下文还剩多少（分镜 ⑨⑨）；括号形来源画它的括号。
struct IslandMark: View {
    let store: ActivityStore
    let hosted: Hosted
    var size: CGFloat = 20

    var body: some View {
        let st = hosted.activity.status
        let mark = store.registry?.producers[hosted.producer]?.mark
        if mark?.shape == .bracket {
            let center = st?.center ?? .idle
            BracketGlyph(size: size, tint: mark?.tint?.color ?? Ink.secondary, center: center,
                         symbolTint: DuoGlyph.symbol(center, live: 0).tint, bounceAt: st?.bounceAt)
        } else {
            WillowRingGlyph(remaining: st?.ringRemaining, size: size)
                .help(st?.summary ?? "")
        }
    }
}

/// 圆里一个 W，外圈是还剩多少：底圈白 18%，剩下的那段白色从顶上顺时针走（同 DuoGlyph 的外圈弧，剩 20% 变橙、10% 变红）。
struct WillowRingGlyph: View {
    let remaining: Double?
    var size: CGFloat = 20

    var body: some View {
        let line = size * 0.08
        ZStack {
            Circle().stroke(Color.white.opacity(0.18), lineWidth: line)
            if let r = remaining {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, r)))
                    .stroke(Gauge.color(remaining: r), style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            WillowMark(size: size - 2 * line - 2)
        }
        .padding(line / 2)
        .frame(width: size, height: size)
        .accessibilityLabel(remaining.map { "许愿柳，上下文还剩 \(Int($0 * 100))%" } ?? "许愿柳")
    }
}

/// 收起态：左边标志、右边「等你 N」，各靠外侧（分镜 ⑨⑨，Live Activities Compact）。
struct CompactWingsV5: View {
    let store: ActivityStore
    let hosted: Hosted
    let right: IslandText.Right
    let notchWidth: CGFloat
    let height: CGFloat

    static let markSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                DemoMark(compact: true)
                IslandMark(store: store, hosted: hosted, size: Self.markSize)
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity)

            Color.clear.frame(width: notchWidth)

            HStack(spacing: 4) {
                Spacer(minLength: 0)
                Text(right.text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(right.tone?.color ?? Color.white)
                    .lineLimit(1)
                if let n = right.count {
                    Text("\(n)")
                        .font(Ink.number(12, .semibold))
                        .foregroundStyle(Tone.cyan)
                        .contentTransition(.numericText())
                }
            }
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.3), value: right)
        .accessibilityElement(children: .combine)
    }

    /// 一侧翼宽：左边标志与右边的字取较宽的一侧，两侧等宽，重心不偏；内边距 12 加与摄像头之间 8。
    static func wingWidth(_ r: IslandText.Right) -> CGFloat {
        min(StageController.wingMax, max(markSize, IslandText.width(r)) + 12 + 8)
    }
}

// MARK: 脱开的小岛（Minimal）

/// 第二件事：一份稿件画成脱开的小岛（分镜 ⑨⑨，Live Activities :17、:19、:63–:67）。
///
/// 分镜原来的规则是「嵌在对话里的不单独占岛」，前提是那场对话就在主位上、悬停主岛看得到它。作者 09-24 问
/// 「为什么悬停的是 draft-b，不应该是 draft-a？」：主位跟着最近在动的会话走，稿件 A 会话不在主位时 draft-a 在刘海上哪儿都看不到，
/// 小岛却给了一份一周没动的稿件。现在的规则（L9）：
/// - 超过 `idleLimit` 没动（`activityAt`；没写的也算没动）：不占岛，窗口侧栏里照样有；
/// - 稿件自己在主位上：不再单独出岛；
/// - 剩下的取最近动过的那一份，**不管它所在的对话在不在主位**：对话在主位时悬停主岛出的是最矮的两行，看不到稿件
///   （09-24 先定过「所在对话在主位就不出岛」，实拍时 稿件 A 会话正在主位，刘海上就一点写作循环的入口都没有了）。
@MainActor
enum Detached {
    /// 多久没动就不占小岛。
    static let idleLimit: TimeInterval = 3 * 24 * 3600

    static func manuscript(_ xs: [Hosted], primary: Hosted?, now: Date = Date()) -> Hosted? {
        xs.filter { h in
            guard h.activity.open, h.activity.ring != nil, h.id != primary?.id else { return false }
            guard let at = h.activity.activityAt, now.timeIntervalSince(at) <= idleLimit else { return false }
            return true
        }
        .max { ($0.activity.activityAt ?? .distantPast) < ($1.activity.activityAt ?? .distantPast) }
    }

    /// 括号里写什么：要重跑的环数（橙）；没有要重跑的就写等你几件（青）；都没有只画括号。
    static func number(_ r: Activity.Ring) -> (n: Int, tone: Color)? {
        let stale = r.segments.filter { $0.state == .stale }.count
        if stale > 0 { return (stale, Tone.orange) }
        if r.waiting > 0 { return (r.waiting, Tone.cyan) }
        return nil
    }

    /// 小岛和岛一样高，宽比高多 12：一个括号加一个数放得下。
    static func width(notchHeight: CGFloat) -> CGFloat { notchHeight + 12 }
}

/// 小岛的内容：写作循环靛蓝的一对括号夹着一个数（分镜 ⑨⑨ 的 [2]）。括号分成左右两半画，数的宽度变了括号跟着让，不会压字。
struct ManuscriptIsland: View {
    let ring: Activity.Ring
    let name: String

    var body: some View {
        let num = Detached.number(ring)
        HStack(spacing: 2) {
            HalfBracket(left: true).stroke(Tone.indigo, style: Self.stroke).frame(width: 5, height: 16)
            if let num {
                Text("\(num.n)")
                    .font(Ink.number(12, .semibold))
                    .foregroundStyle(num.tone)
                    .fixedSize()
            } else {
                Color.clear.frame(width: 6, height: 1)
            }
            HalfBracket(left: false).stroke(Tone.indigo, style: Self.stroke).frame(width: 5, height: 16)
        }
        .help(name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(num.map { "\(name)，\($0.n)" } ?? name)
    }

    static let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
}

/// 括号的一半：竖笔加上下两道短臂，转角带一点圆。
struct HalfBracket: Shape {
    let left: Bool
    func path(in r: CGRect) -> Path {
        let x0 = left ? r.maxX : r.minX, x1 = left ? r.minX : r.maxX
        var p = Path()
        p.move(to: CGPoint(x: x0, y: r.minY))
        p.addArc(tangent1End: CGPoint(x: x1, y: r.minY), tangent2End: CGPoint(x: x1, y: r.maxY), radius: 1.5)
        p.addArc(tangent1End: CGPoint(x: x1, y: r.maxY), tangent2End: CGPoint(x: x0, y: r.maxY), radius: 1.5)
        p.addLine(to: CGPoint(x: x0, y: r.maxY))
        return p
    }
}
