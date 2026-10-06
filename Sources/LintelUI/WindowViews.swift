import AppKit
import LintelCore
import SwiftUI

// 第五版拖出来的窗口（分镜 ①⓪③ ①⓪④）：左边侧栏列所有对话与稿件，右边是选中那一项。
// 侧栏照 macOS 27 UI Kit：着色的线条图标、右边灰色数字、展开三角缩进两层（对话 → 嵌着的稿件；Sidebars :5 :6 :8 :10）。
// 分段放在顶上那一行（Segmented controls :19），名词（:15）。跟随系统深浅。

// MARK: 弹出框与窗口共用的行

/// 一组：组名与条数用组的颜色（提醒事项的分组写法），几行放在一块分组底上，放不下的写「还有 N 件」。
struct ItemGroup: View {
    let name: String
    let count: Int
    let tint: Color
    let rows: [AnyView]
    var more: Int = 0
    var onMore: (() -> Void)? = nil
    /// 点开的折叠组收回去；nil = 这组本来就不折。
    var onFold: (() -> Void)? = nil
    /// 折着的组：折起时到了日子的项照样列出来（10-06 刘海 spec D6），组名一行仍是朝右的箭头。
    var folded: Bool = false
    /// 组名后面的一句（折起的组写「到日子 1」），用 noteTint。
    var note: String? = nil
    var noteTint: Color = Tone.secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if rows.isEmpty || folded, let onMore {
                // 折起的组（以后、做完）：组名、条数、一个朝右的小箭头，点开才列（写着条数，不算悄悄藏起来）。
                Button(action: onMore) {
                    HStack(spacing: 4) {
                        Text(name).font(.system(size: 12, weight: .semibold))
                        Text("\(count)").font(Ink.number(12, .regular))
                        if let note { Text("· \(note)").font(.system(size: 12, weight: .semibold)).foregroundStyle(noteTint) }
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            } else if let onFold {
                // 点开的折叠组：同一行换成朝下的箭头，再点收回去（09-28 交互测试第 3 条：点开以后收不回）。
                Button(action: onFold) {
                    HStack(spacing: 4) {
                        Text(name).font(.system(size: 12, weight: .semibold))
                        Text("\(count)").font(Ink.number(12, .regular))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            } else {
                HStack(spacing: 4) {
                    Text(name).font(.system(size: 12, weight: .semibold))
                    Text("\(count)").font(Ink.number(12, .regular))
                }
                .foregroundStyle(tint)
                .padding(.leading, 4)
            }
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { i in
                        if i > 0 { Divider().padding(.leading, 36) }
                        rows[i]
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Surface.group))
            }
            if more > 0, !rows.isEmpty {
                Button { onMore?() } label: {
                    Text("还有 \(more) 件").font(.system(size: 12)).foregroundStyle(Tone.secondary)
                }
                .buttonStyle(.plain)
                .disabled(onMore == nil)
                .padding(.leading, 4)
            }
        }
    }
}

