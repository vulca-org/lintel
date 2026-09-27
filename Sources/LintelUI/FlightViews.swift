import AppKit
import LintelCore
import SwiftUI

// 第五版的展开态（分镜 ①⓪⓪ ①⓪①）与三处共用的航班卡（刘海、弹出框、窗口）。
// 最矮展开照 Live Activities「Expanded (Minimum Height)」：两行加一个圆按钮；
// 稿件照「Expanded - Passenger's View - In Flight」：左上写作循环与稿名、右上状态胶囊、中间航线与当前位置、下面三栏小标签大数值。

/// 航班卡要的数，全部取自来源写好的字段；这里只挑、只数。
struct FlightModel: Equatable {
    struct Stop: Equatable {
        var name: String
        var state: Activity.Ring.State
    }
    /// 来源名（写作循环）。
    var source: String
    /// 稿名。
    var name: String
    /// 状态胶囊：待办里「论文」那一格（「论文未就绪」）；没有就不画。
    var status: String?
    var statusUrgent: Bool
    var stops: [Stop]
    /// 等你的第一环（来源算的「当前」：按顺序第一个挂着未决的环）。只用来说明，不定航线的位置。
    var current: Int?
    /// 航线上的位置：这一轮最远做到的那一环（来源的 reached）；没给就退回最近动静，再退回当前。
    /// 作者 09-24 问「为什么还在设计这个阶段」：当前被一条挂在设计上的旧未决钉住，最近动静又是一条评论，两个都说不出做到哪。
    var position: Int?
    /// 位置下面写的时间：位置就是最近动静那一环时，写它的时刻。
    var positionAt: Date?
    /// 等你裁的事里最久没动的那条的日期（台账「进展」行的日期）：一条陈旧的未决一眼看得出来。
    var youOldest: String?
    /// 等你裁：环上挂着要你裁的事，加上没挂上环节的。
    var you: Int
    /// 要重跑：环上挂着的、不要你裁的事（过期要重跑的检查与读者组）。
    var rerun: Int
    /// 投稿：待办里「投稿构建」那一格的值（「待填 1」）。
    var submit: String?
    /// 投稿那一格来源自己标的是不是要紧（橙、红）。09-27 面板 grill 9：「可上传」来源标的是白，这里却只要有值就涂橙，
    /// 和「要重跑」同时亮成警示色，读起来像出了问题。颜色跟来源走，不按有没有值。
    var submitUrgent = false
    var youLabel = "等你裁", rerunLabel = "要重跑", submitLabel = "投稿"

    @MainActor static func make(_ h: Hosted, registry: Registry?) -> FlightModel? {
        guard let r = h.activity.ring else { return nil }
        let cells = h.activity.detail?.overview?.todo?.cells ?? []
        let paper = cells.first { $0.title == "论文" }
        let build = cells.first { $0.title.hasPrefix("投稿") }
        let hung = r.segments.flatMap(\.items)
        return FlightModel(
            source: sourceRef(registry, h.producer).name,
            name: r.name ?? h.activity.label?.text ?? h.activity.id,
            status: paper.map { $0.title + ($0.value ?? $0.text) },
            statusUrgent: paper?.tone == .orange || paper?.tone == .red,
            stops: r.segments.map { Stop(name: $0.name, state: $0.state) },
            current: r.segments.firstIndex { $0.key == r.current },
            position: [r.reached, r.latest, r.current].lazy.compactMap { k in r.segments.firstIndex { $0.key == k } }.first,
            positionAt: (r.reached ?? r.latest) == r.latest ? r.latestAt : nil,
            youOldest: (hung.filter { $0.you == true } + r.unhung).compactMap(\.moved).min(),
            you: hung.filter { $0.you == true }.count + r.unhung.count,
            rerun: hung.filter { $0.you != true }.count,
            submit: build.map { $0.value ?? $0.text },
            submitUrgent: build?.tone == .orange || build?.tone == .red)
    }

    /// 最近动静的时刻：今天写「18:52」，更早写「09-23」。
    static func when(_ t: Date, now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDate(t, inSameDayAs: now) ? "HH:mm" : "MM-dd"
        return f.string(from: t)
    }

