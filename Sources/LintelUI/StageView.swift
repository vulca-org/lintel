import AppKit
import LintelCore
import SwiftUI
import UniformTypeIdentifiers

// 刘海舞台上的视图。从许愿柳 f4d6690 `UI/IslandView.swift` 搬来：
// IslandState → StageState、IslandView → StageView、PillAssembly / CompactWings / WingStatus / SessionPill 原名保留、
// IslandExpandedContent → ExpandedContent。画法、间距、动画逐行照搬；读 WillowStore / FocusRule 的地方换成读活动与 Ordering。

@MainActor
@Observable
public final class StageState {
    var expanded = false
    /// 黑色形状此刻的宽和高（含两侧凹肩），分开存，各走各的弹簧。
    var shapeWidth: CGFloat = 0
    var shapeHeight: CGFloat = 0
    var shapeSize: CGSize { CGSize(width: shapeWidth, height: shapeHeight) }
    /// 第五版：弹出框开着（分镜 ①⓪②）。开着时悬停不展开。
    var popover = false
    /// 展开期间钉住的活动（Hosted.id）：刘海此刻显示的那一场。悬停、到达闪现、点选都会写它。
    var pinned: String?
    /// 你亲手点选的那一场（点底部那一行、点胶囊）；悬停与闪现不算。弹出框的「你钉住的」只认它（09-28 交互测试第 15 条）。
    var chosen: String?
    /// 从稿件小岛悬停展开的那一份：这时点卡片 = 点小岛，开窗口并选中它（09-28 交互测试第 16 条）。
    var fromIsland: String?
    var pillWidth: CGFloat = 0
    var pillOut: CGFloat = 0
    var pillAnchorWidth: CGFloat = 0
    var pillHover = false
    var hovering = false
    var dodge: CGFloat = 0
    var dodgeDepth: CGFloat = 0
    var dodgeCorner: CGFloat = 0
    var expandedFloor: CGFloat = 0
    var layoutHeight: CGFloat = 0
    var compact = false
    var naturalHeight: CGFloat = 0
    /// 展开态翻到第几页、是哪个活动的（换了活动从第 0 页起）。候选 E。
    var page = 0
    var pageOf: String?
    /// 拖着东西悬停在刘海上（候选 B）；松手之后短暂的一句话。
    var dropTarget = false
    var dropNotice: DropNotice?
    /// 展开态内容比上限高：正文改成可滚动（作者 09-21：「悬浮窗口的时候可以上下滑动看改了什么」）。
    var contentTaller = false
    /// 卡底那一层（点点 + 翻页行）的高度，滚动区要给它让出来。
    var bottomHeight: CGFloat = 0

    struct DropNotice: Equatable {
        var text: String
        var producer: String?
        var tone: Swatch
    }

    public init() {}
}

/// 刘海本体：纯黑、顶边贴屏幕上沿、顶部两角凹肩、下方两角圆，和刘海连成一块。
struct StageView: View {
    /// 可滚的展开卡没有卡底那一层时，滚动区离卡片底边留这么多（卡片圆底角 24 的一半）。
    static let scrollBottomInset: CGFloat = NotchShape.open.bottom / 2
    /// 演示开关 `--scroll` 用；平时停在顶上。
    @State private var demoScroll = ScrollPosition(edge: .top)
    let store: ActivityStore
    let seen: SeenStore
    let state: StageState
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let stemWidth: CGFloat
    let onHover: (Bool) -> Void
    let onPillHover: (Bool) -> Void
    let onClick: () -> Void
    /// ⌥+点一下：看过，撤下（候选 C）。
    let onSeen: () -> Void
    /// 拖着东西进出刘海、松手（候选 B）。
    let onDropHover: (Bool) -> Void
    let onDrop: ([URL]) -> Void
    let onSwitch: (String) -> Void
    /// 第五版：点稿件小岛，打开窗口并在侧栏选中它（第 7 块）。
    var onOpenWindow: (String) -> Void = { _ in }

    private var open: Bool { state.expanded }
    private var radii: (top: CGFloat, bottom: CGFloat) { open ? NotchShape.open : NotchShape.closed }

    private static let quickOut = AnyTransition.asymmetric(
        insertion: .identity, removal: .opacity.animation(.easeOut(duration: 0.1)))

    var body: some View {
        let xs = store.activities
        let pair = Ordering.pair(xs, seen, pinned: state.pinned)
        let label = pair.primary.flatMap { Ordering.label($0, seen) }
        let right = pair.primary.flatMap { IslandText.right($0, label: label) }
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom,
                               drop: state.dodge, dropDepth: state.dodgeDepth, capsule: state.dodgeCorner, stemWidth: stemWidth)
        let hitShape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

