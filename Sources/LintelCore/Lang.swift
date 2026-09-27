import Foundation

/// 界面语言：跟随系统首选语言，首选是中文就中文，其余一律英文（与许愿柳 `Model/Lang.swift` 同一规则）。
/// `LINTEL_LANG=zh|en` 强制指定；比对截图时两边都要固定语言，所以也认 `WILLOW_LANG`。
public enum Lang: Sendable, Equatable {
    case zh, en

    nonisolated(unsafe) public static var current: Lang = resolve()

    public static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment,
                               preferred: [String] = Locale.preferredLanguages) -> Lang {
        for key in ["LINTEL_LANG", "WILLOW_LANG"] {
            if let forced = environment[key]?.lowercased() {
                if forced.hasPrefix("zh") { return .zh }
                if forced.hasPrefix("en") { return .en }
            }
        }
        return preferred.first?.lowercased().hasPrefix("zh") == true ? .zh : .en
    }
}

/// 宿主自己的一句文案，中英两种写法。来源程序的文字由来源程序按它自己的语言写好，不经过这里。
public func L(_ zh: String, _ en: String) -> String { Lang.current == .zh ? zh : en }