    /// 航线下写哪几处名字：起点、位置、终点；挨得太近（位置是第 0、1 站或最后一站）就只留位置与终点。
    func namedStops() -> [Int] {
        guard !stops.isEmpty else { return [] }
        let last = stops.count - 1
        guard let c = position else { return [0, last] }
        var out = [c]
        if c >= 2 { out.insert(0, at: 0) }
        if c < last { out.append(last) }
        return out
    }
}

/// 航班卡。刘海里是黑底白字（style .notch）；弹出框与窗口里跟随系统深浅，画在 `Surface.card` 上（style .panel）。
struct FlightCard: View {
    enum Style { case notch, panel }
    let model: FlightModel
    var style: Style = .notch

    private var ink: Color { style == .notch ? .white : Tone.primary }
    private var quiet: Color { style == .notch ? Ink.tertiary : Tone.secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.source)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Tone.indigo)
                    Text(model.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let s = model.status {
                    Text(s)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(model.statusUrgent ? (style == .notch ? Color.black : Color.white) : ink)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(model.statusUrgent ? Tone.orange : quiet.opacity(0.18)))
                }
            }
            RouteView(model: model, ink: ink, quiet: quiet)
            if style == .panel { RouteLegend(model: model, ink: ink, quiet: quiet) }
            HStack(alignment: .top, spacing: 12) {
                column(model.youLabel, "\(model.you)", model.you > 0 ? Tone.cyan : quiet,
                       sub: model.youOldest.map { "最久 \($0) 起没动" })
                column(model.rerunLabel, "\(model.rerun)", model.rerun > 0 ? Tone.orange : quiet)
                column(model.submitLabel, model.submit ?? "—", model.submit == nil ? quiet : (model.submitUrgent ? Tone.orange : ink))
            }
        }
        .padding(style == .panel ? 16 : 0)
        .background {
            if style == .panel { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Surface.card) }
        }
    }

    private func column(_ k: String, _ v: String, _ tint: Color, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.system(size: 11, weight: .semibold)).foregroundStyle(quiet)
            Text(v).font(Ink.number(20, .semibold)).foregroundStyle(tint).lineLimit(1)
            if let sub { Text(sub).font(.system(size: 11)).monospacedDigit().foregroundStyle(quiet).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 航线：一环一站。做完的实心点；位置（最近动静那一环）是一个方框，里面写作循环靛蓝；等你的青色空心、过期的橙色空心、
/// 还没到的灰色空心、看不见的虚线圈。到位置为止是实线，之后是虚线。站下只写起点、位置（带时间）、终点。
/// 位置不是「当前」：等你的环不论在前在后都画青圈，一眼看得出做到哪、哪几环还欠一个决定。
struct RouteView: View {
    let model: FlightModel
    let ink: Color
    let quiet: Color

    static let stop: CGFloat = 16
    static let labelHeight: CGFloat = 16

    var body: some View {
        GeometryReader { g in
            let n = model.stops.count
            let step = n > 1 ? (g.size.width - Self.stop) / CGFloat(n - 1) : 0
            let x = { (i: Int) in Self.stop / 2 + CGFloat(i) * step }
            let y = Self.stop / 2
            let cur = model.position ?? -1
            ZStack(alignment: .topLeading) {
                if n > 1 {
                    Path { p in p.move(to: CGPoint(x: x(0), y: y)); p.addLine(to: CGPoint(x: x(max(0, cur)), y: y)) }
                        .stroke(ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    Path { p in p.move(to: CGPoint(x: x(max(0, cur)), y: y)); p.addLine(to: CGPoint(x: x(n - 1), y: y)) }
                        .stroke(quiet, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                ForEach(Array(model.stops.enumerated()), id: \.offset) { i, s in
                    RouteNode(state: s.state, current: i == cur, ink: ink, quiet: quiet)
                        .frame(width: Self.stop, height: Self.stop)
                        .contentShape(Rectangle())
                        .help(s.name + " · " + RouteNode.word(s.state, current: i == cur))
                        .position(x: x(i), y: y)
                }
                ForEach(model.namedStops(), id: \.self) { i in
                    let isCur = i == cur
                    Text(label(i, isCur))
                        .font(.system(size: isCur ? 12 : 11, weight: isCur ? .semibold : .medium))
                        .foregroundStyle(isCur ? ink : quiet)
                        .lineLimit(1)
                        .fixedSize()
                        .position(x: labelX(x(i), label(i, isCur), g.size.width), y: Self.stop + 4 + Self.labelHeight / 2)
                }
            }
        }
        .frame(height: Self.stop + 4 + Self.labelHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.stops.enumerated().map { i, s in (i == model.position ? "做到 " : "") + s.name }.joined(separator: "，"))
    }

    /// 站名；位置那一站后面加最近动静的时刻（今天写时分，更早写月日）。
    private func label(_ i: Int, _ isPosition: Bool) -> String {
        guard isPosition, let t = model.positionAt else { return model.stops[i].name }
        return model.stops[i].name + " · " + FlightModel.when(t)
    }

    /// 两端的名字贴着边，不越出卡片。
    private func labelX(_ cx: CGFloat, _ text: String, _ w: CGFloat) -> CGFloat {
        let half = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]).width / 2
        return min(max(cx, half), w - half)
    }
}

/// 航线上的一个节点。航线和图例共用（09-27 面板 grill 13：七个节点只有三个有字，实心、空心、虚线各是什么没处查）。
struct RouteNode: View {
    let state: Activity.Ring.State
    let current: Bool
    let ink: Color
    let quiet: Color

    /// 状态词，和写作循环写在格子里的那一小句一致。
    static func word(_ s: Activity.Ring.State, current: Bool) -> String {
        if current { return L("做到这里", "reached") }
        switch s {
        case .done: return L("做过", "done")
        case .waiting: return L("等你裁", "your call")
        case .stale: return L("过期", "stale")
        case .open: return L("还没到", "not yet")
        case .unseen: return L("看不见", "not visible")
        }
    }

    var body: some View {
        if current {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.black.opacity(0.001))
                RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(ink, lineWidth: 2)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous).fill(Tone.indigo).frame(width: 6, height: 6)
            }
        } else {
            switch state {
            case .done: Circle().fill(ink).frame(width: 7, height: 7)
            case .waiting: Circle().stroke(Tone.cyan, lineWidth: 1.5).frame(width: 8, height: 8)
            case .stale: Circle().stroke(Tone.orange, lineWidth: 1.5).frame(width: 8, height: 8)
            case .open: Circle().stroke(quiet, lineWidth: 1.5).frame(width: 8, height: 8)
            case .unseen: Circle().stroke(quiet, style: StrokeStyle(lineWidth: 1, dash: [1.5, 1.5])).frame(width: 8, height: 8)
            }
        }
    }
}