/// 一行事项：状态符号（形状分状态，颜色只加一层）、可选的编号、字写全。
struct ItemRow: View {
    let symbol: String
    let tint: Color
    var tag: String? = nil
    let text: String
    /// 最近一次进展的日期（环上的事才有）：靠右灰字，看得出挂了多久。
    var moved: String? = nil
    /// 悬停时出现的原句（清单项状态变过以后，主行是现在要做的事）。
    var help: String? = nil
    /// 第二行（环上的条目：要做什么、由哪个门决定）。
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(tint).frame(width: 16)
            if let tag { Text(tag).font(Ink.number(12, .semibold)).foregroundStyle(Tone.secondary) }
            VStack(alignment: .leading, spacing: 4) {
                Text(text).font(.system(size: 13)).foregroundStyle(Tone.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail, !detail.isEmpty {
                    Text(detail).font(.system(size: 12)).foregroundStyle(Tone.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let moved { Text(moved).font(Ink.number(12, .regular)).foregroundStyle(Tone.secondary).fixedSize() }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .help(help ?? "")
    }
}

/// 清单一组用什么符号、什么颜色（同 ChainSquare 的形状：做完实心、在做半满、等你空心、等别的虚线、以后暗格）。
enum ItemStyle {
    static func symbol(_ s: Activity.Chain.State) -> String {
        switch s {
        case .done: "checkmark.square.fill"
        case .doing: "square.lefthalf.filled"
        case .you: "square"
        case .other: "square.dashed"
        case .later: "square.dotted"
        }
    }
    static func tint(_ s: Activity.Chain.State) -> Color { s == .you ? Tone.cyan : Tone.secondary }
}

// MARK: 窗口

@MainActor
final class LintelWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: ActivityStore
    private let model = WindowSelection()

    init(store: ActivityStore) { self.store = store }

    /// 造好（或取回）窗口并选中这一项；弹出框拖出来时系统要的就是它，所以这里不负责显示。
    func prepare(select id: String) -> NSWindow {
        model.selected = id
        if let w = window { return w }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 620, height: 400)
        w.contentView = NSHostingView(rootView: LintelWindowView(store: store, model: model))
        w.delegate = self
        if let forced = PresentDemo.appearance { w.appearance = NSAppearance(named: forced) }
        w.center()
        w.setFrameAutosaveName("lintel.window")   // 存过位置就用存的，没存过就是居中
        window = w
        return w
    }

    /// 弹出框要拖出来时系统来要窗口。按下鼠标还没拖就会来要（09-28 交互测试第 10 条），
    /// 所以窗口已经开着时不在这里改它的选中项，等真拖出来（`didDetach`）再改。
    func detachable(select id: String) -> NSWindow {
        if let w = window, w.isVisible { return w }
        return prepare(select: id)
    }

    /// 真拖出来了：选中弹出框现在那场；系统按弹出框的位置摆窗口，窗口是存下的尺寸（实测 872 高落在 y=397，下半截出屏），挪回屏内。
    func didDetach(select id: String) {
        model.selected = id
        guard let w = window else { return }
        fit(w)
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak w] in if let w { self?.fit(w) } }
    }

    var isVisible: Bool { window?.isVisible ?? false }

    /// 窗口开着时从弹出框自己拖出来（ConversationPopover.nativeDetach）：选中这一项，窗口顶边到鼠标下、提到最前。
    func grab(select id: String, at p: NSPoint) {
        model.selected = id
        guard let w = window else { return }
        w.setFrame(Self.grabbed(w.frame, at: p), display: true)
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    func follow(_ p: NSPoint) {
        guard let w = window else { return }
        w.setFrameOrigin(Self.grabbed(w.frame, at: p).origin)
    }

    /// 松手：挪进可见区。
    func release() {
        if let w = window { fit(w) }
    }

    /// 鼠标落在窗口顶上居中、顶边往下 14 点处（标题栏那一条）；尺寸不变。屏幕坐标，原点在左下。
    static func grabbed(_ f: NSRect, at p: NSPoint) -> NSRect {
        NSRect(x: p.x - f.width / 2, y: p.y + 14 - f.height, width: f.width, height: f.height)
    }

    private func fit(_ w: NSWindow) {
        guard let vis = (w.screen ?? NSScreen.main)?.visibleFrame else { return }
        let f = Self.fitted(w.frame, in: vis, min: w.minSize)
        if f != w.frame { w.setFrame(f, display: true, animate: false) }
    }

    /// 窗口框挪进可见区：高宽不超过可见区（不小于最小尺寸），再平移到里面。
    static func fitted(_ f: NSRect, in vis: NSRect, min: NSSize = .zero) -> NSRect {
        var r = f
        r.size.width = Swift.max(Swift.min(r.width, vis.width), Swift.min(min.width, vis.width))
        r.size.height = Swift.max(Swift.min(r.height, vis.height), Swift.min(min.height, vis.height))
        // 高度变小时保住顶边（窗口顶是用户拖着的那一头）。
        if r.height < f.height { r.origin.y = f.maxY - r.height }
        r.origin.x = Swift.min(Swift.max(r.minX, vis.minX), vis.maxX - r.width)
        r.origin.y = Swift.min(Swift.max(r.minY, vis.minY), vis.maxY - r.height)
        return r
    }

    func show(select id: String) {
        let w = prepare(select: id)
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    func select(tab: WindowTab) { model.tab = tab }

    func windowWillClose(_ notification: Notification) {}
}

@MainActor
@Observable
final class WindowSelection {
    var selected: String?
    var tab: WindowTab = .list
    /// 侧栏顺序钉住（作者 09-28 交互测试第 13 条）：按最近动静排，两场在跑的对话来回换位，点下去那一刻行已经换了。
    @ObservationIgnored let conversationOrder = StableOrder()
    @ObservationIgnored let draftOrder = StableOrder()
}

/// 第一次见到时按给的顺序（最近动静）排定，之后已见过的位置不再变；新出现的插到最上面（新的之间仍按给的顺序），没了的自然不列。
final class StableOrder {
    private var rank: [String: Int] = [:]
    private var top = 0

    func arrange(_ ids: [String]) -> [String] {
        if rank.isEmpty {
            for (i, id) in ids.enumerated() { rank[id] = i }
        } else {
            for id in ids.reversed() where rank[id] == nil { top -= 1; rank[id] = top }
        }
        return ids.sorted { rank[$0]! < rank[$1]! }
    }
}

enum WindowTab: String, CaseIterable, Identifiable {
    case list, draft, turns
    var id: String { rawValue }
    var name: String { switch self { case .list: L("清单", "List"); case .draft: L("稿件", "Manuscript"); case .turns: L("轮次", "Turns") } }
}

/// 侧栏里的一行：对话（可带嵌着的稿件）或没嵌进对话的稿件。
struct SidebarNode: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int
    let draft: Bool
    var children: [SidebarNode]?
}

