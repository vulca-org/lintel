import AppKit
import LintelCore
import SwiftUI

// 第五版点刘海（分镜 ①⓪②）：一个指着刘海的弹出框，只讲这场对话。跟随系统深浅（Panels :13 优先标准外观，不用 HUD），
// 点外面就关、没有「收起」（Popovers :5），只放少量内容（:2），可以拖出来变成窗口（:16–:18）。
// 分段只有「清单 / 稿件」（名词，Segmented controls :15）；对话里没嵌稿件时只有清单，不画分段。

/// 弹出框里讲哪场对话、有哪些可换。
@MainActor
enum PopoverScope {
    /// 可以换到的对话：开着、没有环、没嵌在别的对话里；最近动过的在前。
    static func conversations(_ xs: [Hosted]) -> [Hosted] {
        xs.filter { $0.activity.open && $0.activity.ring == nil && Ordering.parent(of: $0, in: xs) == nil }
            .sorted { ($0.activity.activityAt ?? .distantPast) > ($1.activity.activityAt ?? .distantPast) }
    }

    static func title(_ h: Hosted) -> String { h.activity.name ?? h.activity.flip?.title ?? h.activity.label?.text ?? String(h.id.suffix(8)) }

    /// 嵌在这场对话里的稿件（v1 一场对话只画一份）。
    static func manuscript(in h: Hosted, _ xs: [Hosted]) -> Hosted? { Nesting.ring(in: h, xs)?.child }

    /// 环上的一件事去掉来源写在前面的「风险 W8 」：编号另放一列（分镜 ①⓪② 的 W8、R4）。
    static func itemText(_ i: Activity.Ring.Item) -> String {
        for p in ["风险 \(i.id) ", "\(i.id) "] where i.text.hasPrefix(p) { return String(i.text.dropFirst(p.count)) }
        return i.text
    }
}

/// 弹出框的内容。
struct PopoverView: View {
    enum Tab: String, CaseIterable { case list, draft }

    let store: ActivityStore
    @State var focus: String
    @State var tab: Tab = .list
    /// 宿主选的那一场与选它的原因；换到别的对话后不再显示原因。
    var chosen: String? = nil
    var reason: Ordering.FocusReason? = nil
    var onOpenWindow: ((String) -> Void)?
    /// 换了对话告诉外面：拖出来要开的是现在这场，不是弹出时那场（09-28 交互测试第 18 条）。
    var onFocus: ((String) -> Void)?

    static func reasonText(_ r: Ordering.FocusReason) -> String {
        switch r {
        case .pinned: return L("你钉住的", "Pinned")
        case .anomaly: return L("出异常", "Problem")
        case .waiting: return L("有事等你", "Waiting on you")
        case .event: return L("刚发生", "Just happened")
        case .unread: return L("有新的一轮", "New turn")
        }
    }

    static let width: CGFloat = 380
    static let youRows = 3
    static let draftRows = 4

