import SwiftUI
import LintelCore

/// 对话的长清单（Activity.chain）怎么排（åé¨ spec 2026-09-24 对话层 V1–V6，分镜 ⑦④ ⑦⑦ ⑦⑨）。
/// 字都是来源写好的；这里只决定次序、取哪几项、画成什么形状。状态只靠形状分，不用绿色（V6）。
enum ChainLayout {
    typealias State = Activity.Chain.State
    typealias Item = Activity.Chain.Item

    /// 读起来像一条进度的次序。
    static let progressOrder: [State] = [.done, .doing, .you, .other, .later]
    /// 点开时的分组次序：要紧的在上，做完的当历史放最后。
    static let groupOrder: [State] = [.doing, .you, .other, .later, .done]
    /// 6 格 5pt、间距 1.5：满格加状态符号、再加两个来源时的来源字母，一共 89.5pt，放得进没有清单时的翼宽 92，
    /// 两翼不因方块变宽（作者 09-24：12 格把两翼撑到 117，静止时刘海挡住菜单栏右侧的图标；
    /// 8 格加字母又把右翼的 6 字标签挤成了「减刘海补…」）。
    static let maxSquares = 6
    static let squareSize: CGFloat = 5
    static let squareGap: CGFloat = 1.5

    /// 收起态左翼的方块：最多 6 格，先留开着的，做完的只补剩下的格。
    /// 对话里嵌着稿件时（左翼后面还有环形小图标）只放 3 格：3 格加小图标加来源字母 89pt，4 格就是 95.5，超过翼宽 92。
    static let maxSquaresNested = 3

    static func squares(_ c: Activity.Chain, max cap: Int = maxSquares) -> [State] {
        let open = c.items.filter { $0.state != .done }
            .sorted { rank($0.state) < rank($1.state) }
            .prefix(cap).map(\.state)
        let room = cap - open.count
        let done = Array(repeating: State.done, count: min(room, c.items.filter { $0.state == .done }.count))
        return done + open
    }

    /// 悬停「此刻」：在做的（最多 2 项）加等你的前几项，一共最多 3 行，有等你的至少带一项。展开卡是统一高（作者 09-21），
    /// 09-24 实拍 2 + 3 行时「Claude 在做」的时间轴被挤到卡底翻页行下面，2 + 2 行时图例还被盖住半行；条数在标题行，整张在面板里。
    static let nowRows = 3
    static func now(_ c: Activity.Chain) -> [Item] {
        let doing = Array(c.items.filter { $0.state == .doing }.prefix(2))
        return doing + Array(c.items.filter { $0.state == .you }.prefix(min(3, nowRows - doing.count)))
    }

    /// 到了日子的项（10-06 spec「刘海上露出到了日子的项」）：来源写了 due 的、没做完的，日子越早越先，一样早按清单顺序。
    /// 「到日子」只看来源有没有写 due，14 天这条规则在来源（D1）。
    static func due(_ c: Activity.Chain) -> [Item] {
        c.items.enumerated()
            .compactMap { i, x in x.state == .done ? nil : x.due.map { (i, $0.days, x) } }
            .sorted { ($0.1, $0.0) < ($1.1, $1.0) }
            .map(\.2)
    }

    static func dueLabel(_ n: Int) -> String { L("到日子 \(n)", "due \(n)") }

    static func groups(_ c: Activity.Chain) -> [(State, [Item])] {
        groupOrder.compactMap { s in
            let xs = c.items.filter { $0.state == s }
            return xs.isEmpty ? nil : (s, xs)
        }
    }

    static func counts(_ c: Activity.Chain) -> [(State, Int)] {
        progressOrder.map { s in (s, c.items.filter { $0.state == s }.count) }
    }

    static func label(_ s: State, _ l: Activity.Chain.Labels) -> String {
        switch s {
        case .done: l.done
        case .doing: l.doing
        case .you: l.you
        case .other: l.other
        case .later: l.later
        }
    }

    /// 收起态左翼要的宽：两侧内边距 12 + 状态符号 18 + 间距 4 + 方块；有来源字母时再加 14 + 间距 4。没有方块就不另要宽。
    static func wingWidth(squares n: Int, initial: Bool) -> CGFloat {
        guard n > 0 else { return 0 }
        return 12 + (initial ? 14 + 4 : 0) + 18 + 4 + CGFloat(n) * squareSize + CGFloat(n - 1) * squareGap
    }