@MainActor
enum SidebarModel {
    static func conversations(_ xs: [Hosted], order: StableOrder? = nil) -> [SidebarNode] {
        var hs = PopoverScope.conversations(xs)
        if let order { let by = Dictionary(hs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }); hs = order.arrange(hs.map(\.id)).compactMap { by[$0] } }
        return hs.map { h in
            // 嵌着的稿件全列（`drafts` 不收嵌着的，这里只列一份另一份就两组都不在：10-04 一份稿件从侧栏消失）；按 id 排，稿件动了不改骨架。
            // 所属按 `listedParent`：对话打盹、稿件过期都不改侧栏里的位置（10-04 一场对话空闲后两份跳回稿件组）。
            let kids = xs.filter { $0.activity.open && $0.activity.ring != nil && Ordering.listedParent(of: $0, in: xs)?.id == h.id }
                .sorted { $0.id < $1.id }.map { node($0, draft: true) }
            return SidebarNode(id: h.id, title: PopoverScope.title(h), count: IslandText.waiting(h.activity)?.count ?? 0, draft: false,
                               children: kids.isEmpty ? nil : kids)
        }
    }

    static func drafts(_ xs: [Hosted], order: StableOrder? = nil) -> [SidebarNode] {
        var hs = xs.filter { $0.activity.open && $0.activity.ring != nil && Ordering.listedParent(of: $0, in: xs) == nil }
            .sorted { ($0.activity.activityAt ?? .distantPast) > ($1.activity.activityAt ?? .distantPast) }
        if let order { let by = Dictionary(hs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }); hs = order.arrange(hs.map(\.id)).compactMap { by[$0] } }
        return hs.map { node($0, draft: true) }
    }

    /// 侧栏的骨架：哪几场对话按什么顺序、各自嵌着哪份稿件、哪些稿件单列。骨架一变，侧栏整个重建（见 `.id`）。
    /// 选中的稿件从一场对话挪到另一场下面时，列表逐项更新会在旧位置留下它的残影（09-25 实拍：对话那一行叠着稿件的图标和字，
    /// 两行同时是选中色，之后一直不消）。标题、数字变了骨架不变，照旧逐项更新。
    static func shape(_ xs: [Hosted], convOrder: StableOrder? = nil, draftOrder: StableOrder? = nil) -> String {
        let convs = conversations(xs, order: convOrder).map { n in ([n.id] + (n.children ?? []).map(\.id)).joined(separator: ">") }
        return (convs + ["|"] + drafts(xs, order: draftOrder).map(\.id)).joined(separator: "\n")
    }

    static func node(_ h: Hosted, draft: Bool) -> SidebarNode {
        SidebarNode(id: h.id, title: h.activity.ring?.name ?? h.activity.name ?? h.activity.label?.text ?? h.id, count: IslandText.waiting(h.activity)?.count ?? 0,
                    draft: draft, children: nil)
    }
}