    var body: some View {
        let xs = store.activities
        let h = xs.first { $0.id == focus } ?? PopoverScope.conversations(xs).first
        VStack(alignment: .leading, spacing: 0) {
            if let h {
                let draft = PopoverScope.manuscript(in: h, xs)
                header(h, xs, hasDraft: draft != nil)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
                VStack(alignment: .leading, spacing: 12) {
                    if tab == .draft, let d = draft { draftPage(d) } else { listPage(h, draft) }
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
                footer(h)
            } else {
                Text(L("没有开着的对话", "No open conversations")).font(.system(size: 13)).foregroundStyle(Tone.secondary).padding(16)
            }
        }
        .frame(width: Self.width, alignment: .topLeading)
        .background(Surface.base)
        .onChange(of: focus) { _, id in onFocus?(id) }
    }

    // MARK: 头

    private func header(_ h: Hosted, _ xs: [Hosted], hasDraft: Bool) -> some View {
        HStack(spacing: 8) {
            let all = PopoverScope.conversations(xs)
            // 对话名是普通文字，能拖（09-30 复现 D1：整个名字原来就是菜单按钮，从顶上一行起拖，按下就开了菜单）；
            // 换一场对话只点名字旁的上下箭头（作者 09-30 选定）。
            Text(PopoverScope.title(h)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Tone.primary).lineLimit(1)
            Menu {
                ForEach(all, id: \.id) { c in
                    Button(PopoverScope.title(c)) { focus = c.id; tab = .list }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tone.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .fixedSize()
            .disabled(all.count < 2)
            .help(L("换一场对话", "Switch conversation"))
            .accessibilityLabel(L("换一场对话", "Switch conversation"))
            // 为什么落在这一场（09-28 面板 grill 第三轮 R6）。
            if let r = reason, h.id == chosen {
                Text(Self.reasonText(r))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tone.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Surface.group))
                    .help(L("弹出框按急缓挑对话：出异常、有事等你、刚发生、有新的一轮，依次优先", "The popover opens on the most urgent conversation: a problem, something waiting on you, something that just happened, then a new turn"))
            }
            Spacer(minLength: 8)
            if hasDraft {
                Picker("", selection: $tab) {
                    Text(L("清单", "List")).tag(Tab.list)
                    Text(L("稿件", "Manuscript")).tag(Tab.draft)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    // MARK: 清单页：等你的前三件，下面是嵌着的稿件

    @ViewBuilder private func listPage(_ h: Hosted, _ draft: Hosted?) -> some View {
        if let c = h.activity.chain {
            let (state, items) = Self.leadGroup(c)
            if let state {
                group(ChainLayout.label(state, c.labels), items.count, state == .you ? Tone.cyan : Tone.secondary,
                      rows: items.prefix(Self.youRows).map { AnyView(ChainItemRow(item: $0, tint: state == .you ? Tone.cyan : Tone.secondary,
                                                                                   symbol: state == .you ? "square" : "circle.lefthalf.filled",
                                                                                   onAction: { ChainActions.send(h, $0, store: store) })) },
                      more: items.count - Self.youRows, open: Self.moreTarget(tab: .list, conversation: h.id, draft: draft?.id))
            }
            // 到了日子的「等别的」「以后」：主组下面另起一段，最多 2 行（10-06 刘海 spec D5；10-06 实见等你 8 项把三行占满，
            // 已过 18 天的「以后」和约在当天的「等别的」只在窗口里）。
            let due = Self.dueRows(c, shown: state == nil ? [] : Array(items.prefix(Self.youRows)))
            if !due.rows.isEmpty {
                group(L("到日子", "Due"), due.total, ChainMeta.dueTint(due.rows[0].due?.days ?? 0),
                      rows: due.rows.map { AnyView(ChainItemRow(item: $0, tint: ItemStyle.tint($0.state),
                                                                 onAction: { ChainActions.send(h, $0, store: store) })) },
                      more: due.total - due.rows.count, open: Self.moreTarget(tab: .list, conversation: h.id, draft: draft?.id))
            } else if state == nil {
                Text(L("清单里没有开着的事", "Nothing open on the list")).font(.system(size: 12)).foregroundStyle(Tone.secondary)
            }
        }
        if let d = draft, let m = FlightModel.make(d, registry: store.registry) {
            FlightCard(model: m, style: .panel)
        }
    }

    /// 到日子段最多几行：和回复末尾那一行一样是 2（10-06 刘海 spec D5）。
    static let dueMax = 2

    /// 到日子段放哪几项：主组里已经画出来的不重复，日子越早越先；total 是没在主组里画过的到日子项总数。
    static func dueRows(_ c: Activity.Chain, shown: [Activity.Chain.Item]) -> (rows: [Activity.Chain.Item], total: Int) {
        let drawn = Set(shown.map(\.id))
        let xs = ChainLayout.due(c).filter { !drawn.contains($0.id) }
        return (Array(xs.prefix(dueMax)), xs.count)
    }

    /// 清单页放哪一组：有等你的放等你，没有就放在做，再没有就放等别的。
    static func leadGroup(_ c: Activity.Chain) -> (Activity.Chain.State?, [Activity.Chain.Item]) {
        for s in [Activity.Chain.State.you, .doing, .other] {
            let xs = c.items.filter { $0.state == s }
            if !xs.isEmpty { return (s, xs) }
        }
        return (nil, [])
    }

    // MARK: 稿件页：航班卡、等你裁、要重跑

    @ViewBuilder private func draftPage(_ d: Hosted) -> some View {
        if let m = FlightModel.make(d, registry: store.registry), let r = d.activity.ring {
            FlightCard(model: m, style: .panel)
            let hung = r.segments.flatMap(\.items)
            let you = hung.filter { $0.you == true } + r.unhung
            let rerun = hung.filter { $0.you != true }
            if !you.isEmpty {
                group(m.youLabel, you.count, Tone.cyan,
                      rows: you.prefix(Self.draftRows).map { AnyView(ItemRow(symbol: "square", tint: Tone.cyan, tag: $0.id, text: PopoverScope.itemText($0), moved: $0.moved, detail: $0.detail)) },
                      more: you.count - Self.draftRows, open: Self.moreTarget(tab: .draft, conversation: d.id, draft: d.id))
            }
            if !rerun.isEmpty {
                group(m.rerunLabel, rerun.count, Tone.orange,
                      rows: rerun.prefix(Self.draftRows).map { AnyView(ItemRow(symbol: "arrow.clockwise", tint: Tone.orange, text: PopoverScope.itemText($0), detail: $0.detail)) },
                      more: rerun.count - Self.draftRows, open: Self.moreTarget(tab: .draft, conversation: d.id, draft: d.id))
            }
        }
    }

    // MARK: 件

    /// open：点「还有 N 件」开窗口时选中哪一项。弹出框只放少量内容（Popovers :2），全部在窗口里；
    /// 原来这里没把动作传下去，「还有 N 件」是一个灰掉的按钮（09-28 交互测试第 9 条）。
    private func group(_ name: String, _ n: Int, _ tint: Color, rows: [AnyView], more: Int, open: String) -> some View {
        ItemGroup(name: name, count: n, tint: tint, rows: rows, more: more, onMore: Self.moreAction(open: open, onOpenWindow: onOpenWindow))
    }

    /// 「还有 N 件」开哪一项的窗口：清单页是这场对话，稿件页是那份稿件。
    static func moreTarget(tab: Tab, conversation: String, draft: String?) -> String {
        tab == .draft ? (draft ?? conversation) : conversation
    }

    /// 「还有 N 件」的动作：能开窗口时开并选中 open；不能开（没接窗口）时为 nil，按钮照旧灰掉。
    static func moreAction(open: String, onOpenWindow: ((String) -> Void)?) -> (() -> Void)? {
        onOpenWindow.map { f in { f(open) } }
    }

    private func row(symbol: String, tint: Color, tag: String?, text: String, moved: String? = nil, help: String? = nil) -> some View {
        ItemRow(symbol: symbol, tint: tint, tag: tag, text: text, moved: moved, help: help)
    }

    @ViewBuilder private func footer(_ h: Hosted) -> some View {
        if let open = onOpenWindow {
            Divider()
            Button { open(h.id) } label: {
                Label(L("在窗口中打开", "Open in window"), systemImage: "rectangle.portrait.and.arrow.forward")
                    .font(.system(size: 12))
                    .foregroundStyle(Tone.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: 控制

/// 本 app 的普通窗口在屏幕上的前后位置：打开弹出框要激活本 app，激活会把普通窗口一起提到最前，这里记下再放回。
@MainActor
enum WindowOrder {
    struct Entry: Equatable { let number: Int; let pid: Int32; let layer: Int }

    /// 屏上窗口，从前到后。
    static func screen() -> [Entry] {
        let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return l.compactMap { w in
            guard let n = w[kCGWindowNumber as String] as? Int, let p = w[kCGWindowOwnerPID as String] as? Int32 else { return nil }
            return Entry(number: n, pid: p, layer: w[kCGWindowLayer as String] as? Int ?? 0)
        }
    }

    /// 本 app 的普通层窗口里，排在别的 app 最前一个普通窗口后面的那些；连同那个窗口号一起返回，激活后放回它后面。
    /// 本 app 的窗口本来就在最前时返回空：用户正看着它，不动。
    nonisolated static func behindOthers(_ order: [Entry], ours: Int32) -> (anchor: Int, windows: [Int])? {
        let normal = order.filter { $0.layer == 0 }
        guard let i = normal.firstIndex(where: { $0.pid != ours }) else { return nil }
        let behind = normal[(i + 1)...].filter { $0.pid == ours }.map(\.number)
        return behind.isEmpty ? nil : (normal[i].number, behind)
    }

    /// 激活之前先把这些窗口设成透明：激活会先把它们提到最前再被放回去，中间约 50 ms 整窗盖在别的 app 上面
    /// （作者 09-28 报点悬停卡时有闪烁，录屏第 126–128 帧）。放回原位、核对过次序再显示。
    static func hide(_ keep: (anchor: Int, windows: [Int])?) {
        guard let keep else { return }
        for n in keep.windows { NSApp.windows.first { $0.windowNumber == n }?.alphaValue = 0 }
    }

    static func restore(_ keep: (anchor: Int, windows: [Int])?) {
        guard let keep else { return }
        // 激活是异步的：马上放一次，稍后再放两次，免得激活真正完成时系统又把它提上来。每次放完核对次序，对了就显示。
        put(keep)
        for ms in [80, 250, 600] {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(ms))
                put(keep)
                // 最后一次不管核对结果都显示：宁可闪一下，不能让窗口一直透明。
                if ms == 600 || inPlace(screen(), keep) { show(keep) }
            }
        }
    }

    /// 这些窗口是否都已排在那个别的 app 的窗口后面（屏上看不见的不算）。
    nonisolated static func inPlace(_ order: [Entry], _ keep: (anchor: Int, windows: [Int])) -> Bool {
        guard let a = order.firstIndex(where: { $0.number == keep.anchor }) else { return true }
        return keep.windows.allSatisfy { n in order.firstIndex { $0.number == n }.map { $0 > a } ?? true }
    }

    private static func show(_ keep: (anchor: Int, windows: [Int])) {
        for n in keep.windows { NSApp.windows.first { $0.windowNumber == n }?.alphaValue = 1 }
    }

    private static func put(_ keep: (anchor: Int, windows: [Int])) {
        for n in keep.windows.reversed() {
            NSApp.windows.first { $0.windowNumber == n }?.order(.below, relativeTo: keep.anchor)
        }
    }
}

/// 自己拖的几步：按下（系统问能不能拖时）、拖过门槛算开始、之后每次是移动、松手。
struct OwnDrag {
    static let threshold: CGFloat = 6
    enum Step: Equatable { case none, start, move }
    private var start: CGPoint?
    private var moving = false

    mutating func begin(at p: CGPoint) { start = p; moving = false }

    mutating func dragged(to p: CGPoint) -> Step {
        guard let s = start else { return .none }
        if moving { return .move }
        guard hypot(p.x - s.x, p.y - s.y) >= Self.threshold else { return .none }
        moving = true
        return .start
    }

    /// 松手；返回刚才是不是真拖过。
    mutating func end() -> Bool {
        defer { start = nil; moving = false }
        return moving
    }
}

/// 弹出框本身：系统 NSPopover，挂在刘海舞台上（探针结论见 docs/verification/2026-09-24-nav-v5/README.md 第 0 节）：
/// 弹出框窗口要比舞台高一层，否则舞台透明区接走拖动；打开时激活本 app，点外面才关得掉、才拖得出来；关掉时把前台还给原来那个 app。
@MainActor
final class ConversationPopover: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?
    private var previous: NSRunningApplication?
    private var appearanceWatch: NSKeyValueObservation?
    var onClosed: () -> Void = {}
    /// 拖出来时要的窗口（第 7 块）；nil 时系统自己把内容放进一个浮动窗口。
    var detachWindow: ((String) -> NSWindow?)?
    /// 真拖出来了：选中现在这场、把窗口挪回屏内。
    var didDetach: ((String) -> Void)?
    var onOpenWindow: ((String) -> Void)?
    private var focus: String = ""
    /// 系统来要过窗口（开始拖）：要的那个窗口，和当时它可不可见。
    private var detachTarget: (window: NSWindow, wasVisible: Bool)?
    /// 窗口已经开着时自己拖（见 nativeDetach）：窗口开没开着、拖过门槛（关弹出框、窗口到鼠标下）、跟着移动、松手。
    var windowVisible: (() -> Bool)?
    var ownDragged: ((String, NSPoint) -> Void)?
    var ownMoved: ((NSPoint) -> Void)?
    var ownEnded: (() -> Void)?
    private var ownDrag = OwnDrag()
    private var monitor: Any?

    var isShown: Bool { popover?.isShown ?? false }
    /// 上一次关掉的时刻：点刘海关掉弹出框时，同一次点击不能再把它打开。
    private(set) var closedAt: Date?

    func show(store: ActivityStore, focus: String, tab: PopoverView.Tab = .list, reason: Ordering.FocusReason? = nil,
              relativeTo rect: NSRect, of view: NSView) {
        close()
        self.focus = focus
        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        let host = NSHostingController(rootView: PopoverView(store: store, focus: focus, tab: tab, chosen: focus, reason: reason, onOpenWindow: onOpenWindow.map { f in
            // 要开窗口：关弹出框时不把前台还给原来的 app，否则窗口刚开就被压到那个 app 后面（09-28 实测 z=2、前台 Claude）。
            { [weak self] id in self?.previous = nil; self?.close(); f(id) }
        }, onFocus: { [weak self] id in self?.focus = id }))
        host.sizingOptions = [.preferredContentSize]
        p.contentViewController = host
        p.delegate = self
        p.appearance = Self.systemAppearance()
        // 系统换深浅：弹出框跟着换（舞台定死 darkAqua，不能靠继承）。
        appearanceWatch = NSApp.observe(\.effectiveAppearance) { [weak p] _, _ in
            MainActor.assumeIsolated { p?.appearance = Self.systemAppearance() }
        }
        popover = p
        if !NSApp.isActive { previous = NSWorkspace.shared.frontmostApplication }
        // 激活本 app 会把本 app 的普通窗口（第 7 块的窗口）一起提到最前：作者 09-28 报点悬停卡时全部面板一起出来、点别处又一起关掉。
        // 先记下哪些普通窗口原本压在别的 app 的窗口后面，激活以后放回去。
        let keep = WindowOrder.behindOthers(WindowOrder.screen(), ours: ProcessInfo.processInfo.processIdentifier)
        WindowOrder.hide(keep)
        NSApp.activate()
        p.show(relativeTo: rect, of: view, preferredEdge: .minY)
        WindowOrder.restore(keep)
        if let w = host.view.window, let stage = view.window {
            w.level = NSWindow.Level(rawValue: stage.level.rawValue + 1)
        }
    }

    func close() {
        popover?.performClose(nil)
    }

    static func systemAppearance() -> NSAppearance? {
        if let forced = PresentDemo.appearance { return NSAppearance(named: forced) }
        let sys = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
        return NSAppearance(named: sys)
    }

    /// 系统只往看不见的窗口里拖：窗口已经开着（哪怕压在别的 app 后面）时拖不出来（09-30 复现：开着 3 次都没反应，关着 1 次就出来）。
    /// 所以窗口开着时不交给系统，自己拖；关着照旧交给系统（它会把弹出框变成窗口的样子拖出来）。
    nonisolated static func nativeDetach(windowVisible: Bool) -> Bool { !windowVisible }

    /// 系统在弹出框能拖的地方按下时来问（点在按钮、菜单上不问）；自己拖也从这里起步，所以同样不会从按钮上拖起。
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        let native = Self.nativeDetach(windowVisible: windowVisible?() ?? false)
        Self.log("shouldDetach native=\(native)")
        if !native { watchDrag(); ownDrag.begin(at: NSEvent.mouseLocation) }
        return native
    }

    /// 本 app 的拖动与松手事件只看不拦；弹出框关掉以后同一次按住还在拖，所以装上就不拆。
    private func watchDrag() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] e in
            MainActor.assumeIsolated { self?.track(e.type) }
            return e
        }
    }

    private func track(_ type: NSEvent.EventType) {
        let p = NSEvent.mouseLocation
        if type == .leftMouseUp {
            if ownDrag.end() { Self.log("own-drag end"); ownEnded?() }
            return
        }
        switch ownDrag.dragged(to: p) {
        case .start:
            let id = focus
            Self.log("own-drag focus=\(id.prefix(14))")
            previous = nil      // 窗口要到前面来：关弹出框时不把前台还给原来的 app
            close()
            ownDragged?(id, p)
        case .move:
            ownMoved?(p)
        case .none:
            break
        }
    }

    func detachableWindow(for popover: NSPopover) -> NSWindow? {
        let w = detachWindow?(focus)
        detachTarget = w.map { ($0, $0.isVisible) }
        Self.log("detachableWindow → \(w.map { "\($0.frame)" } ?? "nil")")
        return w
    }

    func popoverDidDetach(_ popover: NSPopover) {
        // 拖出来成了窗口：同上，不把前台还回去。
        previous = nil
        Self.log("didDetach focus=\(focus.prefix(14))")
    }

    static func log(_ m: String) {
        guard PresentDemo.logging || PresentDemo.seconds != nil else { return }
        FileHandle.standardError.write(Data("\(Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(Date())) popover \(m)\n".utf8))
    }

    /// 给了自己的窗口时，拖出来系统不调 popoverDidDetach，只关弹出框（09-28 实测：shouldDetach → detachableWindow → closed）。
    /// 按下鼠标没拖也会来要窗口，所以看关掉时它是不是从看不见变成看得见了。开始前就开着的窗口分不清，当没拖出。
    nonisolated static func detachedOnClose(requested: Bool, wasVisible: Bool, isVisible: Bool) -> Bool {
        requested && !wasVisible && isVisible
    }

    func popoverDidClose(_ notification: Notification) {
        closedAt = Date()
        if let t = detachTarget, Self.detachedOnClose(requested: true, wasVisible: t.wasVisible, isVisible: t.window.isVisible) {
            // 拖出来成了窗口：不把前台还回去，选中现在这场、挪回屏内。
            previous = nil
            Self.log("detached focus=\(focus.prefix(14))")
            didDetach?(focus)
        }
        detachTarget = nil
        appearanceWatch = nil
        popover = nil
        // 把前台还给点刘海之前的那个 app（弹出框只是暂时看一眼，Popovers :3）。点别的 app 关掉的，那个 app 已经在前台，不抢回来。
        if NSApp.isActive, let prev = previous, prev != NSRunningApplication.current { prev.activate() }
        previous = nil
        onClosed()
    }
}