    private static func rank(_ s: State) -> Int { progressOrder.firstIndex(of: s) ?? 0 }
}

/// 清单和稿件的环共用的一套记号（作者 09-24 要求：颜色与界面统一设计、前后一致、好看，并完全符合 Apple 的设计）。
/// 形状管状态：做完实心、在做半满、等你空心、等别的虚线、以后暗格——颜色只是加一层，不单靠颜色（HIG Color / Accessibility）。
/// 有色的只有两种，各只表示一件事：青 = 轮到你（许愿柳「等你选择」），橙 = 读偏或过期；红留给坏了；其余灰阶。
/// 在做不再用紫（09-24 grill）：紫与写作循环的身份靛青挨在一起、意思却不同，HIG Color 说同一种颜色别表示两件事；
/// 半满的形状已经说了「在做」。不用绿色（V6）。
enum ChainTone {
    typealias State = Activity.Chain.State

    static func tint(_ s: State) -> Color {
        switch s {
        case .done: Ink.secondary
        case .doing: Ink.primary
        case .you: Ink.accent
        case .other: Ink.secondary
        case .later: Ink.tertiary
        }
    }

    /// 事项文字：开着的亮，等别的和以后退一档，做完的当历史再退一档。
    static func text(_ s: State) -> Color {
        switch s {
        case .doing, .you: Ink.primary
        case .other, .later: Ink.secondary
        case .done: Ink.tertiary
        }
    }
}

/// 一格状态：做完实心，在做半满，等你空心，等别的虚线框，以后暗格。
struct ChainSquare: View {
    let state: Activity.Chain.State
    var size: CGFloat = ChainLayout.squareSize