struct LintelWindowView: View {
    let store: ActivityStore
    @Bindable var model: WindowSelection
    @State private var collapsed: Set<String> = []
    /// 侧栏重建（骨架变了）后列表会丢掉键盘焦点，选中那行从强调色变成灰色。重建后把焦点还给侧栏：这个窗口里能拿键盘焦点的
    /// 只有它（右边是只读的清单与分段），而且焦点状态在重建时先被清掉，「原来在不在侧栏」事后问不出来（实拍：带这个条件时
    /// 几轮之后又变灰）。窗口不在前台时设焦点不会把它拉到前台。
    @FocusState private var sidebarFocused: Bool

    var body: some View {
        let xs = store.activities
        NavigationSplitView {
            List(selection: $model.selected) {
                Section(L("对话", "Conversations")) {
                    ForEach(SidebarModel.conversations(xs, order: model.conversationOrder)) { n in
                        if let kids = n.children, !kids.isEmpty {
                            // 嵌着稿件的对话默认展开（分镜 ①⓪③）；三角收起时朝里、展开时朝下（Disclosure controls :4）。
                            DisclosureGroup(isExpanded: Binding(get: { !collapsed.contains(n.id) },
                                                                set: { if $0 { collapsed.remove(n.id) } else { collapsed.insert(n.id) } })) {
                                ForEach(kids) { k in sidebarRow(k).tag(k.id) }
                            } label: { sidebarRow(n) }
                            .tag(n.id)
                        } else {
                            sidebarRow(n).tag(n.id)
                        }
                    }
                }
                let drafts = SidebarModel.drafts(xs, order: model.draftOrder)
                if !drafts.isEmpty {
                    Section(L("稿件", "Manuscripts")) {
                        ForEach(drafts) { n in sidebarRow(n).tag(n.id) }
                    }
                }
            }
            .listStyle(.sidebar)
            .focused($sidebarFocused)
            .id(SidebarModel.shape(xs, convOrder: model.conversationOrder, draftOrder: model.draftOrder))
            // 挂在重建出来的那张列表上：新列表出现时才设（onChange 里异步设，实拍有时赶在新列表进窗口之前，整段仍是灰色）。
            .task(id: SidebarModel.shape(xs, convOrder: model.conversationOrder, draftOrder: model.draftOrder)) {
                try? await Task.sleep(for: .milliseconds(60))
                sidebarFocused = true
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            if let id = model.selected, let h = xs.first(where: { $0.id == id }) {
                DetailPane(store: store, hosted: h, model: model)
            } else {
                Text(L("选一场对话或一份稿件", "Pick a conversation or a manuscript")).font(.system(size: 13)).foregroundStyle(Tone.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Surface.base)
            }
        }
    }

    private func sidebarRow(_ n: SidebarNode) -> some View { SidebarRow(node: n, selected: model.selected == n.id) }
}

/// 侧栏一行。图标用强调色（Sidebars :10）、数字用次要灰；被选中、窗口在前台（系统铺强调色底）时两样换成白。
/// 选中与否由列表传进来：09-27 读 backgroundProminence、09-28 交给系统和 listItemTint，深色外观实拍都是蓝底上的蓝图标——
/// 那两条路在这里都不反白。窗口不在前台时选中底是灰的，强调色在灰底上看得清，不换。
struct SidebarRow: View {
    let node: SidebarNode
    let selected: Bool
    @Environment(\.controlActiveState) private var active

