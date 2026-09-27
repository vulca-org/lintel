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
    var onOpenWindow: ((String) -> Void)?

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
    }

    // MARK: 头

    private func header(_ h: Hosted, _ xs: [Hosted], hasDraft: Bool) -> some View {
        HStack(spacing: 8) {
            let all = PopoverScope.conversations(xs)
            // 对话名旁的上下箭头：换一场对话（macOS 的弹出按钮就是这个样子）。
            Menu {
                ForEach(all, id: \.id) { c in
                    Button(PopoverScope.title(c)) { focus = c.id; tab = .list }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(PopoverScope.title(h)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Tone.primary).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Tone.secondary)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .fixedSize()
            .disabled(all.count < 2)
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
                                                                                   symbol: state == .you ? "square" : "circle.lefthalf.filled")) },
                      more: items.count - Self.youRows)
            } else {
                Text(L("清单里没有开着的事", "Nothing open on the list")).font(.system(size: 12)).foregroundStyle(Tone.secondary)
            }
        }
        if let d = draft, let m = FlightModel.make(d, registry: store.registry) {
            FlightCard(model: m, style: .panel)
        }
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
                      more: you.count - Self.draftRows)
            }
            if !rerun.isEmpty {
                group(m.rerunLabel, rerun.count, Tone.orange,
                      rows: rerun.prefix(Self.draftRows).map { AnyView(row(symbol: "arrow.clockwise", tint: Tone.orange, tag: nil, text: PopoverScope.itemText($0))) },
                      more: rerun.count - Self.draftRows)
            }
        }
    }

    // MARK: 件

    private func group(_ name: String, _ n: Int, _ tint: Color, rows: [AnyView], more: Int) -> some View {
        ItemGroup(name: name, count: n, tint: tint, rows: rows, more: more)
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
    var onOpenWindow: ((String) -> Void)?
    private var focus: String = ""

    var isShown: Bool { popover?.isShown ?? false }
    /// 上一次关掉的时刻：点刘海关掉弹出框时，同一次点击不能再把它打开。
    private(set) var closedAt: Date?

    func show(store: ActivityStore, focus: String, tab: PopoverView.Tab = .list, relativeTo rect: NSRect, of view: NSView) {
        close()
        self.focus = focus
        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        let host = NSHostingController(rootView: PopoverView(store: store, focus: focus, tab: tab, onOpenWindow: onOpenWindow.map { f in
            { [weak self] id in self?.close(); f(id) }
        }))
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
        NSApp.activate()
        p.show(relativeTo: rect, of: view, preferredEdge: .minY)
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

    func popoverShouldDetach(_ popover: NSPopover) -> Bool { Self.log("shouldDetach"); return true }

    func detachableWindow(for popover: NSPopover) -> NSWindow? {
        let w = detachWindow?(focus)
        Self.log("detachableWindow → \(w.map { "\($0.frame)" } ?? "nil")")
        return w
    }

    func popoverDidDetach(_ popover: NSPopover) { Self.log("didDetach") }

    static func log(_ m: String) {
        guard PresentDemo.logging || PresentDemo.seconds != nil else { return }
        FileHandle.standardError.write(Data("\(Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(Date())) popover \(m)\n".utf8))
    }

    func popoverDidClose(_ notification: Notification) {
        closedAt = Date()
        appearanceWatch = nil
        popover = nil
        // 把前台还给点刘海之前的那个 app（弹出框只是暂时看一眼，Popovers :3）。点别的 app 关掉的，那个 app 已经在前台，不抢回来。
        if NSApp.isActive, let prev = previous, prev != NSRunningApplication.current { prev.activate() }
        previous = nil
        onClosed()
    }
}
