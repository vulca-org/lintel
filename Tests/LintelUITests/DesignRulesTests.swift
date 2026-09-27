import AppKit
import Foundation
import SwiftUI
import Testing
@testable import LintelCore
@testable import LintelUI

/// 09-24 grill（作者要求界面完全符合 Apple 的设计、视觉前后一致）：能用机器查的几条，查死。
/// 出处都是存档的 HIG 原文（evidence/refs-2026-09-18-design/raw/，manifest 里有 sha256）：
/// - Accessibility「Strive to meet color contrast minimum standards」：17pt 以下的字 4.5:1；
/// - Typography：macOS 默认 13pt、最小 10pt；「Consider using the built-in text styles」（13 / 12 / 11 / 10）；
/// - DesignKit 自己写的 4pt 间距网格。
@MainActor
@Suite("设计规则：对比度、字号、间距")
struct DesignRulesTests {
    /// WCAG 相对亮度：sRGB 分量先线性化。
    static func luminance(_ c: NSColor) -> Double {
        let s = c.usingColorSpace(.sRGB)!
        func lin(_ v: CGFloat) -> Double { let v = Double(v); return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let a = Double(s.alphaComponent)
        // 叠在纯黑上：分量乘 alpha。
        return 0.2126 * lin(s.redComponent * a) + 0.7152 * lin(s.greenComponent * a) + 0.0722 * lin(s.blueComponent * a)
    }

    static func contrastOnBlack(_ c: Color) -> Double {
        var out = 0.0
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance { out = (luminance(NSColor(c)) + 0.05) / 0.05 }
        return out
    }

    @Test("写字的每一级颜色在黑底上至少 4.5:1（HIG Accessibility，WCAG AA，17pt 以下）；quaternary 只许填充")
    func contrast() {
        for (name, c) in [("primary", Ink.primary), ("secondary", Ink.secondary), ("tertiary", Ink.tertiary), ("accent", Ink.accent),
                          ("orange", Swatch.orange.color), ("red", Swatch.red.color)] {
            let r = Self.contrastOnBlack(c)
            #expect(r >= 4.5, "\(name) \(String(format: "%.2f", r)):1")
        }
        #expect(Self.contrastOnBlack(Ink.quaternary) < 4.5, "quaternary 本来就过不了：别拿它写字")
    }

    /// 在某个外观下把颜色解成 sRGB。
    static func resolve(_ c: Color, _ name: NSAppearance.Name) -> NSColor {
        var out = NSColor.black
        NSAppearance(named: name)!.performAsCurrentDrawingAppearance { out = NSColor(c).usingColorSpace(.sRGB)! }
        return out
    }

    static func contrast(_ a: NSColor, _ b: NSColor) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// 第五版每一种「字色 × 底」在浅、深两种外观下都到 4.5:1。表里只列真会出现的组合：靛蓝只写在航班卡上（深色外框上它到不了），
    /// 刘海本体是黑底、深色值。
    static let v5Pairs: [(String, Color, String, Color)] = [
        ("cyan", Tone.cyan, "base", Surface.base), ("cyan", Tone.cyan, "group", Surface.group), ("cyan", Tone.cyan, "card", Surface.card),
        ("orange", Tone.orange, "base", Surface.base), ("orange", Tone.orange, "group", Surface.group), ("orange", Tone.orange, "card", Surface.card),
        ("indigo", Tone.indigo, "card", Surface.card),
        ("primary", Tone.primary, "base", Surface.base), ("primary", Tone.primary, "group", Surface.group),
        ("primary", Tone.primary, "card", Surface.card), ("primary", Tone.primary, "sidebar", Surface.sidebar),
        ("secondary", Tone.secondary, "base", Surface.base), ("secondary", Tone.secondary, "group", Surface.group),
        ("secondary", Tone.secondary, "card", Surface.card), ("secondary", Tone.secondary, "sidebar", Surface.sidebar),
    ]

    @Test("第五版：弹出框与窗口的字色在各自的底上，浅深两种外观都至少 4.5:1；刘海上的青、橙、靛蓝在黑底上也到")
    func v5Contrast() {
        for (tn, tone, sn, surface) in Self.v5Pairs {
            for a in [NSAppearance.Name.aqua, .darkAqua] {
                let r = Self.contrast(Self.resolve(tone, a), Self.resolve(surface, a))
                #expect(r >= 4.5, "\(tn) on \(sn) (\(a.rawValue)) \(String(format: "%.2f", r)):1")
            }
        }
        for (n, c) in [("cyan", Tone.cyan), ("orange", Tone.orange), ("indigo", Tone.indigo)] {
            let r = Self.contrast(Self.resolve(c, .darkAqua), .black)
            #expect(r >= 4.5, "\(n) on notch black \(String(format: "%.2f", r)):1")
        }
    }

    /// 读这两份新写的视图源码：字号、间距都在规则里。
    static func source(_ name: String) throws -> [String] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/LintelUI/\(name)")
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    static func numbers(_ line: String, after key: String) -> [Double] {
        var out: [Double] = []
        var rest = Substring(line)
        while let r = rest.range(of: key) {
            rest = rest[r.upperBound...]
            let digits = rest.prefix { "0123456789.".contains($0) }
            if let v = Double(digits) { out.append(v) }
        }
        return out
    }

    @Test("清单与环的字号只用 macOS 文字样式（13 / 12 / 11 / 10）；SF Symbols 的小图形可到 9；没有 10pt 以下的字")
    func typeSizes() throws {
        for file in ["ChainViews.swift", "RingViews.swift"] {
            for (i, line) in try Self.source(file).enumerated() {
                for v in Self.numbers(line, after: ".system(size: ") {
                    let symbol = line.contains("Image(systemName")
                    let ok = [10, 11, 12, 13].contains(v) || (symbol && v == 9)
                    #expect(ok, "\(file):\(i + 1) size \(v)")
                }
            }
        }
    }

    @Test("清单与环的间距在 4pt 网格上（2 是半格）")
    func spacingGrid() throws {
        let allowed: Set<Double> = [0, 2, 4, 8, 12, 16, 20, 24]
        for file in ["ChainViews.swift", "RingViews.swift"] {
            for (i, line) in try Self.source(file).enumerated() {
                for key in ["spacing: ", ".padding(.horizontal, ", ".padding(.vertical, ", ".padding(.top, ", ".padding(.bottom, "] {
                    for v in Self.numbers(line, after: key) {
                        #expect(allowed.contains(v), "\(file):\(i + 1) \(key)\(v)")
                    }
                }
            }
        }
    }
}
