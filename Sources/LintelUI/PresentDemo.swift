import AppKit
import Foundation

/// 演示开关（许愿柳 `PresentDemo` 的同名同义复制）：`--present <秒>` 起演示，`--passive` 不强制展开、按真实事件走。
public enum PresentDemo {
    nonisolated(unsafe) public static var seconds: Double? = nil
    nonisolated(unsafe) public static var passive = false
    /// `--log`：平时也把「为什么弹出、为什么换一张、为什么收起」写到 stderr。
    ///
    /// 2026-09-17 试用时发现：`lintel host` 一个字都不写，屏幕上出了岔子以后宿主侧没有任何记录可查，
    /// 只能看来源程序的日志和拒收文件——而它们看不见刘海自己的决定。
    nonisolated(unsafe) public static var logging = false
    /// `--scroll <点>`：演示时展开卡可滚，就滚到这里（09-22 验「头部钉住不滚」；演示宿主不收真实滚轮）。
    nonisolated(unsafe) public static var scrollY: CGFloat? = nil
    /// `--appearance light|dark`：弹出框与窗口用这个外观拍（深浅两张），不动系统设置。
    nonisolated(unsafe) public static var appearance: NSAppearance.Name? = nil
}
