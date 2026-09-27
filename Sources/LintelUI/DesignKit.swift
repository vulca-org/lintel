import AppKit
import LintelCore
import SwiftUI

// 从许愿柳 f4d6690 `UI/DesignKit.swift` 搬来的界面件。画法不变；原来直接读 SessionState / ClaudeStatus 的地方，改成读活动字段。

/// Apple 风格的界面件：一条对齐线、4pt 间距网格、同心圆角、数字用 SF 的等宽数字。
public enum Ink {
    /// 打开「增强对比度」时各级字再亮一档（HIG Color：自定义颜色要给 increased contrast 的变体）。启动时读一次。
    static let moreContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    public static let primary = Color.white.opacity(0.92)
    public static let secondary = Color.white.opacity(moreContrast ? 0.72 : 0.6)
    /// 最淡的一级字。HIG Accessibility 按 WCAG AA：17pt 以下的字至少 4.5:1。原来 36% 白在黑底上只有 3.13:1，
    /// 50% 是 5.28:1（09-24 grill）。
    public static let tertiary = Color.white.opacity(moreContrast ? 0.62 : 0.5)
    /// 只给填充与描边（以后的暗格、空槽）；20% 白是 1.66:1，不能拿来写字。
    public static let quaternary = Color.white.opacity(0.2)
    public static let fill = Color.white.opacity(0.07)
    public static let separator = Color.white.opacity(0.1)
    public static let hair: CGFloat = 0.5
    /// 等你做选择的强调蓝（许愿柳 `ChoiceCard.accent`）：橙色是「读偏了」、红色是「坏了」，「轮到你了」不是任何一种错误。
    /// 09-24 grill 起用系统青（窗口定死 darkAqua，取暗色值 100/210/255，与原来手写的 0.45/0.78/1.0 几乎一样）：
    /// 系统色自带增强对比度的变体（HIG Color / Accessibility）；不用 systemBlue，那是 macOS 可点控件的强调色，
    /// 拿来写不能点的「等你」会被读成能点（HIG Color：同一种颜色别表示两件事）。
    public static let accent = Color(nsColor: .systemCyan)