    var body: some View {
        let r = RoundedRectangle(cornerRadius: max(1, size / 5), style: .continuous)
        let tint = ChainTone.tint(state)
        let line: CGFloat = size >= 7 ? 1.2 : 1
        ZStack {
            switch state {
            case .done:
                r.fill(tint)
            case .doing:
                r.fill(tint.opacity(0.18))
                r.fill(tint).mask(HStack(spacing: 0) { Color.black; Color.clear })
                r.strokeBorder(tint, lineWidth: line)
            case .you:
                r.fill(tint.opacity(0.16))
                r.strokeBorder(tint, lineWidth: line)
            case .other:
                r.strokeBorder(tint, style: StrokeStyle(lineWidth: line, dash: [max(1, size / 4), max(1, size / 5)]))
            case .later:
                r.fill(Ink.quaternary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 一项的旁注：你认可过、几轮没动、证据。预测不写字（作者 09-24：面板里不要「模型说的」，没必要）——
/// 有证据的写证据，没写的就是还没有证据，两种一眼分得开（A2）。
struct ChainMeta: View {
    let item: Activity.Chain.Item

    static func has(_ x: Activity.Chain.Item) -> Bool {
        x.due != nil || x.approved == true || x.idle != nil || !(x.note ?? "").isEmpty || !(x.wait ?? "").isEmpty || !(x.blocks ?? []).isEmpty
    }

    /// 到日子那几个字：已过用警示色（橙 = 过期，同 ChainTone 的约定）；今天、还有几天只是提示，灰字。
    static func dueTint(_ days: Int) -> Color { days < 0 ? Tone.orange : Tone.secondary }

    // 画在弹出框与窗口的浅底上：用 Tone（Ink 是给黑底刘海的白字，放在白卡片上看不见——09-27 第二轮修 N1 时实拍，旁注那一行留了高度却一个字都没有）。
    static func idleTint(_ state: Activity.Chain.State) -> Color {
        state == .doing ? Tone.orange : Tone.secondary
    }

    var body: some View {
        HStack(spacing: 8) {
            if let d = item.due {
                // 到了日子：放最前，字是来源写的（「已过 18 天」「今天」「还有 9 天」）。
                Text(d.text).foregroundStyle(ChainMeta.dueTint(d.days)).fixedSize()
            }
            if let w = item.wait, !w.isEmpty {
                // 「等别的」在等什么：放在最前，这一行的状态就靠它说清（第二轮 N2）。
                Text(L("等 \(w)", "waiting on \(w)")).foregroundStyle(Tone.secondary).lineLimit(1)
            }
            if let b = item.blocks, !b.isEmpty {
                // 挡着什么：排第一件时看它（09-28 spec D1）。
                Text(L("挡着 \(b.joined(separator: "、"))", "blocks \(b.joined(separator: ", "))"))
                    .foregroundStyle(Tone.secondary).lineLimit(1)
            }
            if item.approved == true {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                    Text(L("你认可过", "you approved"))
                }
                .foregroundStyle(Tone.secondary)
                .fixedSize()
            }
            if let n = item.idle {
                // 在做的卡住了是警示，用橙；等你没动只是你一直没回，灰字就够——09-24 面板上 11 行等你全标成橙色，等于没有警示。
                Text(L("\(n) 轮没动", "idle \(n) turns"))
                    .foregroundStyle(ChainMeta.idleTint(item.state))
                    .fixedSize()
            }
            if let n = item.note, !n.isEmpty {
                // 来源写明是什么（「依据 …」「证据 …」「本轮 N 次操作」），这里不猜。截在末尾、悬停看全文：
                // 09-28 第三轮实拍从中间截成「gh repo view yha98…x_datasheet.tex:31」，头尾各剩半截。
                Text(n)
                    .foregroundStyle(Tone.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(n)
            }
        }
        .font(.system(size: 10, weight: .medium))   // Footnote 10（macOS 文字样式）
    }
}

/// 清单的一行（窗口清单页、弹出框共用；09-27 grill 第二轮 N1–N4）：
/// 主行「编号 标题」——聊天和刘海上那一行清单都用编号指一项；第二行是现在要做什么；第三行是旁注（等什么、几轮没动、你认可过、依据）。
/// 旁注在 753715f 删旧面板后一直没人画，README 写的「证据和预测分开」「等你太久没动会写出来」面板上看不到。
/// 清单行上的动作写回来源收件（09-28 spec「清单实时」C）：走已有的面板动作通道，lintel 不解析 id。
@MainActor
enum ChainActions {
    static func send(_ h: Hosted, _ a: Activity.Chain.Item.Action, store: ActivityStore) {
        Drop.act(producer: h.producer, activity: h.activity.id, action: a.id, paths: store.paths)
    }
}

struct ChainItemRow: View {
    let item: Activity.Chain.Item
    let tint: Color
    var symbol: String? = nil
    /// 作者点了一个动作（09-28 spec「清单实时」C）：调用方把它写进来源收件。nil = 这里不让点（只看）。
    var onAction: ((Activity.Chain.Item.Action) -> Void)? = nil
    /// 点过、来源还没写回新状态：先画成已送出，免得以为没点上。项一变就清掉。
    @State private var sent: String?

    private var actions: [Activity.Chain.Item.Action] { onAction == nil ? [] : (item.actions ?? []) }

    private func fire(_ a: Activity.Chain.Item.Action) {
        sent = a.title
        onAction?(a)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let first = actions.first, sent == nil {
                Button { fire(first) } label: {
                    Image(systemName: symbol ?? ItemStyle.symbol(item.state)).font(.system(size: 12, weight: .medium)).foregroundStyle(tint)
                        .frame(width: 20, height: 20).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(first.title)
                .accessibilityLabel("\(first.title) \(item.id)")
            } else {
                Image(systemName: sent == nil ? (symbol ?? ItemStyle.symbol(item.state)) : "arrow.up.circle")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(sent == nil ? tint : Tone.secondary).frame(width: 16)
                    .help(sent.map { L("已送出：\($0)", "Sent: \($0)") } ?? "")
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(item.id).font(Ink.number(12, .semibold)).foregroundStyle(Tone.secondary).fixedSize()
                    Text(item.title).font(.system(size: 13)).foregroundStyle(Tone.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let c = item.current, !c.isEmpty, c != item.title {
                    Text(c).font(.system(size: 12)).foregroundStyle(Tone.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ChainMeta.has(item) { ChainMeta(item: item) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            ForEach(actions, id: \.self) { a in Button(a.title) { fire(a) } }
        }
        .onChange(of: item) { sent = nil }
    }
}