/// 航线下面一行图例：只列这条航线上真出现的记号，次序照航线读的次序。刘海里不画（地方不够，悬停时看弹出框）。
struct RouteLegend: View {
    let model: FlightModel
    let ink: Color
    let quiet: Color

    static func keys(_ m: FlightModel) -> [(state: Activity.Ring.State, current: Bool)] {
        var out: [(Activity.Ring.State, Bool)] = []
        if m.position != nil, m.stops.indices.contains(m.position!) { out.append((m.stops[m.position!].state, true)) }
        for s in [Activity.Ring.State.done, .waiting, .stale, .open, .unseen]
        where m.stops.enumerated().contains(where: { $0.element.state == s && $0.offset != m.position }) {
            out.append((s, false))
        }
        return out
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(Self.keys(model).enumerated()), id: \.offset) { _, k in
                HStack(spacing: 4) {
                    RouteNode(state: k.state, current: k.current, ink: ink, quiet: quiet).frame(width: 16, height: 16)
                    Text(RouteNode.word(k.state, current: k.current)).font(.system(size: 11)).foregroundStyle(quiet).fixedSize()
                }
            }
        }
    }
}

// MARK: 刘海里的展开态

/// 最矮展开的两行：第一行「等你 N」（青），第二行第一件等你的事。没有等你的退到在做，再退到来源写的标签。
@MainActor
enum MinimumLines {
    static func lines(_ h: Hosted) -> (head: String, headTone: Color, body: String)? {
        let a = h.activity
        if let c = a.chain {
            let you = c.items.filter { $0.state == .you }
            if let first = you.first { return ("\(c.labels.you) \(you.count)", Tone.cyan, first.text) }
            let doing = c.items.filter { $0.state == .doing }
            if let first = doing.first { return ("\(c.labels.doing) \(doing.count)", Ink.secondary, first.text) }
        }
        guard let head = a.label?.text ?? a.flip?.title else { return nil }
        return (head, Ink.secondary, a.status?.summary ?? a.flip?.subtitle ?? "")
    }
}