    var body: some View {
        let onAccent = selected && active == .key
        HStack {
            Label { Text(node.title).lineLimit(1) } icon: {
                Image(systemName: node.draft ? "doc.text" : "bubble.left").foregroundStyle(onAccent ? Color.white : Color.accentColor)
            }
            Spacer(minLength: 4)
            if node.count > 0 { Text("\(node.count)").font(Ink.number(12, .regular)).foregroundStyle(onAccent ? Color.white : Tone.secondary) }
        }
    }
}

/// 清单里默认折起的组（以后、做完）哪些被点开了：按对话、按组各记各的。
/// 09-28 交互测试第 3 条：原来两组共用一个开关，点开「以后」连做完的几十项一起展开，而且收不回去；换对话也还开着。
struct FoldedGroups: Equatable {
    private var open: Set<String> = []

    static func foldable(_ state: Activity.Chain.State) -> Bool { state == .done || state == .later }

    func folded(_ activity: String, _ state: Activity.Chain.State) -> Bool {
        Self.foldable(state) && !open.contains("\(activity)|\(state.rawValue)")
    }

    /// 折起时露哪几项：到了日子的照样露（10-06 刘海 spec D6），其余收起；点开全列。次序照清单。
    static func visible(_ items: [Activity.Chain.Item], folded: Bool) -> [Activity.Chain.Item] {
        folded ? items.filter { $0.due != nil } : items
    }

    mutating func toggle(_ activity: String, _ state: Activity.Chain.State) {
        guard Self.foldable(state) else { return }
        let k = "\(activity)|\(state.rawValue)"
        if open.contains(k) { open.remove(k) } else { open.insert(k) }
    }
}

/// 右边：顶上一行对话名与分段，下面按分段画清单、稿件或轮次。
struct DetailPane: View {
    /// 顶上那一行和红绿灯同高：内容区从标题栏底下开始，往上挪回标题栏那一截（全尺寸内容区、透明标题栏）。
    static let titlebarInset: CGFloat = 52
    let store: ActivityStore
    let hosted: Hosted
    @Bindable var model: WindowSelection
    @State private var folds = FoldedGroups()

