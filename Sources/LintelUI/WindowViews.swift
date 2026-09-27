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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if rows.isEmpty, let onMore {
                // 折起的组（以后、做完）：组名、条数、一个朝右的小箭头，点开才列（写着条数，不算悄悄藏起来）。
                Button(action: onMore) {
                    HStack(spacing: 4) {
                        Text(name).font(.system(size: 12, weight: .semibold))
                        Text("\(count)").font(Ink.number(12, .regular))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
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
    static func conversations(_ xs: [Hosted]) -> [SidebarNode] {
        PopoverScope.conversations(xs).map { h in
            let child = PopoverScope.manuscript(in: h, xs).map { [node($0, draft: true)] }
            return SidebarNode(id: h.id, title: PopoverScope.title(h), count: IslandText.waiting(h.activity)?.count ?? 0, draft: false,
                               children: child)
        }
    }

    static func drafts(_ xs: [Hosted]) -> [SidebarNode] {
        xs.filter { $0.activity.open && $0.activity.ring != nil && Ordering.parent(of: $0, in: xs) == nil }
            .sorted { ($0.activity.activityAt ?? .distantPast) > ($1.activity.activityAt ?? .distantPast) }
            .map { node($0, draft: true) }
    }

    /// 侧栏的骨架：哪几场对话按什么顺序、各自嵌着哪份稿件、哪些稿件单列。骨架一变，侧栏整个重建（见 `.id`）。
    /// 选中的稿件从一场对话挪到另一场下面时，列表逐项更新会在旧位置留下它的残影（09-25 实拍：对话那一行叠着稿件的图标和字，
    /// 两行同时是选中色，之后一直不消）。标题、数字变了骨架不变，照旧逐项更新。
    static func shape(_ xs: [Hosted]) -> String {
        let convs = conversations(xs).map { n in ([n.id] + (n.children ?? []).map(\.id)).joined(separator: ">") }
        return (convs + ["|"] + drafts(xs).map(\.id)).joined(separator: "\n")
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
                    ForEach(SidebarModel.conversations(xs)) { n in
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
                let drafts = SidebarModel.drafts(xs)
                if !drafts.isEmpty {
                    Section(L("稿件", "Manuscripts")) {
                        ForEach(drafts) { n in sidebarRow(n).tag(n.id) }
                    }
                }
            }
            .listStyle(.sidebar)
            .focused($sidebarFocused)
            .id(SidebarModel.shape(xs))
            // 挂在重建出来的那张列表上：新列表出现时才设（onChange 里异步设，实拍有时赶在新列表进窗口之前，整段仍是灰色）。
            .task(id: SidebarModel.shape(xs)) {
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

    private func sidebarRow(_ n: SidebarNode) -> some View { SidebarRow(node: n) }
}

/// 侧栏一行。图标用强调色、数字用次要灰；被选中铺上强调色底时两样都换成白（09-27 面板 grill 10：蓝底上的蓝图标、灰数字看不见）。
/// 系统在选中行把 backgroundProminence 设成 .increased，写死的颜色不会自己反白，要读它。
struct SidebarRow: View {
    let node: SidebarNode
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let selected = prominence == .increased
        HStack {
            // 侧栏图标用 app 的强调色、跟随系统强调色（Sidebars :10）。
            Label { Text(node.title).lineLimit(1) } icon: {
                Image(systemName: node.draft ? "doc.text" : "bubble.left").foregroundStyle(selected ? Color.white : Color.accentColor)
            }
            Spacer(minLength: 4)
            if node.count > 0 { Text("\(node.count)").font(Ink.number(12, .regular)).foregroundStyle(selected ? Color.white : Tone.secondary) }
        }
    }
}

/// 右边：顶上一行对话名与分段，下面按分段画清单、稿件或轮次。
struct DetailPane: View {
    /// 顶上那一行和红绿灯同高：内容区从标题栏底下开始，往上挪回标题栏那一截（全尺寸内容区、透明标题栏）。
    static let titlebarInset: CGFloat = 52
    let store: ActivityStore
    let hosted: Hosted
    @Bindable var model: WindowSelection
    @State private var openDone = false

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
                let folded = (state == .done || state == .later) && !openDone
                ItemGroup(name: ChainLayout.label(state, c.labels), count: items.count, tint: ItemStyle.tint(state),
                          rows: folded ? [] : items.map { AnyView(ChainItemRow(item: $0, tint: ItemStyle.tint(state))) },
                          more: folded ? items.count : 0, onMore: { openDone = true })
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
                          rows: rerun.map { AnyView(ItemRow(symbol: "arrow.clockwise", tint: Tone.orange, text: PopoverScope.itemText($0))) })
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
}