    public static func number(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

/// 第五版（分镜 ⑨⑨–①⓪④，作者 09-24）：弹出框与窗口跟随系统深浅，刘海本体仍是深色。颜色按外观取值，刘海定死 darkAqua，自然取深色那一份。
/// 浅色下青、橙用 Apple 增强对比度的那一档（#0071a4、#c93400）：标准的 systemCyan / systemOrange 在白底上不到 3:1；
/// 深色下靛蓝用 #7d7aff：systemIndigo 深色值 #5e5ce6 在黑底上只有 3.6:1（HIG Accessibility，17pt 以下 4.5:1）。
/// 这几种颜色只在下面 `Surface` 定死的不透明底上写字——系统材质半透明，背后是什么就变成什么，对比度量不死。
public enum Tone {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { a in
            let hex = a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
    }
    /// 等你（轮到你了）。
    public static let cyan = dynamic(light: 0x0071a4, dark: 0x64d2ff)
    /// 过期、要重跑、未就绪。
    public static let orange = dynamic(light: 0xc93400, dark: 0xff9f0a)
    /// 写作循环的身份色。
    public static let indigo = dynamic(light: 0x5e5ce6, dark: 0x7d7aff)
    /// 正文、次要字（「还有 5 件」、三栏的小标签）。系统的 secondaryLabel 在浅灰底上不到 4.5:1，这里取定值。
    public static let primary = dynamic(light: 0x1d1d1f, dark: 0xf5f5f7)
    public static let secondary = dynamic(light: 0x636366, dark: 0xaeaeb2)
}

/// 弹出框与窗口里写字的底（不透明）：底是定的，对比度才测得出来。
public enum Surface {
    /// 弹出框、窗口正文区的底。
    public static let base = Tone.dynamic(light: 0xf5f5f7, dark: 0x2c2c2e)
    /// 行的分组底（清单几行一组）。
    public static let group = Tone.dynamic(light: 0xffffff, dark: 0x3a3a3c)
    /// 航班卡的底：浅色白，深色比外框更深（分镜 ①⓪② 深色）。
    public static let card = Tone.dynamic(light: 0xffffff, dark: 0x161618)
    /// 窗口侧栏的底。
    public static let sidebar = Tone.dynamic(light: 0xe8e8ed, dark: 0x232325)
}

extension Swatch {
    /// 调色板到颜色。有系统色的一律用系统色（窗口是 darkAqua，取暗色值，并跟着增强对比度变；09-24 grill）；
    /// 其余数值逐个取自许愿柳原来写在视图里的颜色。
    public var color: Color {
        switch self {
        case .inkPrimary: Ink.primary
        case .inkSecondary: Ink.secondary
        case .inkTertiary: Ink.tertiary
        case .inkQuaternary: Ink.quaternary
        case .white: Color.white
        case .white85: Color.white.opacity(0.85)
        case .white70: Color.white.opacity(0.7)
        case .white55: Color.white.opacity(0.55)
        case .white50: Color.white.opacity(0.5)
        case .white45: Color.white.opacity(0.45)
        case .white35: Color.white.opacity(0.35)
        case .white28: Color.white.opacity(0.28)
        case .white25: Color.white.opacity(0.25)
        case .white18: Color.white.opacity(0.18)
        case .orange: Color(nsColor: .systemOrange)
        case .red: Color(nsColor: .systemRed)
        case .coral: Color(red: 1, green: 0.42, blue: 0.36)
        case .blue: Ink.accent
        case .slate: Color(red: 0.55, green: 0.62, blue: 0.72)
        case .purple: Color(nsColor: .systemPurple)
        case .mint: Color(nsColor: .systemMint)
        case .deepBlue: Color(nsColor: .systemBlue)
        case .indigo: Color(nsColor: .systemIndigo)                      // 写作循环的身份色（作者 09-18）
        case .gray: Color(white: 0.5)
        }
    }
}

/// 数据条里的一格：上面小号标签，下面数值（可带一个小图形）。
struct StatCell<Accessory: View>: View {
    let label: String
    let value: String
    var tint: Color = Ink.primary
    /// 有悬停说明：标签带虚线下划线（同总览标题，分镜 ㊿）。
    var dotted = false
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Ink.tertiary)
                .underline(dotted, pattern: .dot, color: Ink.quaternary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 6) {
                Text(value)
                    .font(Ink.number(12.5, .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)      // 数先站稳，配件（量表 / 点点 / 走势线）挤它不动（09-21 实拍「49%」被截成「4…」）
                accessory()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension StatCell where Accessory == EmptyView {
    init(label: String, value: String, tint: Color = Ink.primary, dotted: Bool = false) {
        self.init(label: label, value: value, tint: tint, dotted: dotted) { EmptyView() }
    }
}

/// 各块按从上到下的次序淡入、下移 4pt 到位。不用模糊：模糊渐显时行与行糊成一片。
struct Reveal: ViewModifier {
    let order: Int
    let shown: Bool
    let after: Double

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : -4)
            .animation(.easeOut(duration: 0.2).delay(after + 0.04 * Double(order)), value: shown)
    }
}

extension View {
    func reveal(_ order: Int, _ shown: Bool, after: Double = 0.1) -> some View {
        modifier(Reveal(order: order, shown: shown, after: after))
    }
}

/// 外圈弧与数据条的颜色：像电量，剩 20% 变橙、10% 变红（许愿柳 `ClaudeStatus.level` 的阈值）。
enum Gauge {
    static func color(remaining: Double) -> Color {
        if remaining <= 0.1 { return .red }
        if remaining <= 0.2 { return .orange }
        return Ink.primary
    }

    /// 圆心扇形有多满：最近一次写入越近越满（10 秒 / 1 分 / 5 分）。
    static func liveness(secondsSinceLastWrite s: TimeInterval) -> Double {
        if s <= 10 { return 1 }
        if s <= 60 { return 2.0 / 3.0 }
        if s <= 300 { return 1.0 / 3.0 }
        return 0
    }
}

/// iPhone Duo 合一状态图标的几何（量自 dev.to「One icon, three signals」封面动图）。
enum DuoGeometry {
    static let arcSpan: Double = 230
    static let dotAngles: [Double] = [30, 10, -10, -30]
    static let lineRatio: CGFloat = 0.058
    static let dotSizeRatio: CGFloat = 0.082
    static let symbolRatio: CGFloat = 0.42
    static var arcStartDegrees: Double { 90 + (360 - arcSpan) / 2 }
    /// 底部四点亮几个：同一来源程序在跑的活动数，满 4 = 4 个及以上。
    static func litDots(running: Int) -> Int { min(4, max(0, running)) }
}

/// 左翼的合一状态图标：外圈弧 = 还剩多少，底部四点 = 几个在跑，圆心 = 状态符号。
struct DuoGlyph: View {
    var ringRemaining: Double?
    var lastWriteAt: Date?
    let center: Activity.Center
    var sessions: Int = 1
    var size: CGFloat = 18
    var summary: String? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { ctx in
            let since = lastWriteAt.map { ctx.date.timeIntervalSince($0) } ?? .infinity
            glyph(live: Gauge.liveness(secondsSinceLastWrite: since))
        }
        .frame(width: size, height: size)
        .help(fullSummary)
        .accessibilityElement()
        .accessibilityLabel(fullSummary)
    }

    private func glyph(live: Double) -> some View {
        let lw = max(1.1, size * DuoGeometry.lineRatio)
        let dot = max(1.6, size * DuoGeometry.dotSizeRatio)
        let r = size / 2 - dot / 2
        let span = DuoGeometry.arcSpan / 360
        let lit = DuoGeometry.litDots(running: sessions)
        let symbol = Self.symbol(center, live: live)
        return ZStack {
            Circle()
                .trim(from: 0, to: span)
                .stroke(Ink.quaternary, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .rotationEffect(.degrees(DuoGeometry.arcStartDegrees))
                .frame(width: 2 * r, height: 2 * r)
            if let remaining = ringRemaining {
                Circle()
                    .trim(from: 0, to: span * max(0.03, remaining))
                    .stroke(Gauge.color(remaining: remaining), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .rotationEffect(.degrees(DuoGeometry.arcStartDegrees))
                    .frame(width: 2 * r, height: 2 * r)
            }
            ForEach(Array(DuoGeometry.dotAngles.enumerated()), id: \.offset) { i, a in
                let theta = (90 + a) * .pi / 180
                Circle()
                    .fill(i < lit ? Ink.primary : Ink.quaternary)
                    .frame(width: dot, height: dot)
                    .offset(x: r * CGFloat(cos(theta)), y: r * CGFloat(sin(theta)))
            }
            Image(systemName: symbol.name, variableValue: symbol.variable)
                .font(.system(size: size * DuoGeometry.symbolRatio, weight: .bold))
                .foregroundStyle(symbol.tint)
                .contentTransition(.symbolEffect(.replace))
                .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size)
    }

    static func symbol(_ c: Activity.Center, live: Double) -> (name: String, variable: Double?, tint: Color) {
        switch c {
        case .live: ("wifi", live, Ink.primary)
        case .waiting: ("questionmark", nil, Ink.accent)
        case .done: ("checkmark", nil, Ink.primary)
        case .flagged: ("exclamationmark", nil, .orange)
        case .broken: ("exclamationmark", nil, .red)
        case .withdrawn: ("arrow.uturn.backward", nil, Ink.secondary)
        case .idle: ("minus", nil, Ink.tertiary)
        // awt-loop 的两个：形状照它 spec 6.2 的 ◇ 与 ◌，不另造一套说法。
        case .superseded: ("diamond", nil, Ink.accent)
        case .assumed: ("circle.dotted", nil, Ink.tertiary)
        }
    }

    private var fullSummary: String {
        let running = L("\(sessions) 个会话在跑", "\(sessions) session\(sessions == 1 ? "" : "s") running")
        return [summary, running].compactMap { $0 }.joined(separator: " · ")
    }
}

/// 演示模式的标记。演示画的是造出来的内容，直接画在真屏幕上会被当成真的。
struct DemoMark: View {
    var compact = false

    var body: some View {
        if PresentDemo.seconds != nil, !Backdrop.isOn, compact {
            Circle().fill(Color.yellow).frame(width: 6, height: 6).help(L("演示数据", "Demo data"))
        } else if PresentDemo.seconds != nil, !Backdrop.isOn {
            Text(L("演示", "Demo"))
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(Color.yellow, in: Capsule())
                .foregroundStyle(Color.black)
                .fixedSize()
        }
    }
}

/// 数据条里的走势线（分镜 53，借写作循环的依据走势）：一点一轮、0…1、旧 → 新；顶上一条淡线是满；末点一个白点。
/// 用 Shape 画、不用 Canvas：Canvas 在面板里自己占一块图层，第一次打开面板要给它分配显示内存，
/// 09-21 真机上主线程卡在那一步等窗口服务器（采样：SharedSurfaceGroup::wait_for_allocations），面板整块黑。
struct Sparkline: View {
    let series: [Double]

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
            SparkLine(series: series).stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            SparkEnd(series: series).fill(Color.white)
        }
        .frame(width: 44, height: 14)
    }

    static func point(_ i: Int, _ v: Double, count n: Int, in r: CGRect) -> CGPoint {
        CGPoint(x: r.minX + 1 + (r.width - 2) * CGFloat(i) / CGFloat(max(1, n - 1)),
                y: r.maxY - 1 - (r.height - 2) * CGFloat(min(1, max(0, v))))
    }
}

private struct SparkLine: Shape {
    let series: [Double]
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard series.count >= 2 else { return p }
        for (i, v) in series.enumerated() {
            let q = Sparkline.point(i, v, count: series.count, in: r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        return p
    }
}

private struct SparkEnd: Shape {
    let series: [Double]
    func path(in r: CGRect) -> Path {
        guard let v = series.last, series.count >= 2 else { return Path() }
        let q = Sparkline.point(series.count - 1, v, count: series.count, in: r)
        return Path(ellipseIn: CGRect(x: q.x - 1.8, y: q.y - 1.8, width: 3.6, height: 3.6))
    }
}

/// 来源标记：写明这一项来自哪个来源程序（spec G4，名字取自登记，不取自活动内容）。
/// - 点击面板左耳：写全名（面板宽，放得下）。
/// - 展开态与精简卡左耳：只放登记里的识别字母，14pt 小圆标。先前放全名，英文「Wishing Willow」把工作区名整个挤没、
///   状态图标和右耳标签跟着右移，中文精简卡里工作区名也被挤成一个字母（2026-09-17 带标记那一轮逐像素比对抓到）。
/// - 收起态左翼与胶囊：只在刘海上同时有不止一个来源程序时画（`Ordering.multiSource`）。
///   原先一律不画，理由是「第一版只有一个来源」；作者 09-18 更正许愿柳与 AWT 平行接入后，这条理由不成立（L8 修订）。
/// `--no-source-mark` 只给比对截图用：先证明关掉标记时与许愿柳逐像素一致，再证明打开后差异只落在声明的区域里。
struct SourceMark: View {
    let name: String