    var body: some View {
        let xs = store.activities
        let isDraft = hosted.activity.ring != nil
        let draft = isDraft ? hosted : PopoverScope.manuscript(in: hosted, xs)
        let tabs: [WindowTab] = isDraft ? [.draft] : (draft != nil ? [.list, .draft, .turns] : [.list, .turns])
        let tab = tabs.contains(model.tab) ? model.tab : tabs[0]
        VStack(spacing: 0) {
            HStack {
                Text(isDraft ? (hosted.activity.ring?.name ?? hosted.id) : PopoverScope.title(hosted))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Tone.primary).lineLimit(1)
                Spacer()
                if tabs.count > 1 {
                    Picker("", selection: Binding(get: { tab }, set: { model.tab = $0 })) {
                        ForEach(tabs) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            }
            .padding(.horizontal, 20).frame(height: 52)
            .padding(.top, -Self.titlebarInset)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .list: listPage(draft)
                    case .draft: if let d = draft { draftPage(d) }
                    case .turns: turnsPage()
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Surface.base)
    }

    /// 清单：要紧的组写全（等你、在做、等别的），以后与做完折成一行；嵌着的稿件卡在下面。
    @ViewBuilder private func listPage(_ draft: Hosted?) -> some View {
        if let c = hosted.activity.chain {
            ForEach(ChainLayout.groups(c), id: \.0) { state, items in
                let folded = folds.folded(hosted.id, state)
                let shown = FoldedGroups.visible(items, folded: folded)
                let due = items.compactMap(\.due)
                ItemGroup(name: ChainLayout.label(state, c.labels), count: items.count, tint: ItemStyle.tint(state),
                          rows: shown.map { AnyView(ChainItemRow(item: $0, tint: ItemStyle.tint(state),
                                                                  onAction: { ChainActions.send(hosted, $0, store: store) })) },
                          more: folded ? items.count - shown.count : 0,
                          onMore: { folds.toggle(hosted.id, state) },
                          onFold: FoldedGroups.foldable(state) ? { folds.toggle(hosted.id, state) } : nil,
                          folded: folded,
                          note: folded && !due.isEmpty ? ChainLayout.dueLabel(due.count) : nil,
                          noteTint: ChainMeta.dueTint(due.map(\.days).min() ?? 0))
            }
        }
        if let d = draft, let m = FlightModel.make(d, registry: store.registry) {
            FlightCard(model: m, style: .panel)
        }
    }

    @ViewBuilder private func draftPage(_ d: Hosted) -> some View {
        if let m = FlightModel.make(d, registry: store.registry), let r = d.activity.ring {
            FlightCard(model: m, style: .panel)
            let hung = r.segments.flatMap(\.items)
            let you = hung.filter { $0.you == true } + r.unhung
            let rerun = hung.filter { $0.you != true }
            if !you.isEmpty {
                ItemGroup(name: m.youLabel, count: you.count, tint: Tone.cyan,
                          rows: you.map { AnyView(ItemRow(symbol: "square", tint: Tone.cyan, tag: $0.id, text: PopoverScope.itemText($0), moved: $0.moved, detail: $0.detail)) })
            }
            if !rerun.isEmpty {
                ItemGroup(name: m.rerunLabel, count: rerun.count, tint: Tone.orange,
                          // 第二行带来源给的原因与改动量（写作循环：「句子改 174 新增 51 删 39」）——09-28 grill 第三轮 R5：只写「要重读」，看不出该不该重跑。
                          rows: rerun.map { AnyView(ItemRow(symbol: "arrow.clockwise", tint: Tone.orange, text: PopoverScope.itemText($0), detail: $0.detail)) })
            }
        }
    }

    /// 轮次：新 → 旧，每轮一块：标签、时刻、用时，下面来源写好的几行。
    @ViewBuilder private func turnsPage() -> some View {
        let turns = hosted.activity.detail?.history ?? []
        if turns.isEmpty {
            Text(L("还没有轮次", "No turns yet")).font(.system(size: 13)).foregroundStyle(Tone.secondary)
        }
        ForEach(turns) { t in
            if t.quiet == true { quietTurn(t) } else { fullTurn(t) }
        }
    }

    /// 不是你说的一轮（后台通知）：一行细条，写时刻与来源给的第一行，不和真实的轮次一样占整张卡（09-28 面板 grill 第三轮 R3）。
    private func quietTurn(_ t: Activity.Turn) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bell").font(.system(size: 10)).foregroundStyle(Tone.secondary)
            Text(t.lines.first?.text ?? L("后台通知", "Background notice"))
                .font(.system(size: 12)).foregroundStyle(Tone.secondary).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            Text([t.at.map { RingHeader.clock($0) }, t.duration].compactMap { $0 }.joined(separator: " · "))
                .font(Ink.number(11, .regular)).foregroundStyle(Tone.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fullTurn(_ t: Activity.Turn) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(t.tag ?? "").font(.system(size: 13, weight: .semibold)).foregroundStyle(Tone.primary)
                    Spacer()
                    Text([t.at.map { RingHeader.clock($0) }, t.duration].compactMap { $0 }.joined(separator: " · "))
                        .font(Ink.number(12, .regular)).foregroundStyle(Tone.secondary)
                }
                ForEach(Array(t.lines.enumerated()), id: \.offset) { _, l in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(l.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tone.secondary).frame(width: 40, alignment: .leading)
                        Text(l.text).font(.system(size: 13)).foregroundStyle(Tone.primary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Surface.group))
    }
}