        ZStack(alignment: .top) {
            // 第五版（分镜 ⑨⑨）：没嵌进对话的稿件是一颗脱开的小岛，括号里是要重跑几环。
            if state.pillWidth > 0, let other = Detached.manuscript(xs, primary: pair.primary), let ring = other.activity.ring {
                PillAssembly(islandWidth: state.shapeWidth, anchorWidth: open ? state.pillAnchorWidth : nil, liquid: !open,
                             pillOut: state.pillOut, pillExtra: 0,
                             pillWidth: state.pillWidth, pillHeight: notchHeight, notchHeight: notchHeight,
                             bottomRadius: NotchShape.closed.bottom, lift: state.dodge, liftDepth: state.dodgeDepth,
                             onTap: { onOpenWindow(other.id) }, onHover: onPillHover) {
                    ManuscriptIsland(ring: ring, name: other.activity.label?.text ?? other.activity.id)
                }
            }

            ZStack(alignment: .top) {
                // 缩回刘海时不能全透明：alpha 为 0 的像素鼠标直接穿过窗口，悬停永远到不了这里。2% 的黑盖在物理刘海上看不见。
                let dropping = state.dropTarget || state.dropNotice != nil
                shape.fill(Color.black.opacity(open || right != nil || state.hovering || dropping ? 1 : 0.02))

                if state.expanded {
                    // 第五版（分镜 ①⓪⓪ ①⓪①）：对话是最矮的两行加圆按钮，稿件是航班卡；按内容定高，不再统一 360、不翻页。
                    ExpandedV5(store: store, seen: seen, pinned: state.pinned, notchWidth: notchWidth, notchHeight: notchHeight,
                               compact: state.compact,
                               onOpen: onClick)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(Self.quickOut)
                } else if state.dropTarget || state.dropNotice != nil {
                    DropWings(store: store, state: state, notchWidth: notchWidth, height: notchHeight)
                        .padding(.horizontal, NotchShape.closed.top)
                        .transition(.opacity.animation(.easeOut(duration: 0.15)))
                } else if let f = pair.primary, let r = right {
                    CompactWingsV5(store: store, hosted: f, right: r, notchWidth: notchWidth, height: notchHeight)
                        .padding(.horizontal, NotchShape.closed.top)
                        .transition(.asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.22).delay(0.1)),
                                                removal: .opacity.animation(.easeOut(duration: 0.1))))
                }
            }
            .frame(width: state.shapeWidth, height: state.shapeHeight, alignment: .top)
            .clipShape(shape)
            .overlay { if open { shape.stroke(Color.white.opacity(0.08), lineWidth: 1) } }
            .shadow(color: .black.opacity(open ? 0.55 : 0), radius: 10, y: 4)
            .contentShape(hitShape)
            .onHover(perform: onHover)
            .onTapGesture {
                // ⌥+点 = 看过，撤下；不开面板（NotchDrop 的 option 键是删，我们的是撤下，面板里还在）。
                if NSApp.currentEvent?.modifierFlags.contains(.option) == true { onSeen() } else { onClick() }
            }
            // 候选 B：拖到刘海上。dropDestination 在主线程直接给解好的 URL；isTargeted 在拖进 / 拖出时各来一次。
            .dropDestination(for: URL.self) { urls, _ in
                onDrop(urls)
                return !urls.isEmpty
            } isTargeted: { inside in onDropHover(inside) }
        }
        .offset(y: state.dodge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

/// 拖放时的两翼（候选 B，分镜 ⑭ ⑮）：左翼来源标记 + 「登记稿件」，右翼「松手 → 名字」；松手后右翼换成「交给名字 · 等回话」。
struct DropWings: View {
    let store: ActivityStore
    let state: StageState
    let notchWidth: CGFloat
    let height: CGFloat

    var body: some View {
        let taker = Drop.taker(store.registry)
        let producer = state.dropNotice?.producer ?? taker?.id
        // 两翼各 ≤6 个汉字（与标签同一把尺）：松手后左翼「等回话」、右翼「交给名字」。
        let left = state.dropTarget ? L("登记稿件", "Register") : (state.dropNotice?.producer != nil ? L("等回话", "waiting") : "")
        let right = state.dropTarget
            ? (taker.map { L("松手 → \($0.producer.name)", "Drop → \($0.producer.name)") } ?? L("没有来源收目录", "No source takes folders"))
            : (state.dropNotice?.text ?? "")
        let tone = state.dropTarget ? Ink.primary : (state.dropNotice?.tone.color ?? Ink.secondary)
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Spacer(minLength: 0)
                if let producer { SourceInitial(ref: sourceRef(store.registry, producer)) }
                if !left.isEmpty {
                    Text(left).font(.system(size: 12, weight: .semibold)).foregroundStyle(state.dropTarget ? Ink.primary : Ink.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)

            Color.clear.frame(width: notchWidth)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(right).font(.system(size: 12, weight: .semibold)).foregroundStyle(tone).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: height)
    }

    /// 收起态两翼要多宽：按右翼那句话算（与 CompactWings 同一把尺）。
    static func label(_ state: StageState, registry: Registry?) -> String? {
        if state.dropTarget {
            return Drop.taker(registry).map { L("松手 → \($0.producer.name)", "Drop → \($0.producer.name)") } ?? L("没有来源收目录", "No source takes folders")
        }
        return state.dropNotice?.text
    }
}

/// 第二项的胶囊，连同它从岛里分离出来的那一段液体连桥（模糊 + 按不透明度截断）。
struct PillAssembly<Content: View>: View, @preconcurrency Animatable {
    var islandWidth: CGFloat
    let anchorWidth: CGFloat?
    let liquid: Bool
    var pillOut: CGFloat
    var pillExtra: CGFloat
    let pillWidth: CGFloat
    let pillHeight: CGFloat
    let notchHeight: CGFloat
    let bottomRadius: CGFloat
    var lift: CGFloat
    let liftDepth: CGFloat
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    let content: () -> Content

    init(islandWidth: CGFloat, anchorWidth: CGFloat? = nil, liquid: Bool = true, pillOut: CGFloat, pillExtra: CGFloat, pillWidth: CGFloat, pillHeight: CGFloat = StageController.pillHeight, notchHeight: CGFloat,
         bottomRadius: CGFloat, lift: CGFloat = 0, liftDepth: CGFloat = 0, onTap: @escaping () -> Void, onHover: @escaping (Bool) -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.lift = lift
        self.liftDepth = liftDepth
        self.islandWidth = islandWidth
        self.anchorWidth = anchorWidth
        self.liquid = liquid
        self.pillOut = pillOut
        self.pillExtra = pillExtra
        self.pillWidth = pillWidth
        self.pillHeight = pillHeight
        self.notchHeight = notchHeight
        self.bottomRadius = bottomRadius
        self.onTap = onTap
        self.onHover = onHover
        self.content = content
    }

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get { .init(islandWidth, .init(pillOut, .init(pillExtra, lift))) }
        set {
            islandWidth = newValue.first
            pillOut = newValue.second.first
            pillExtra = newValue.second.second.first
            lift = newValue.second.second.second
        }
    }

    var body: some View {
        GeometryReader { g in
            let w = pillWidth + pillExtra
            let h = pillHeight
            let mid = g.size.width / 2
            let base = anchorWidth ?? islandWidth
            let tucked = base / 2 - w / 2 - 8
            let rest = base / 2 + StageController.pillGap + w / 2
            let cx = mid + tucked + (rest - tucked) * pillOut
            let cy = StageController.dodgedPillCenterY(dodge: lift, depth: liftDepth, notchHeight: notchHeight, height: h)
            ZStack(alignment: .topLeading) {
                if liquid && pillOut > 0.02 && pillOut < 0.97 {
                    Canvas { ctx, size in
                        ctx.addFilter(.alphaThreshold(min: 0.5, color: .black))
                        ctx.addFilter(.blur(radius: 4))
                        ctx.drawLayer { layer in
                            let reach = max(0, 24 - lift)
                            let body = CGRect(x: mid - islandWidth / 2 + NotchShape.closed.top, y: -reach,
                                              width: max(0, islandWidth - 2 * NotchShape.closed.top), height: notchHeight + reach)
                            layer.fill(Path(roundedRect: body, cornerRadius: bottomRadius, style: .continuous), with: .color(.black))
                            layer.fill(Path(roundedRect: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h),
                                            cornerRadius: h / 2, style: .continuous), with: .color(.black))
                        }
                    }
                    .allowsHitTesting(false)
                }
                content()
                    .opacity(Double(max(0, min(1, liquid ? (pillOut - 0.45) / 0.4 : (pillOut - 0.8) / 0.2))))
                    .frame(width: w, height: h)
                    .background(Capsule().fill(Color.black))
                    .contentShape(Capsule())
                    .onTapGesture(perform: onTap)
                    .onHover(perform: onHover)
                    .position(x: cx, y: cy)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}