    nonisolated(unsafe) static var enabled = !CommandLine.arguments.contains("--no-source-mark")

    var body: some View {
        if Self.enabled {
            Text(name)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(Color.white.opacity(0.1), in: Capsule())
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// 一个来源画在刘海上的身份：登记里的识别字母与名字，加上（登记了才有的）形状与身份色。
struct SourceRef: Equatable {
    let initial: String
    let name: String
    let mark: Registry.Mark?
    var producer = ""
}

func sourceRef(_ registry: Registry?, _ producer: String) -> SourceRef {
    let p = registry?.producers[producer]
    return SourceRef(initial: p?.initial ?? String(producer.prefix(1)).uppercased(), name: p?.name ?? producer, mark: p?.mark,
                     producer: producer)
}

/// 括号标志（几何在 `Marks.swift`）：中间是网格上的状态符号；`center` 为 nil 时画来源标记的横 5（胶囊、耳朵、面板列表）。
/// 状态符号不再用系统图标（作者 2026-09-22 B-5 第 2 项）：✓ ! ? 和信号跟括号不是同一套几何。
struct BracketGlyph: View {
    var size: CGFloat = 14
    var tint: Color = Ink.secondary
    var center: Activity.Center? = nil
    var symbolTint: Color = Ink.primary
    /// 状态刚变时弹一下（原来靠系统图标的 bounce，画成形状之后自己做）。
    var bounceAt: Date? = nil

    var body: some View {
        ZStack {
            BracketShape(small: BracketShape.isSmall(size)).stroke(tint, style: StrokeStyle(lineWidth: BracketShape.lineWidth(size), lineCap: .butt, lineJoin: .round))
            GridSymbolView(center: center ?? .idle, tint: center == nil ? tint : symbolTint, size: size)
                .id(center.map { "\($0)" } ?? "mark")
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
                .keyframeAnimator(initialValue: 1.0, trigger: bounceAt) { v, s in v.scaleEffect(s) } keyframes: { _ in
                    SpringKeyframe(1.35, duration: 0.14)
                    SpringKeyframe(1.0, duration: 0.3)
                }
        }
        .frame(width: size, height: size)
    }
}

struct SourceInitial: View {
    let ref: SourceRef

    var body: some View {
        if SourceMark.enabled {
            Group {
                if ref.mark?.shape == .bracket {
                    BracketGlyph(size: 14, tint: ref.mark?.tint?.color ?? Ink.secondary)
                } else if ref.producer == "willow" {
                    // 许愿柳：画出来的 W（小尺寸版），不用字体（B-5 第 4 项，sheet-9 的 B）。按来源认，不按首字母：
                    // 别的来源首字母是 W 也不该拿到许愿柳的标志（grill 09-22）。
                    WillowMark(size: 14)
                } else {
                    Text(String(ref.initial.prefix(1)))
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Ink.secondary)
                        .frame(width: 14, height: 14)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
            }
            .help(ref.name)
            .accessibilityLabel(ref.name)
            .fixedSize()
        }
    }
}
