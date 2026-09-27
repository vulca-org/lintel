import AppKit
import LintelCore
import LintelUI

/// 宿主：起活动存储与刘海舞台。`--present <秒>` 与各演示开关照许愿柳 f4d6690 `WishingWillowApp.swift` 的编排与时刻，
/// 这样同一个开关在两边拍出来的帧可以逐帧比。
enum Host {
    @MainActor
    static func run(arguments: [String]) {
        PresentDemo.logging = arguments.contains("--log")
        if let i = arguments.firstIndex(of: "--scroll"), i + 1 < arguments.count, let y = Double(arguments[i + 1]) {
            PresentDemo.scrollY = CGFloat(y)
        }
        if let i = arguments.firstIndex(of: "--appearance"), i + 1 < arguments.count {
            PresentDemo.appearance = arguments[i + 1] == "dark" ? .darkAqua : .aqua
        }
        if let i = arguments.firstIndex(of: "--present") {
            PresentDemo.seconds = i + 1 < arguments.count ? (Double(arguments[i + 1]) ?? 6) : 6
            PresentDemo.passive = arguments.contains("--passive")
        }
        let app = NSApplication.shared
        let delegate = HostDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class HostDelegate: NSObject, NSApplicationDelegate {
    private let store = ActivityStore(paths: LintelPaths.default())
    private var stage: StageController?
    private var backdrop: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        // 演示读的是造出来的活动，看过的记录不落盘：否则演示把样例标成已读，之后真实的看过记录被污染。
        let demo = PresentDemo.seconds != nil
        backdrop = Backdrop.show()
        let c = StageController(store: store, seen: demo ? SeenStore(ephemeral: true) : SeenStore(paths: store.paths))
        stage = c
        c.start()

        guard let hold = PresentDemo.seconds else { return }
        if !PresentDemo.passive {
            if let i = args.firstIndex(of: "--pin"), i + 1 < args.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { c.presentPin(args[i + 1]) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + hold / 2) {
                if args.contains("--flash-detail") {
                    // 黑面板的真实路径（09-21 日志）：声明到达自动弹紧凑闪现卡 → 悬停变全卡 → 点击开面板。
                    c.presentFlash()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { c.presentHover(true) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { c.presentDetail() }
                } else if args.contains("--detail-from-card") {
                    // 真实点击的路：展开卡开着再开面板（09-21 作者：从悬浮卡点进去面板整块黑，--detail 从收起态直开复现不了）。
                    c.presentExpanded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { c.presentDetail() }
                } else if args.contains("--window") {
                    let sel = args.firstIndex(of: "--window-select").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
                    let tab = args.firstIndex(of: "--window-tab").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
                    c.presentWindow(select: sel, tab: tab)
                } else if args.contains("--popover") {
                    c.presentPopover(draft: args.contains("--popover-draft"))
                } else if args.contains("--detail") {
                    c.presentDetail()
                } else if args.contains("--flash") {
                    c.presentFlash()
                    if args.contains("--flash-hover") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { c.presentHover(true) }
                    }
                } else if !args.contains("--still") && !args.contains("--popover") && !args.contains("--window") && !args.contains("--pill-cycle") && !args.contains("--hover-cycle") && !args.contains("--dodge-cycle") && !args.contains("--expand-cycles") {
                    c.presentExpanded()
                }
            }
            // 候选 E / C 的实拍：演示宿主忽略真实悬停与点击，所以翻页与「⌥+点撤下」各给一个开关。
            if let i = args.firstIndex(of: "--page"), i + 1 < args.count, let n = Int(args[i + 1]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + hold / 2 + 0.8) { c.presentPage(n) }
            }
            if let i = args.firstIndex(of: "--drop"), i + 1 < args.count {
                let url = URL(fileURLWithPath: args[i + 1])
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { c.presentDrop(url) }
            }
            if args.contains("--pill-open") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { c.presentPillOpen() }
            }
            if args.contains("--dismiss") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + hold / 2 - 1.0) { c.presentDismiss() }
            }
            if args.contains("--expand-then-detail") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + hold / 2 + 1.6) { c.presentDetail() }
            }
            if args.contains("--hover-cycle") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { c.presentHover(true) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { c.presentHover(false) }
            }
            if args.contains("--dodge-cycle") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { c.presentDodge(true) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { c.presentDodge(false) }
            }
            if args.contains("--flip-cycle") {
                for k in 1...8 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + hold / 2 + 2.5 * Double(k)) { c.presentFlip() }
                }
            }
            // 负担实测：连续展开 / 收起 N 次，看内存是每次都涨还是涨到一个数就停（grill 2026-09-18）。
            if let i = args.firstIndex(of: "--expand-cycles"), i + 1 < args.count, let n = Int(args[i + 1]) {
                for k in 0..<n {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0 + 4.0 * Double(k)) { c.presentExpanded() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0 + 4.0 * Double(k)) { c.presentCollapse() }
                }
            }
            if args.contains("--pill-cycle") {
                let t0 = 3.5
                DispatchQueue.main.asyncAfter(deadline: .now() + t0) { c.presentExpanded() }
                DispatchQueue.main.asyncAfter(deadline: .now() + t0 + 2.0) { c.presentCollapse() }
                DispatchQueue.main.asyncAfter(deadline: .now() + t0 + 4.0) { c.presentPillHover(true) }
                DispatchQueue.main.asyncAfter(deadline: .now() + t0 + 5.5) { c.presentPillHover(false) }
                DispatchQueue.main.asyncAfter(deadline: .now() + t0 + 6.5) { c.presentHoverBump(true) }
                DispatchQueue.main.asyncAfter(deadline: .now() + t0 + 7.5) { c.presentHoverBump(false) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + hold) {
            NSApp.terminate(nil)
        }
    }
}
