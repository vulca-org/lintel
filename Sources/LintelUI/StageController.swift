import AppKit
import LintelCore
import SwiftUI

// 从许愿柳 f4d6690 `App/IslandController.swift` 搬来：几何、舞台、弹簧、胶囊、悬停、面板、让位逐行照搬。
// 改动只在数据来源：WillowStore → ActivityStore，FocusRule → Ordering，许愿柳的五个回调 → 活动事件（按登记里的属性决定展开还是收起）。

/// 刘海位置的面板。
///
/// 为什么又回到刘海：先前默认走菜单栏，理由是刘海会和别的 app 冲突。
/// 但真实截图和这台机器的设置推翻了它 —— `_HIHideMenuBar = 1`，菜单栏自动隐藏，
/// 状态项大部分时间根本看不见，「常亮」在这里不可能成立。
/// 面板放在 `.mainMenu + 3`，菜单栏藏不藏都在。
///
/// 冲突的处理：boring.notch、Alcove、NotchNook 也在这一层盖同一块矩形，系统不仲裁。
/// 检测到它们在跑，就**不抢那块矩形**，改挂在刘海正下方。检测是按名字的启发式，写明白。
///
/// 窗口是固定大小的透明舞台。**不要设置 `ignoresMouseEvents`**：保持默认时，窗口里 alpha 为 0 的像素
/// 让鼠标事件穿过去，舞台的透明部分不挡菜单栏；显式设成 false 会让整块舞台吞掉点击。
final class StagePanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .mainMenu + 3
        collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        appearance = NSAppearance(named: .darkAqua)
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class StageController {
    private let store: ActivityStore
    private let seen: SeenStore
    private let state = StageState()
    private let panel = StagePanel()
    private var autoCollapse: Timer?
    private var hoverIntent: DispatchWorkItem?
    private var pillEmerge: DispatchWorkItem?
    private var pillRetract: DispatchWorkItem?
    private var arrivals = ArrivalQueue()
    private var dodgeTimer: Timer?
    /// 让路的目标位置（0 或菜单栏高度）。state.dodge 是此刻画到了哪，逐帧追这个值。
    private var dodgeTarget: CGFloat = 0
    /// 让路那一段的逐帧推进：起点、终点、开始时刻、方向。
    private struct DodgeTrack { let from: CGFloat; let to: CGFloat; let start: CFTimeInterval; let down: Bool }
    private var dropNoticeTimer: Timer?
    private var pillIntent: DispatchWorkItem?
    /// 两个来源同时有弹卡排着时谁先（作者 09-22）：许愿柳在前，写作循环在后。
    static let popOrder = ["willow"]
    /// 弹卡冷却（A，作者 09-21）：上一次弹卡的时刻；冷却期内到达的排队，到期每个来源只弹最新一条，一次一个来源。
    private var lastFlashAt: Date?
    private var cooldownTimer: Timer?
    /// 上一次弹卡的来源：排队时它排到最后，两个来源轮流弹。
    private var lastFlashSource: String?
    /// 悬停胶囊展开的时刻（B）：之后第一秒里指针从胶囊挪进卡里，不算离开。
    private var pillOpenedAt: Date?
    private var dodgeTrack: DodgeTrack?

    public private(set) var yielding = false

    static let wingMax: CGFloat = 124
    static let wing: CGFloat = 92   // 76 贴圆角、84 加内边距后截断成「审幻灯片…」；按 6 字 ≈ 72pt 算
    /// 内容宽；形状再加两侧凹肩。582 = 面板内容宽，582 : 360 ≈ φ（作者 2026-09-22 B-5 第 5 项；原来 500，不在任何比例上）。
    static let expandedWidth: CGFloat = ExpandedV5.width
    /// 主动弹出的精简版的内容宽。原来 440 是按 156 宽的刘海算的（两侧各留约 142）；本机刘海 185，两侧只剩 127，
    /// 09-24 实拍耳朵被截成「W …」「答…」（L27）。按 185 算两侧各留约 157。
    static let compactWidth: CGFloat = 500
    static let maxExpandedHeight: CGFloat = 470
    /// 展开卡统一高度（作者 09-21：「全部统一成许愿柳现在的高度」）：许愿柳展开卡的自然高度实测 360（同日日志 natural=360）。
    /// 内容更高的滚，更矮的留白；卡底那一层钉在底。
    static let uniformExpandedHeight: CGFloat = 360
    static let pillHeight: CGFloat = 24
    /// 胶囊中心的纵坐标（相对岛顶）。平时在刘海高度里居中；让路时尺寸不变，顶边和主体顶边对齐，一起贴住菜单栏底边。
    /// 先前让路时把胶囊从 24pt 拉到 28pt，用户指出不该变大，应保持尺寸、只对齐顶边（2026-09-13）。
    static func dodgedPillCenterY(dodge: CGFloat, depth: CGFloat, notchHeight: CGFloat, height: CGFloat = pillHeight) -> CGFloat {
        let p = depth > 0 ? max(0, min(1, dodge / depth)) : 0
        return notchHeight / 2 - max(0, notchHeight - height) / 2 * p
    }
    static let pillGap: CGFloat = 6
    static let pillMax: CGFloat = 120
    /// 鼠标停在胶囊上时向右长出的宽度，用来放那个会话的标签。
    static let pillPreview: CGFloat = 130     // 标签 + 「· 共 N 个」
    /// 悬停那 0.3 秒里岛先鼓起多少。
    /// 只往两边鼓、不往下鼓：往下那 2pt 在收起态底下读作「多出来一条黑的」（用户 2026-09-13）。
    static let hoverBump = CGSize(width: 10, height: 0)
    static let shadowPad: CGFloat = 16

    // 弹簧参数的基准取自 boring.notch 源码：打开 (0.42, 0.8)、收起 (0.45, 1.0) 不回弹、内容挪位 (0.38, 0.8)。
    // 用户要「从上到下、由内向外」：宽和高拆开走——展开时宽先到（从刘海向两边），高后到（往下长）；
    // 收起反过来，高先收回、宽再收进刘海。
    static let openWidth = Animation.spring(response: 0.34, dampingFraction: 0.84)
    static let openHeight = Animation.spring(response: 0.5, dampingFraction: 0.84)
    /// 展开时高比宽晚起跑多久：让岛先从刘海往两边撑开，再往下长。
    static let openHeightLag: TimeInterval = 0.12
    static let closeHeight = Animation.spring(response: 0.3, dampingFraction: 1.0)
    static let closeWidth = Animation.spring(response: 0.45, dampingFraction: 1.0)
    static let moveSpring = Animation.spring(response: 0.38, dampingFraction: 0.8)
    // 给菜单栏让路的时长与曲线照本机菜单栏实测，写在 DodgeRule（downDuration / upDuration / eased）。
    /// 两端顶角：让路时一开始就收掉凹肩；回刘海时贴回上沿之后再长出来，读作「合上」。
    static let dodgeCornerOut = Animation.easeOut(duration: 0.12)
    static let dodgeCornerIn = Animation.easeOut(duration: 0.16)
    /// 悬停鼓起：短而有一点回弹，像按下去之前的那一下。
    static let hoverSpring = Animation.spring(response: 0.26, dampingFraction: 0.62)
    /// 胶囊滴出去：有回弹，连桥拉长再断开；收回：不回弹，干脆地吸回岛里。
    static let pillOutSpring = Animation.spring(response: 0.52, dampingFraction: 0.64)
    static let pillInSpring = Animation.spring(response: 0.3, dampingFraction: 0.92)
    /// 并入展开面板：比面板长大快（面板宽走 0.34 的弹簧），胶囊始终藏在面板底下。
    /// 用 pillInSpring 时胶囊比面板慢，右上角露出一块圆头 3–4 帧（2026-09-13 逐帧）。
    static let pillMerge = Animation.easeOut(duration: 0.14)
    static let pillHoverSpring = Animation.spring(response: 0.34, dampingFraction: 0.74)
    /// 悬停要停够这么久才展开（boring.notch 的 minimumHoverDuration）：鼠标只是去点菜单栏时路过，不弹。
    static let hoverDelay: TimeInterval = 0.3
    /// 指针离开形状这么久才收（B，作者 09-21）：先前 0.15 s，擦边就开合。
    static let hoverOutGrace: TimeInterval = 0.4
    /// 悬停胶囊展开后这么久内不理「离开」：新形状比胶囊宽，指针要挪进来。
    static let pillOpenGrace: TimeInterval = 1.0
    /// 同一块刘海两次弹卡至少隔这么久（A）：三个会话轮着声明时，26 秒连弹 4 次（09-21 日志）。
    static let flashCooldown: TimeInterval = 10

    public init(store: ActivityStore, seen: SeenStore) {
        self.store = store
        self.seen = seen
    }

    public func start() {
        yielding = Self.otherNotchAppRunning()
        let g = notchGeometry()

        let host = NSHostingView(rootView: StageView(
            store: store, seen: seen, state: state,
            notchWidth: g.width, notchHeight: g.height,
            stemWidth: screen()?.auxiliaryTopLeftArea != nil && !yielding ? g.width : 0,
            onHover: { [weak self] inside in self?.hover(inside) },
            onPillHover: { [weak self] inside in self?.pillHover(inside) },
            // 真实点击在鼠标事件处理里调 openDetail，面板第一次出现就要给 RenderBox 分配新图层表面，
            // 主线程卡在等窗口服务器确认那一帧（09-21 采样：RBLayer display → SharedSurfaceGroup::wait_for_allocations
            // → CAContext waitForCommitId，一次卡 55 秒，面板整块黑）。定时器里开面板从没复现过：挪出事件处理再开。
            onClick: { [weak self] in
                let ev = NSApp.currentEvent.map { "\($0.type.rawValue)" } ?? "nil"
                self?.demoLog("click event=\(ev) → open next turn")
                DispatchQueue.main.async { self?.openDetail() }
            },
            onSeen: { [weak self] in self?.dismissShown() },
            onDropHover: { [weak self] inside in self?.dropHover(inside) },
            onDrop: { [weak self] urls in self?.dropped(urls) },
            onSwitch: { [weak self] id in self?.switchTo(id, byClick: true) },
            onOpenWindow: { [weak self] id in self?.lintelWindow.show(select: id) }
        ))
        // 舞台是固定大小的窗口（placeStage 用 setFrame 定），不需要 SwiftUI 按内容给窗口定尺寸。
        // 默认的 sizingOptions 会在每次更新时重算最小 / 固有 / 最大尺寸约束：胶囊里的符号每闪一帧，整个窗口就重新布局一次（F1，负担实测 2026-09-18）。
        host.sizingOptions = []
        panel.contentView = host

        store.onReload = { [weak self] in
            self?.logSnapshot()
            self?.layout(animated: true)
        }
        // 登记为「需要你注意」的事件：展开精简版（许愿柳：声明到达、等你选择）。
        // 其余事件：刷新；登记了 dismissExpandedAfter 的，正展开着就停一会儿再收起（许愿柳：打断一轮）。
        store.onEvent = { [weak self] h, e, spec in
            if spec.attention { self?.arrive(h.id, reason: "\(e.type)-arrived") }
            else { self?.event(e.type, dismissAfter: spec.dismissExpandedAfter, pinning: h.id) }
        }
        store.start()
        demoLog("host started home=\(store.paths.home.path)")
        placeStage()
        morph(to: targetShapeSize(expanded: false), .move, animated: false)
        updatePill(animated: false)
        panel.orderFrontRegardless()
        startDodgeWatch()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cachedScreen = nil
                self?.cachedGeometry = nil
                self?.placeStage()
                self?.layout(animated: false)
            }
        }
    }

    // MARK: 几何

    /// 让路的计时器每秒 60 次要用到屏幕和刘海几何；每次都遍历 NSScreen.screens 占了它一半的时间（F1 采样）。
    /// 记一份，屏幕参数变了（接外接屏、改分辨率）再重取。
    private var cachedScreen: NSScreen??
    private func screen() -> NSScreen? {
        if let s = cachedScreen { return s }
        let s = NSScreen.screens.first { $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main
        cachedScreen = .some(s)
        return s
    }

    /// 刘海的中心 x 与宽高。没有刘海（外接屏）时给一个虚拟刘海：居中、同宽。
    private var cachedGeometry: (midX: CGFloat, width: CGFloat, height: CGFloat)?
    private func notchGeometry() -> (midX: CGFloat, width: CGFloat, height: CGFloat) {
        if let g = cachedGeometry { return g }
        let g = measureNotch()
        cachedGeometry = g
        return g
    }

    /// 刘海几何只随屏幕变（接外接屏、改分辨率），让路计时器却每秒 60 次要它；记一份，屏幕参数变了再量。
    private func measureNotch() -> (midX: CGFloat, width: CGFloat, height: CGFloat) {
        guard let s = screen() else { return (0, 185, 32) }
        let f = s.frame
        if let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            let w = f.width - l.width - r.width
            return (f.minX + l.width + w / 2, w, s.safeAreaInsets.top)
        }
        return (f.midX, 185, 32)
    }

    /// 形状的目标尺寸（含凹肩）：展开 = 内容宽 + 两肩 × 内容高；收起时有话说才长出两翼，否则缩回刘海宽。
    private func targetShapeSize(expanded: Bool) -> CGSize {
        let g = notchGeometry()
        if expanded {
            let natural = v5Height()
            state.naturalHeight = natural
            return CGSize(width: ExpandedV5.width + 2 * NotchShape.open.top, height: natural)
        }
        // 拖放时两翼按「松手 → 名字」那句话定宽（候选 B）。
        if let text = DropWings.label(state, registry: store.registry) {
            return CGSize(width: g.width + Self.wingWidth(label: text) * 2 + 2 * NotchShape.closed.top, height: g.height)
        }
        // 第五版收起态（分镜 ⑨⑨）：左边标志、右边「等你 N」，两侧等宽。
        let primary = Ordering.pair(store.activities, seen, pinned: state.pinned).primary
        let right = primary.flatMap { IslandText.right($0, label: Ordering.label($0, seen)) }
        var size = CGSize(width: right.map { g.width + CompactWingsV5.wingWidth($0) * 2 + 2 * NotchShape.closed.top } ?? g.width,
                          height: g.height)
        // 缩回刘海时不鼓：鼓出来的那一圈黑色就在物理刘海外面，读作凭空多出来一块。
        if state.hovering, right != nil {
            size.width += Self.hoverBump.width
            size.height += Self.hoverBump.height
        }
        return size
    }

    /// 拖放时两翼的宽：按右翼那句话的字宽，左右等宽（92 按 6 个汉字定，英文标签 ≤14 字符约 95pt）。
    static func wingWidth(label: String?) -> CGFloat {
        guard let label, !label.isEmpty else { return wing }
        let text = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]).width
        return min(wingMax, max(wing, ceil(text) + 12 + 4))
    }

    /// 第二个会话的胶囊宽度。只在收起态出现：展开后它挪进展开态底部那一行。
    private func pillWidth() -> CGFloat {
        guard !state.expanded, !state.popover else { return 0 }
        // 第五版（分镜 ⑨⑨）：第二件事只有没嵌进对话的稿件，画成一颗脱开的小岛；第二个对话不再出岛。
        let pair = Ordering.pair(store.activities, seen, pinned: state.pinned)
        guard Detached.manuscript(store.activities, primary: pair.primary) != nil else { return 0 }
        return Detached.width(notchHeight: notchGeometry().height)
    }

    /// 舞台固定大小：装得下点击面板、最高的展开态、带胶囊（含悬停预览）的收起态，外加阴影。
    ///
    /// 先前舞台跟着形状改尺寸。录屏逐帧量展开时宽度 690→816→787→779→814，不是单调长大；
    /// 推断是窗口变大那一帧旧画面贴在新窗口左下角，形状先偏左再弹回中间——用户看到的「从左到右出现」。
    private func stageSize() -> CGSize {
        let g = notchGeometry()
        let compactWithPill = g.width + Self.wingMax * 2 + 2 * NotchShape.closed.top + Self.hoverBump.width
            + 2 * (Self.pillGap + Self.pillMax + Self.pillPreview + 10)
        let w = max(ExpandedV5.width + 2 * NotchShape.open.top, compactWithPill) + 2 * Self.shadowPad
        let h = Self.maxExpandedHeight + Self.shadowPad
        return CGSize(width: ceil(w), height: ceil(h))
    }

    /// 把舞台放到刘海正下方居中。只在启动和屏幕变化时调用。
    private func placeStage() {
        guard let s = screen() else { return }
        let g = notchGeometry()
        let size = stageSize()
        let drop: CGFloat = yielding ? g.height + 6 : 0      // 让路：挂到刘海下方
        let rect = NSRect(x: g.midX - size.width / 2, y: s.frame.maxY - drop - size.height,
                          width: size.width, height: size.height)
        if panel.frame != rect { panel.setFrame(rect, display: true) }
    }

    /// 黑色形状此刻在屏幕上的矩形。悬停与点外面的判断用它，不用舞台——舞台比形状大。
    private func shapeScreenRect(ignoringDodge: Bool = false) -> NSRect {
        guard let s = screen() else { return .zero }
        let g = notchGeometry()
        let drop: CGFloat = (yielding ? g.height + 6 : 0) + (ignoringDodge ? 0 : state.dodge)
        return NSRect(x: g.midX - state.shapeWidth / 2, y: s.frame.maxY - drop - state.shapeHeight,
                      width: state.shapeWidth, height: state.shapeHeight)
    }

    private enum Motion { case open, close, move, hover }

    /// 形状变到 target。宽、高各自一个动画事务。胶囊另由 updatePill 管。
    private func morph(to target: CGSize, _ motion: Motion, animated: Bool = true) {
        state.layoutHeight = target.height
        guard animated else {
            state.shapeWidth = target.width
            state.shapeHeight = target.height
            return
        }
        switch motion {
        case .open:
            // 高晚一拍再长。宽要走的距离短（两边各 90pt 上下）、高要走 400pt，同时起跑时高的像素跑得快得多：
            // 逐帧看是收起态宽度的一条黑带先往下长、再往两边撑开——用户看到的是下面先多出一条黑带、再展开（2026-09-13）。
            withAnimation(Self.openWidth) { state.shapeWidth = target.width }
            withAnimation(Self.openHeight.delay(Self.openHeightLag)) { state.shapeHeight = target.height }
        case .close:
            withAnimation(Self.closeHeight) { state.shapeHeight = target.height }
            withAnimation(Self.closeWidth) { state.shapeWidth = target.width }
        case .move, .hover:
            withAnimation(motion == .hover ? Self.hoverSpring : Self.moveSpring) {
                state.shapeWidth = target.width
                state.shapeHeight = target.height
            }
        }
    }

    /// 胶囊出场：先在岛里就位（不动画），下一拍再弹出来；退场：弹回岛里，停稳后再撤掉。
    /// delay：岛刚开始收起时等它收稳再滴出去，否则胶囊和正在缩小的岛挤在一起。
    private func updatePill(animated: Bool, delay: TimeInterval = 0, retract: Animation = StageController.pillInSpring) {
        let want = pillWidth()
        guard animated else {
            pillEmerge?.cancel(); pillEmerge = nil
            pillRetract?.cancel(); pillRetract = nil
            state.pillWidth = want
            state.pillOut = want > 0 ? 1 : 0
            if want == 0 { state.pillHover = false }
            return
        }
        if want > 0 {
            pillRetract?.cancel(); pillRetract = nil
            if let pending = pillEmerge, !pending.isCancelled { return }   // 已经排着一次出场，别提前
            let go = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pillEmerge = nil
                let w = self.pillWidth()
                guard w > 0 else { return }
                if self.state.pillWidth == 0 || self.state.pillOut < 0.05 {
                    self.state.pillWidth = w
                    self.state.pillOut = 0
                    // 插入与动画分两拍：同一拍里插入的视图没有「旧值」，弹簧不会从 0 起跳。
                    DispatchQueue.main.async {
                        withAnimation(Self.pillOutSpring) { self.state.pillOut = 1 }
                    }
                } else {
                    if self.state.pillWidth != w { self.state.pillWidth = w }
                    if self.state.pillOut < 1 { withAnimation(Self.pillOutSpring) { self.state.pillOut = 1 } }
                }
            }
            pillEmerge = go
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: go)
        } else if state.pillWidth > 0 {
            pillEmerge?.cancel(); pillEmerge = nil
            guard pillRetract == nil else { return }
            withAnimation(retract) {
                state.pillOut = 0
                state.pillHover = false
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pillRetract = nil
                if self.pillWidth() == 0 { self.state.pillWidth = 0 }
            }
            pillRetract = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }
    }

    /// D 段（设计 B5：换位滞后先量再定）：主位上的来源换了就记一行，跑一天后按次数决定要不要做滞后。
    private var lastPrimarySource: String?
    private func logPrimarySource() {
        // 不算弹卡时临时钉住的那个：D 段要数的是排序本身换了几次，弹卡换位另有 expanded 行（grill 09-22）。
        let now = Ordering.pair(store.activities, seen, pinned: nil).primary?.producer
        guard now != lastPrimarySource else { return }
        demoLog("primary-source \(lastPrimarySource ?? "-")→\(now ?? "-")")
        lastPrimarySource = now
    }

    private func layout(animated: Bool) {
        logPrimarySource()
        holdExpandedHeight()
        let target = targetShapeSize(expanded: state.expanded)
        if !(animated && state.shapeSize == target) {
            morph(to: target, .move, animated: animated)
        }
        updatePill(animated: animated)
    }

    /// 第五版展开态按内容量高（最矮展开约 100，航班卡约 220）。
    private func v5Height() -> CGFloat {
        let g = notchGeometry()
        let probe = NSHostingController(rootView:
            ExpandedV5(store: store, seen: seen, pinned: state.pinned, notchWidth: g.width, notchHeight: g.height, compact: state.compact)
                .frame(width: ExpandedV5.width))
        let fit = probe.sizeThatFits(in: CGSize(width: ExpandedV5.width, height: 10_000))
        return max(g.height + 40, min(Self.maxExpandedHeight, ceil(fit.height)))
    }

    // MARK: 交互

    /// 每次重扫以后记一行「现在有什么」。**只在这一行的内容变了才写**，否则 5 秒一行会把日志刷成噪音；
    /// 但起动那一行永远写，这样「宿主还活着但没事发生」和「宿主卡住了」不再长得一样。
    private var lastSnapshot: String?
    private func logSnapshot() {
        let counts = Dictionary(grouping: store.activities, by: { $0.activity.status?.center.rawValue ?? "无" })
            .map { "\($0.key)=\($0.value.count)" }.sorted().joined(separator: " ")
        let line = "store n=\(store.activities.count) \(counts)"
            + " 开着=\(store.activities.filter { $0.activity.open }.count)"
            + " 在跑=\(store.activities.filter { $0.activity.running }.count)"
            + " 拒收=\(store.rejects.count) 健康=\(store.issues.count)"
        guard line != lastSnapshot else { return }
        lastSnapshot = line
        demoLog(line)
    }

    /// 日志。演示模式（`--present`）一直写；平时要加 `--log` 才写。写 stderr。
    private func demoLog(_ msg: String) {
        guard PresentDemo.seconds != nil || PresentDemo.logging else { return }
        FileHandle.standardError.write(Data("\(Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(Date())) \(msg)\n".utf8))
    }

    private func hover(_ inside: Bool) {
        // 演示要可复现：你的鼠标恰好经过展开后的面板，悬停收回就会让「展开态」截图拍成收起态。
        // 忽略，但记下来——被忽略的事件本身就是证据。
        // 录 README 素材（--backdrop）时也不理悬停：真人鼠标经过会把要拍的展开态收掉——2026-09-13 英文两张静帧就这样拍成了收起态。
        if PresentDemo.seconds != nil && (!PresentDemo.passive || Backdrop.isOn) { demoLog("ignored hover inside=\(inside)"); return }
        hoverBody(inside, force: false)
    }

    /// 悬停的实际处理。force：演示用，不看鼠标实际在不在形状里——录「悬停展开」动效时鼠标不在那儿。
    private func hoverBody(_ inside: Bool, force: Bool) {
        if state.popover { return }                          // 面板打开时悬停不收放
        hoverIntent?.cancel()
        if inside {
            if !state.expanded, !state.hovering {
                // 先鼓一下：鼠标一进来就有回应，不用干等 0.3 秒。
                withAnimation(Self.hoverSpring) { state.hovering = true }
                morph(to: targetShapeSize(expanded: false), .hover)
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self, force || self.shapeScreenRect().insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) else { return }
                self.autoCollapse?.invalidate()
                // 钉住收起态正在显示的那个会话：展开的必须是你刚才看到的那个（HIG：展开态是放大的收起态）。
                if let f = Ordering.pair(self.store.activities, self.seen, pinned: self.state.pinned).primary {
                    self.state.pinned = f.id
                    self.seen.markSeen(f)
                }
                if self.state.expanded && self.state.compact { self.promoteCompact() }
                else { self.setExpanded(true, reason: "hover-in") }
            }
            hoverIntent = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
        } else {
            // 展开时形状在鼠标下面变大，会误报一次「离开」。等一个宽限再看鼠标还在不在形状里；
            // 刚从胶囊展开的，宽限更长（指针要从胶囊挪进卡里）。
            let grace = (pillOpenedAt.map { Date().timeIntervalSince($0) < Self.pillOpenGrace } ?? false) ? Self.pillOpenGrace : Self.hoverOutGrace
            DispatchQueue.main.asyncAfter(deadline: .now() + grace) { [weak self] in
                guard let self else { return }
                guard force || !self.shapeScreenRect().insetBy(dx: -1, dy: -1).contains(NSEvent.mouseLocation) else { return }
                if self.state.expanded {
                    self.setExpanded(false, reason: "hover-out")
                } else if self.state.hovering {
                    withAnimation(Self.hoverSpring) { self.state.hovering = false }
                    self.morph(to: self.targetShapeSize(expanded: false), .hover)
                }
            }
        }
    }

    /// 鼠标停在胶囊上：胶囊向右长出，预览那个会话的标签。
    private func pillHover(_ inside: Bool) {
        if PresentDemo.seconds != nil && (!PresentDemo.passive || Backdrop.isOn) { demoLog("ignored pill hover inside=\(inside)"); return }
        pillIntent?.cancel(); pillIntent = nil
        guard state.pillWidth > 0, !state.expanded, !state.popover else { return }
        withAnimation(Self.pillHoverSpring) { state.pillHover = inside }
        // 分镜 ㉞（作者 09-21）：停稳 hoverDelay 就直接展开胶囊那个来源，不只是预览。
        guard inside else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state.pillHover, !self.state.expanded, !self.state.popover,
                  let other = Detached.manuscript(self.store.activities,
                                                  primary: Ordering.pair(self.store.activities, self.seen, pinned: self.state.pinned).primary) else { return }
            self.demoLog("pill-hover-open \(other.id.prefix(8))")
            self.pillOpenedAt = Date()
            self.switchTo(other.id, force: true)
            self.state.fromIsland = other.id
        }
        pillIntent = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
    }

    /// 需要你注意的事件到达：没在展示别的就展开 6 秒；正在展示另一项就排队，不顶掉你读到一半的那个。
    private func arrive(_ id: String, reason: String) {
        if PresentDemo.seconds != nil && !PresentDemo.passive { demoLog("ignored \(reason)"); return }
        if state.popover { return }
        let showing = state.expanded ? state.pinned : nil
        // 正在展示的就是这个会话（例如声明之后又弹出选择题）：当场刷新、重置计时，不走排队。
        if showing == id {
            demoLog("refresh \(id.prefix(8)) reason=\(reason)")
            flash(pinning: id, reason: reason)
            return
        }
        if arrivals.offer(id, showing: showing) {
            let cooling = lastFlashAt.map { Date().timeIntervalSince($0) < Self.flashCooldown } ?? false
            if cooling || !arrivals.waiting.isEmpty {
                // A：冷却期内不弹，排队；到期每个来源弹它最新的一条，其余留在两翼与胶囊的数里。
                // 队里已有别的来源在等时也排进去，按轮次取，不插队（grill 09-22）。
                _ = arrivals.offer(id, showing: "cooldown")
                demoLog("\(cooling ? "cooldown" : "behind-queue") \(id.prefix(8))")
                layout(animated: true)
                dequeueWhenCool()
            } else {
                flash(pinning: id, reason: reason)
            }
        } else {
            demoLog("queued \(id.prefix(8)) behind \(showing.map { String($0.prefix(8)) } ?? "-")")
            layout(animated: true)
        }
    }

    /// 冷却到期后只弹排队里最新的一条；还在冷却就定个时再来。
    private func dequeueWhenCool() {
        guard !state.expanded, !state.popover else { return }
        let wait = lastFlashAt.map { Self.flashCooldown - Date().timeIntervalSince($0) } ?? 0
        if wait > 0 {
            cooldownTimer?.invalidate()
            cooldownTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.dequeueWhenCool() }
            }
            return
        }
        let alive = Set(Ordering.live(store.activities).filter { Ordering.stillWorthShowing($0, seen) }.map(\.id))
        if let next = arrivals.nextBySource(alive: alive, order: Self.popOrder, after: lastFlashSource) {
            demoLog("dequeued \(next.prefix(8)) (latest of its source after cooldown; \(arrivals.waiting.count) left)")
            flash(pinning: next)
        }
    }

    /// 静止展开 6 秒。不算已读 —— 面板在屏幕顶上出现，不是任何人看过的证据。
    /// 没展开时弹精简版（只放要求与理解）；你正悬停看着完整面板时，不把它缩成精简版。
    private func flash(pinning id: String, reason: String = "declaration-arrived") {
        if state.popover { return }
        lastFlashAt = Date()
        lastFlashSource = ArrivalQueue.source(of: id)
        state.pinned = id
        state.chosen = nil
        state.fromIsland = nil
        if state.expanded {
            morph(to: targetShapeSize(expanded: true), .move)
        } else {
            // 对话：先弹来源写好的弹出几行（理解到达时是「你说的 / 读成的」），鼠标停上去由 promoteCompact 换成最矮两行；
            // 稿件没有弹出几行，直接是航班卡。09-27 作者选 A 加回（第五版曾整个去掉）。
            state.compact = store.activities.first { $0.id == id }.map { ArrivalLines.lines($0, compact: true) != nil } ?? false
            setExpanded(true, reason: reason)
        }
        autoCollapse?.invalidate()
        autoCollapse = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.shapeScreenRect().contains(NSEvent.mouseLocation) { self.setExpanded(false, reason: "flash-timeout") }
            }
        }
    }

    /// 悬停展开、鼠标在面板里时，面板只长不缩：点翻页行翻到内容短的会话，面板一缩鼠标就落到面板外，
    /// 悬停判定当成离开、整个收起（用户 2026-09-13 报）。收起、打开或关掉点击面板时清零。
    /// force：演示里模拟点击翻页行，鼠标不在那儿。
    private func holdExpandedHeight(force: Bool = false) {
        guard state.expanded, !state.popover else { return }
        guard force || shapeScreenRect().insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) else { return }
        state.expandedFloor = max(state.expandedFloor, state.shapeHeight)
    }

    /// 翻页后面板保持的高度，鼠标一回到内容范围、离开底部翻页那一带，就缩回内容本身的高度：
    /// 空着的那块黑色只在「连着点翻页」时留着（用户 2026-09-13：「为了排版空隙太多了」）。
    /// 鼠标还在空白处或翻页行上不缩——一缩它就落到面板外，面板会整个收起。
    private func releaseExpandedFloor() {
        guard state.expanded, !state.popover, !state.compact, state.naturalHeight > 0,
              state.expandedFloor > state.naturalHeight + 1 else { return }
        let rect = shapeScreenRect()
        let p = NSEvent.mouseLocation
        guard rect.contains(p), rect.maxY - p.y < state.naturalHeight - 12 else { return }
        state.expandedFloor = 0
        morph(to: targetShapeSize(expanded: true), .move)
    }

    /// 底部那一行或胶囊：切到那个会话并展开，算看过。byClick：你亲手点的才记成「你点选的」；悬停小岛停稳也走这里，但不算。
    private func switchTo(_ id: String, force: Bool = false, byClick: Bool = false) {
        guard let s = store.activities.first(where: { $0.id == id }) else { return }
        demoLog("switch \(id.prefix(8))\(byClick ? " by-click" : "")")
        state.chosen = byClick ? id : nil
        state.fromIsland = nil
        autoCollapse?.invalidate(); autoCollapse = nil
        seen.markSeen(s)
        if state.expanded {
            holdExpandedHeight(force: force)
            withAnimation(Self.moveSpring) { state.pinned = id }
            morph(to: targetShapeSize(expanded: true), .move)
        } else {
            state.pinned = id
            setExpanded(true, reason: "pill")
        }
    }

    /// 不需要你注意的事件（许愿柳：撤回）：两翼的内容由活动自己换（「已撤回」只停几秒，来源程序到时重写）。
    /// 登记了 dismissExpandedAfter 且正展开着：停这么久再收（许愿柳：「你撤回了这一轮」停 1.8 秒）。
    private func event(_ type: String, dismissAfter: Double?, pinning id: String) {
        if PresentDemo.seconds != nil && !PresentDemo.passive { demoLog("ignored event \(type)"); return }
        demoLog("event \(type)")
        if state.expanded { state.pinned = id }
        layout(animated: true)
        guard let delay = dismissAfter, state.expanded, !state.popover else { return }
        autoCollapse?.invalidate()
        autoCollapse = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.setExpanded(false, reason: "withdraw") }
        }
    }

    /// 精简版被鼠标停住：长成完整的悬停面板。
    private func promoteCompact() {
        guard state.expanded, state.compact, !state.popover else { return }
        demoLog("compact→full")
        state.expandedFloor = 0
        state.pillAnchorWidth = state.shapeWidth
        withAnimation(Self.openWidth) { state.compact = false }
        morph(to: targetShapeSize(expanded: true), .open)
    }

    private func setExpanded(_ on: Bool, reason: String) {
        guard state.expanded != on else { return }
        state.expandedFloor = 0
        if !on { state.compact = false }
        // 每次展开/收回都记原因 —— 真实截图里「该展开的时候是收起的」，不记原因就只能猜。
        demoLog("expanded=\(on) reason=\(reason)")
        hoverIntent?.cancel()
        if !on { afterCollapse(pin: state.pinned) }
        if on, state.dodge > 0 || dodgeTarget > 0 {          // 展开就回到刘海：面板从刘海长出来
            dodgeTrack = nil; dodgeTarget = 0
            withAnimation(Self.openHeight) { state.dodge = 0; state.dodgeCorner = 0 }
        }
        // 先量尺寸、再开动画。量一次要建一整棵展开态视图（实测约 30 ms）；放在动画开始之后，
        // 这段时间算进弹簧里，第一帧就跳一大截。
        let measureStart = Date()
        let target = targetShapeSize(expanded: on)
        demoLog("measure \(Int(Date().timeIntervalSince(measureStart) * 1000))ms natural=\(Int(state.naturalHeight)) shown=\(state.pinned.map { String($0.prefix(14)) } ?? "-")")
        if on { state.pillAnchorWidth = state.shapeWidth }
        withAnimation(on ? Self.openWidth : Self.closeHeight) {
            state.expanded = on
            state.hovering = false
        }
        morph(to: target, on ? .open : .close)
        // 展开时胶囊立刻吸回岛里；收起时等岛收稳（约 0.3 秒）再滴出去。
        updatePill(animated: true, delay: on ? 0 : 0.3, retract: on ? Self.pillMerge : Self.pillInSpring)
    }

    /// 收起动画走完之后：松开钉住（立刻松开的话，收起途中内容会跳成另一个会话），再轮到排队的下一个。
    private func afterCollapse(pin: String?) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(550))
            guard let self, !self.state.expanded, !self.state.popover else { return }
            if pin != nil, self.state.pinned == pin {
                self.state.pinned = nil
                self.state.chosen = nil
                self.state.fromIsland = nil
                self.layout(animated: true)
            }
            // A：收起之后不马上接着弹排队的，等冷却到期只弹最新一条。
            self.dequeueWhenCool()
        }
    }

    /// 松手之后那句话停多久。
    static let dropNoticeSeconds: TimeInterval = 8

    /// 拖着东西进出刘海（候选 B）：两翼长出来写「登记稿件 / 松手 → 名字」，离开就收。展开态与面板不接拖放。
    private func dropHover(_ inside: Bool) {
        guard !state.popover, !state.expanded, state.dropTarget != inside else { return }
        state.dropTarget = inside
        layout(animated: true)
    }

    /// 松手：交给 Drop 判断收不收、写收件；两翼换成「交给名字 · 等回话」或拒收的理由，8 秒后收。
    private func dropped(_ urls: [URL]) {
        state.dropTarget = false
        let outcomes = Drop.receive(urls: urls, registry: store.registry, paths: store.paths)
        guard let first = outcomes.first else { layout(animated: true); return }
        demoLog("drop \(first.kind == .handed ? "handed" : "refused") \(first.producer ?? "-") \(first.reason)")
        state.dropNotice = .init(text: first.kind == .handed ? L("交给\(first.name)", "To \(first.name)") : first.reason,
                                 producer: first.producer, tone: first.kind == .handed ? .white55 : .orange)
        layout(animated: true)
        dropNoticeTimer?.invalidate()
        dropNoticeTimer = Timer.scheduledTimer(withTimeInterval: Self.dropNoticeSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.state.dropNotice = nil
                self.layout(animated: true)
            }
        }
    }

    /// 演示：拖放（候选 B 的实拍）：先按「拖着悬停」画 1.5 秒，再按松了手画。
    public func presentDrop(_ url: URL) {
        dropHover(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.dropped([url]) }
    }

    /// 演示：悬停胶囊停稳之后的结果（分镜 ㉞ 的实拍；真实悬停在演示里被忽略）。
    public func presentPillOpen() {
        // 第五版：「胶囊」就是稿件小岛，悬停它展开的是小岛上那份稿件（演示宿主不收真实悬停，拿这个开关拍）。
        guard let other = Detached.manuscript(store.activities, primary: Ordering.pair(store.activities, seen, pinned: state.pinned).primary)
        else { demoLog("pill-open: no island"); return }
        demoLog("pill-open \(other.id.prefix(8))")
        switchTo(other.id, force: true)
        state.fromIsland = other.id
    }

    /// 演示：翻到第 n 页（候选 E 的实拍；真实悬停在演示里被忽略）。
    public func presentPage(_ n: Int) {
        guard let f = Ordering.pair(store.activities, seen, pinned: state.pinned).primary else { return }
        demoLog("page \(n) of \(f.id.prefix(8))")
        withAnimation(.easeOut(duration: 0.2)) { state.page = n; state.pageOf = f.id }
    }

    /// 演示：⌥+点撤下（候选 C 的实拍）。
    public func presentDismiss() { dismissShown() }

    /// ⌥+点一下：看过，撤下（候选 C，作者 09-21 按默认）。不是关闭：面板里还在；标签按 labelUntilSeen 缩回，
    /// 主项按规则换成下一个没看过的。
    private func dismissShown() {
        guard !state.popover else { return }
        guard let f = Ordering.pair(store.activities, seen, pinned: state.pinned).primary else { return }
        demoLog("seen-by-click \(f.id.prefix(8))")
        seen.markSeen(f)
        if state.expanded { setExpanded(false, reason: "option-click") } else { layout(animated: true) }
    }

    /// 点击：灵动岛再长大一档变成面板。不是另开窗口——用户实测原来的标准窗口「跳脱」。
    private func openDetail() {
        if case .window(let id) = Self.clickTarget(expanded: state.expanded, popover: state.popover,
                                                   pinned: state.pinned, fromIsland: state.fromIsland) {
            demoLog("island-card click → window \(id.prefix(14))")
            openWindow(id, reason: "island-window")
            return
        }
        togglePopover()
    }

    /// 开窗口并选中这一件：收起展开的卡，标成看过。
    private func openWindow(_ id: String, reason: String) {
        autoCollapse?.invalidate(); autoCollapse = nil
        if let h = store.activities.first(where: { $0.id == id }) { seen.markSeen(h) }
        setExpanded(false, reason: reason)
        lintelWindow.show(select: id)
    }

    enum ClickTarget: Equatable { case popover, window(String) }

    /// 点展开的卡开什么。悬停稿件小岛 0.3 秒它就并进主岛展开（分镜 ㉞），小岛本身点不到了；
    /// 这时卡上显示的就是小岛那份稿件，点它按小岛的设计开窗口并选中它，其余照旧开弹出框。
    static func clickTarget(expanded: Bool, popover: Bool, pinned: String?, fromIsland: String?) -> ClickTarget {
        guard expanded, !popover, let id = fromIsland, id == pinned else { return .popover }
        return .window(id)
    }

    // MARK: 弹出框（第五版，分镜 ①⓪②）

    private let pop = ConversationPopover()
    private lazy var lintelWindow = LintelWindow(store: store)

    /// 弹出框拖出来与「在窗口中打开」都进同一个窗口（分镜 ①⓪③）；点稿件小岛也进它，侧栏选中那份稿件。
    private func wireWindow() {
        pop.detachWindow = { [weak self] id in self?.lintelWindow.detachable(select: id) }
        pop.didDetach = { [weak self] id in self?.lintelWindow.didDetach(select: id) }
        pop.onOpenWindow = { [weak self] id in self?.lintelWindow.show(select: id) }
        pop.windowVisible = { [weak self] in self?.lintelWindow.isVisible ?? false }
        pop.ownDragged = { [weak self] id, p in self?.lintelWindow.grab(select: id, at: p) }
        pop.ownMoved = { [weak self] p in self?.lintelWindow.follow(p) }
        pop.ownEnded = { [weak self] in self?.lintelWindow.release() }
    }

    public func presentWindow(select prefix: String?, tab: String?) {
        let xs = store.activities
        let id = prefix.flatMap { p in xs.first { $0.id.hasPrefix(p) }?.id } ?? PopoverScope.conversations(xs).first?.id
        guard let id else { return }
        lintelWindow.show(select: id)
        if let tab, let t = WindowTab(rawValue: tab) { lintelWindow.select(tab: t) }
    }

    /// 弹出框说「你钉住的」只认你亲手点选、而且还在显示的那一场。悬停展开、悬停小岛、到达闪现都会改 pinned，
    /// 原来直接拿 pinned 算原因，从悬停卡点开几乎总标「你钉住的」（09-28 交互测试第 15 条）。
    static func chosenPin(pinned: String?, chosen: String?) -> String? {
        guard let chosen, chosen == pinned else { return nil }
        return chosen
    }

    enum PopoverTarget: Equatable { case conversation(Hosted), window(String), none }

    /// 点刘海开什么。弹出框只讲一场对话：主位是对话就是它；主位是嵌着的稿件就是它所在的对话；都不是就最近的对话。
    /// 一场开着的对话都没有、主位是稿件（10-06：夜里对话全关了，只剩写作循环的稿件），弹出框没有可讲的；
    /// 先前在这里静默返回，点几次都没反应。改照点稿件小岛的设计：开窗口并选中这份稿件。
    static func popoverTarget(primary: Hosted?, in xs: [Hosted]) -> PopoverTarget {
        if let conv = primary.flatMap({ p in p.activity.ring == nil ? p : Ordering.parent(of: p, in: xs) }) ?? PopoverScope.conversations(xs).first {
            return .conversation(conv)
        }
        if let p = primary { return .window(p.id) }
        return .none
    }

    /// 点刘海：收起悬停卡，从收起态的刘海弹出一个指着它的弹出框；再点一次关掉。
    private func togglePopover(draft: Bool = false) {
        if pop.isShown { pop.close(); return }
        // 弹出框开着时点刘海：系统先按「点外面」把它关掉，这次点击随后又到这里——刚关的不再打开，点刘海就是关。
        if let t = pop.closedAt, Date().timeIntervalSince(t) < 0.3 { return }
        guard let view = panel.contentView else { return }
        let xs = store.activities
        let primary = demoPinned.flatMap { id in xs.first { $0.id == id } } ?? Ordering.pair(xs, seen, pinned: state.pinned).primary
        let conv: Hosted
        switch Self.popoverTarget(primary: primary, in: xs) {
        case .conversation(let c): conv = c
        case .window(let id):
            demoLog("popover: no open conversation → window \(id.prefix(14))")
            hoverIntent?.cancel()
            openWindow(id, reason: "no-conversation-window")
            return
        case .none:
            demoLog("popover: nothing to open")
            return
        }
        // 为什么是这一场：下面一行就把全部标成看过，原因要先算。
        let why = primary.flatMap { Ordering.reason($0, in: xs, seen, pinned: Self.chosenPin(pinned: state.pinned, chosen: state.chosen)) }
        autoCollapse?.invalidate(); autoCollapse = nil
        hoverIntent?.cancel()
        for s in xs { seen.markSeen(s) }
        if state.expanded { setExpanded(false, reason: "popover") }
        state.popover = true
        // 锚在收起态刘海的矩形上（探针：悬停卡开着时锚点会跟着卡走）。
        let collapsed = targetShapeSize(expanded: false)
        let rect = NSRect(x: view.bounds.midX - collapsed.width / 2, y: 0, width: collapsed.width, height: notchGeometry().height)
        demoLog("popover conv=\(conv.id.prefix(14)) draft=\(draft) why=\(why?.rawValue ?? "-")")
        pop.onClosed = { [weak self] in
            self?.state.popover = false
            self?.demoLog("popover closed")
            self?.layout(animated: true)
        }
        wireWindow()
        pop.show(store: store, focus: conv.id, tab: draft ? .draft : .list, reason: why, relativeTo: rect, of: view)
    }

    public func presentPopover(draft: Bool) { togglePopover(draft: draft) }

    // MARK: 菜单栏让路

    /// 让路计时器此刻的频率。
    private var dodgeFast = true

    private func startDodgeWatch(fast: Bool = true) {
        // 只读鼠标位置和窗口列表，不装全局事件监听，不要辅助功能权限。每秒 60 次：菜单栏滑出只有约 0.1 秒，
        // 先前 0.1 秒才看一次，光是发现就可能晚一整段动画。读窗口列表比读鼠标贵，只在碰到顶边、或让路中鼠标离开带子时读。
        // 收起、缩回刘海、什么都没画、也没在让路时没有东西会挡住菜单栏，降到每秒 10 次，只用来发现「两翼又长出来了」（负担报告 2026-09-19）。
        dodgeTimer?.invalidate()
        dodgeFast = fast
        let t = Timer(timeInterval: fast ? 1.0 / 60 : 1.0 / 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.dodgeTick() }
        }
        t.tolerance = fast ? 0.004 : 0.02
        RunLoop.main.add(t, forMode: .common)
        dodgeTimer = t
    }

    private func dodgeTick() {
        stepDodge()
        // 演示与录素材时不跟真鼠标走，和悬停一样。
        if PresentDemo.seconds != nil && (!PresentDemo.passive || Backdrop.isOn) { return }
        releaseExpandedFloor()
        guard let s = screen() else { return }
        let g = notchGeometry()
        // 收起态、而且两翼或胶囊画着东西才会挡：缩回刘海时形状和物理刘海一样宽。
        // 挂在刘海下方让路（别的刘海 app 在跑）时本来就在菜单栏下面，不用再让。
        let active = !yielding && !state.expanded && !state.popover && (state.shapeWidth > g.width + 1 || state.pillWidth > 0)
        let fast = active || state.expanded || state.popover || state.hovering || dodgeTarget != 0 || dodgeTrack != nil
        if fast != dodgeFast { startDodgeWatch(fast: fast) }
        let band = DodgeRule.band(screen: s.frame, height: g.height)
        let p = NSEvent.mouseLocation
        if dodgeTarget == 0 {
            var island = shapeScreenRect(ignoringDodge: true)
            if state.pillWidth > 0 {
                island.size.width += Self.pillGap + state.pillWidth + (state.pillHover ? Self.pillPreview : 0)
            }
            guard DodgeRule.wantsMenuBarCheck(active: active, pointer: p, band: band, island: island) else { return }
            let bar = Self.menuBarWindow()
            if DodgeRule.shouldStart(menuBarY: bar.y) { setDodge(true, bar: bar) }
        } else {
            let inBand = DodgeRule.inBand(p, band)
            let bar: (y: CGFloat?, height: CGFloat, popUp: Bool) = active && !inBand ? Self.menuBarWindow() : (0, 0, false)
            if DodgeRule.shouldEnd(active: active, pointerInBand: inBand, menuBarY: bar.y, popUpOpen: bar.popUp) { setDodge(false, bar: bar) }
        }
    }

    private func setDodge(_ on: Bool, bar: (y: CGFloat?, height: CGFloat, popUp: Bool)? = nil) {
        let target: CGFloat = on ? menuBarHeight() : 0
        guard dodgeTarget != target else { return }
        dodgeTarget = target
        demoLog("dodge=\(on)")
        if on {
            state.dodgeDepth = target
            withAnimation(Self.dodgeCornerOut) { state.dodgeCorner = 1 }
        }
        // 发现时菜单栏已经走了一截：岛先追到它此刻的位置，剩下的再按曲线走（见 DodgeRule.catchUp）。
        let from = DodgeRule.catchUp(current: state.dodge, depth: state.dodgeDepth, barY: bar?.y, barHeight: bar?.height ?? 0, down: on)
        dodgeTrack = DodgeTrack(from: from, to: target, start: CACurrentMediaTime(), down: on)
        stepDodge()
    }

    /// 推进一帧：位置由这里每帧直接写入，不交给 SwiftUI 的动画插值。
    /// 插值进行中，`TimelineView` 驱动的计时文字每秒刷新时会直接排到终点的位置——回位时胶囊里的「3:24」先跳到顶上、
    /// 左翼的「6:06」被岛的形状裁掉，和岛不同步（2026-09-13 录屏逐帧，用户报告计时数字在弹出、收回时和岛不同步）。
    /// 每帧写实际位置，画面里就没有「终点」可跳。时长按剩余距离折算：半路反向时不会慢半拍。
    private func stepDodge() {
        guard let tr = dodgeTrack else { return }
        let full = tr.down ? DodgeRule.downDuration : DodgeRule.upDuration
        let duration = full * Double(abs(tr.to - tr.from) / max(state.dodgeDepth, 1))
        let p = duration > 0 ? (CACurrentMediaTime() - tr.start) / duration : 1
        let value = p >= 1 ? tr.to : tr.from + (tr.to - tr.from) * CGFloat(DodgeRule.eased(p, down: tr.down))
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { state.dodge = value }
        guard p >= 1 else { return }
        dodgeTrack = nil
        if tr.to == 0 {
            // 两端的凹肩等主体贴回屏幕上沿再长；边走边长会先在半空冒出两只角。
            withAnimation(Self.dodgeCornerIn) { state.dodgeCorner = 0 }
        }
    }

    /// 菜单栏的高度。让路时灵动岛正好挂在菜单栏底边下、凹肩接住它——先前多让了 6pt，用户看到一条缝（2026-09-13）。
    /// 菜单栏自动隐藏时 visibleFrame 仍然扣掉菜单栏那一条（这台机器 28pt）；取不到就按刘海高度。
    private func menuBarHeight() -> CGFloat {
        guard let s = screen() else { return notchGeometry().height }
        let inset = s.frame.maxY - s.visibleFrame.maxY
        return inset > 0 ? inset : notchGeometry().height
    }

    /// 菜单栏窗口此刻在哪（y：0 = 完全出来，负数 = 正在滑出或收回，nil = 不在屏幕上），以及有没有下拉菜单开着。
    /// 一次读窗口列表两样都拿到。认菜单栏靠层级（mainMenu = 24）、属于 Window Server、宽度够宽——
    /// 窗口名「Menubar」要屏幕录制权限才读得到，这个 app 不要那个权限；层级、所属进程、位置不需要。
    static func menuBarWindow() -> (y: CGFloat?, height: CGFloat, popUp: Bool) {
        let popUpLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let barLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        let info = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        var y: CGFloat? = nil
        var height: CGFloat = 0
        var popUp = false
        for w in info {
            let layer = w[kCGWindowLayer as String] as? Int
            if layer == popUpLevel { popUp = true }
            guard layer == barLevel, (w[kCGWindowOwnerName as String] as? String) == "Window Server",
                  let b = w[kCGWindowBounds as String] as? [String: Any],
                  let by = (b["Y"] as? NSNumber)?.doubleValue, let bw = (b["Width"] as? NSNumber)?.doubleValue, bw >= 600
            else { continue }
            y = max(y ?? -.infinity, CGFloat(by))
            height = CGFloat((b["Height"] as? NSNumber)?.doubleValue ?? 0)
        }
        return (y, height, popUp)
    }

    // MARK: 给 --present 用

    /// 演示用：直接打开点击后的面板。
    public func presentDetail() { openDetail() }

    /// 演示用：走真实悬停路径（先鼓一下、hoverDelay 后展开；移开后收起），不看鼠标位置。
    public func presentHover(_ inside: Bool) { hoverBody(inside, force: true) }

    /// 演示用：让路与复原（录下移的样子，不依赖真鼠标）。
    public func presentDodge(_ on: Bool) { setDodge(on) }

    /// 演示用：像写出理解那一刻一样主动弹出（精简版）。
    public func presentFlash() {
        store.reload()
        if let f = demoPinned ?? Ordering.pair(store.activities, seen, pinned: nil).primary?.id { flash(pinning: f, reason: "present-flash") }
    }

    /// 演示用：把某个活动钉成主项（按 id 前缀），好在真实家目录里复现某一张卡（09-21 作者：从悬浮卡点进去面板整块黑）。
    private var demoPinned: String?
    public func presentPin(_ prefix: String) {
        guard let id = store.activities.first(where: { $0.id.hasPrefix(prefix) })?.id else { demoLog("pin skipped: no \(prefix)"); return }
        demoPinned = id
        state.pinned = id
        demoLog("pin \(id.prefix(8))")
        layout(animated: false)
    }

    /// 演示用：翻到下一个在跑的会话，等于点悬停面板底部那一行。
    public func presentFlip() {
        let current = Ordering.pair(store.activities, seen, pinned: state.pinned).primary
        guard let next = Ordering.flipTarget(store.activities, after: current) else { demoLog("flip skipped: no next"); return }
        demoLog("flip → \(next.id.prefix(8)) \(next.activity.group?.name ?? "") \(next.activity.ears?.phase ?? "")")
        switchTo(next.id, force: true)
    }

    public func presentExpanded() {
        store.reload()
        // 取消任何待执行的自动收回：否则演示期间恰好有一轮开始，那 6 秒的闪现计时器
        // 会在演示展开之后把它收回去。
        autoCollapse?.invalidate()
        autoCollapse = nil
        if let f = Ordering.pair(store.activities, seen, pinned: demoPinned).primary { state.pinned = f.id }
        setExpanded(true, reason: "present")
    }

    /// 演示用：收起（胶囊随后滴出去）。
    public func presentCollapse() { setExpanded(false, reason: "present") }

    /// 演示用：模拟鼠标停在胶囊上 / 离开。
    public func presentPillHover(_ on: Bool) {
        guard state.pillWidth > 0 else { demoLog("pill hover skipped: no pill"); return }
        demoLog("pill hover=\(on)")
        withAnimation(Self.pillHoverSpring) { state.pillHover = on }
    }

    /// 演示用：模拟悬停鼓起 / 复原（不展开）。
    public func presentHoverBump(_ on: Bool) {
        demoLog("hover bump=\(on)")
        withAnimation(Self.hoverSpring) { state.hovering = on }
        morph(to: targetShapeSize(expanded: false), .hover)
    }

    /// 已知刘海类 app 在跑没有。按名字与 bundle id 的启发式：宁可误判成「有」而让路，
    /// 也不要两块面板叠在同一个矩形里抢鼠标。
    public static func otherNotchAppRunning() -> Bool {
        let needles = ["notch", "alcove", "dynamiclake", "mediamate", "dynamic island"]
        return NSWorkspace.shared.runningApplications.contains { app in
            guard app.processIdentifier != getpid() else { return false }
            let hay = ((app.bundleIdentifier ?? "") + " " + (app.localizedName ?? "")).lowercased()
            return needles.contains { hay.contains($0) }
        }
    }
}