/// 理解刚到、刘海自己弹出的那几秒：画来源写好的弹出几行（许愿柳：你说的 / Claude 读成的）。
/// 09-27 作者选 A：第五版去掉了精简版，这张对照卡跟着没了，而它正是许愿柳存在的理由。鼠标停上去就换回最矮两行。
@MainActor
enum ArrivalLines {
    static func lines(_ h: Hosted, compact: Bool) -> [Activity.PopupLine]? {
        guard compact, h.activity.ring == nil, !h.activity.popup.isEmpty else { return nil }
        return Array(h.activity.popup.prefix(4))
    }

    static func tint(_ t: Activity.PopupLine.Tone) -> Color {
        switch t {
        case .primary: Color.white
        case .secondary, .quiet: Ink.secondary
        case .warning: Swatch.orange.color
        case .accent: Tone.cyan
        }
    }
}

/// 刘海展开态的内容：刘海那一行（左标志、右边对话名），下面是两行加圆按钮，或者航班卡。
struct ExpandedV5: View {
    let store: ActivityStore
    let seen: SeenStore
    let pinned: String?
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    /// 理解到达的那几秒（StageState.compact）：画弹出几行，不画最矮两行。
    var compact: Bool = false
    var onOpen: () -> Void = {}

    static let width: CGFloat = 460
    static let inset: CGFloat = 16

    var body: some View {
        let xs = store.activities
        let h = pinned.flatMap { id in xs.first { $0.id == id } } ?? Ordering.pair(xs, seen, pinned: pinned).primary
        VStack(alignment: .leading, spacing: 0) {
            if let h {
                ears(h, xs)
                if let m = FlightModel.make(h, registry: store.registry) {
                    FlightCard(model: m, style: .notch)
                        .padding(.horizontal, Self.inset).padding(.top, 8).padding(.bottom, 20)
                } else {
                    minimum(h)
                }
            }
        }
        .frame(width: Self.width, alignment: .topLeading)
    }

    /// 刘海那一行：左边来源标志（与收起态同一个位置，展开时不跳），右边是这件事所在的对话名（稿件嵌在对话里时）。
    private func ears(_ h: Hosted, _ xs: [Hosted]) -> some View {
        let parent = Ordering.parent(of: h, in: xs)
        let owner = parent ?? h
        return HStack(spacing: 0) {
            IslandMark(store: store, hosted: owner, size: CompactWingsV5.markSize)
            Spacer(minLength: notchWidth)
            if h.activity.ring != nil, let p = parent {
                Text(p.activity.name ?? p.activity.flip?.title ?? p.activity.label?.text ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Self.inset)
        .frame(height: notchHeight)
    }

    @ViewBuilder private func minimum(_ h: Hosted) -> some View {
        if let rows = ArrivalLines.lines(h, compact: compact) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Ink.secondary)
                        Text(r.text)
                            .font(.system(size: 13, weight: r.tone == .primary ? .semibold : .regular))
                            .foregroundStyle(ArrivalLines.tint(r.tone))
                            .lineLimit(max(1, r.lines))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.inset).padding(.top, 8).padding(.bottom, 20)
        } else if let l = MinimumLines.lines(h) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.head)
                        .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(l.headTone)
                    Text(l.body)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onOpen) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.16)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("打开这场对话", "Open this conversation"))
            }
            .padding(.horizontal, Self.inset).padding(.top, 8).padding(.bottom, 20)
        }
    }
}
