import Foundation

/// 活动文件的校验。先按下面这张结构表逐字段查原始 JSON（多出来的字段、错的类型、表外的符号与颜色、超长文字），
/// 全部通过才交给 `Codable` 解码。拒收不静默：每条原因都带字段路径，写进拒收日志，也显示在健康状态里（L3）。
///
/// 结构表同时是协议文档：`docs/protocol/activity-v1.md` 由 `lintel schema` 从这里打印，不另写一份。
public enum Validation {
    public struct Reject: Sendable, Equatable, Codable {
        public var producer: String
        public var file: String
        public var path: String
        public var reason: String
        public init(producer: String, file: String, path: String, reason: String) {
            self.producer = producer; self.file = file; self.path = path; self.reason = reason
        }
    }

    /// 内容里自称来源的字段。来源只由目录决定（L2），写了就拒收，免得读的人以为它算数。
    public static let claimedSourceKeys: Set<String> = ["producer", "source", "from", "app", "sender", "origin"]

    /// 刘海与胶囊里用得到的 SF Symbols。来源程序只能从这里选。
    public static let symbols: Set<String> = [
        "exclamationmark.triangle.fill", "checklist", "questionmark.bubble.fill", "questionmark.bubble",
        "arrow.uturn.backward", "ellipsis", "terminal", "doc.text", "pencil", "magnifyingglass", "globe",
        "person.2", "circle.dotted",
    ]

    /// 硬上限：超过就拒收。**只拦离谱的内容**；刘海放不下的正常长度由画法截断（正文限两行、面板里点开看全文），不在这里拒。
    ///
    /// 2026-09-17 试用第一分钟就踩到：`line` 原本设 400 字，而「你的要求」那一行存的是完整原话，
    /// 真实的一条 507 字原话让**整份活动被拒收**，那个会话在刘海上直接不显示——上限拦掉的正是要显示的东西。
    public enum Limit {
        public static let short = 64          // 标签、胶囊字、阶段词、名字
        public static let line = 20_000       // 一行正文（存的是完整原话，画的时候才截断）
        public static let long = 200_000      // 可展开的全文（面板里的每一轮原话与理解）
        public static let list = 500          // 数组长度
    }

    indirect enum Shape: Sendable {
        case object([String: Field])
        case array(Shape, max: Int)
        case string(max: Int)
        case oneOf(Set<String>)
        case symbol
        case swatch
        case date
        case number(ClosedRange<Double>)
        case integer(ClosedRange<Int>)
        case bool
        /// 带 kind 的变体：kind → 该变体的字段（kind 本身不用写进字段表）。
        case tagged([String: [String: Field]])
    }

    struct Field: Sendable {
        let shape: Shape
        let required: Bool
        let nullable: Bool
        static func req(_ s: Shape) -> Field { Field(shape: s, required: true, nullable: false) }
        static func opt(_ s: Shape) -> Field { Field(shape: s, required: false, nullable: true) }
    }

    static let swatches = Set(Swatch.allCases.map(\.rawValue))

    static let pill: Shape = .object([
        "symbol": .opt(.symbol), "dot": .opt(.swatch), "tint": .opt(.swatch), "pulse": .req(.bool),
        "clockSince": .opt(.date), "agoSince": .opt(.date), "title": .opt(.string(max: Limit.short)),
        "preview": .opt(.string(max: Limit.short)),
    ])
    static let label: Shape = .object(["text": .req(.string(max: Limit.short)), "tone": .req(.swatch), "count": .opt(.integer(0...1_000_000))])
    static let stat: Shape = .object([
        "label": .req(.string(max: Limit.short)), "value": .req(.string(max: Limit.short)), "tone": .opt(.swatch),
        "gauge": .opt(.number(0...1)), "dots": .opt(.integer(0...4)),
        "series": .opt(.array(.number(0...1), max: 400)), "hint": .opt(.string(max: Limit.line)),
    ])
    static let choice: [String: Field] = [
        "choiceKind": .req(.oneOf(["question", "plan"])), "title": .req(.string(max: Limit.short)),
        "countNote": .opt(.string(max: Limit.short)), "at": .opt(.date), "question": .opt(.string(max: Limit.line)),
        "options": .req(.array(.string(max: Limit.short), max: 32)), "action": .req(.string(max: Limit.short)),
    ]
    static let timeline: [String: Field] = [
        "startedAt": .req(.date), "endedAt": .opt(.date),
        "segments": .req(.array(.object(["name": .req(.string(max: Limit.short)), "swatch": .req(.swatch),
                                          "from": .opt(.date), "to": .opt(.date), "mergeIfEmpty": .opt(.bool)]), max: 8)),
        "markAt": .opt(.date), "ticks": .req(.array(.date, max: Limit.list)),
        "endLabel": .req(.string(max: Limit.short)), "sentPrefix": .opt(.string(max: Limit.short)),
    ]
    static let steps: [String: Field] = [
        "offset": .req(.integer(0...1_000_000)),
        "items": .req(.array(.object(["symbol": .req(.symbol), "text": .req(.string(max: Limit.line)), "at": .opt(.date)]), max: 16)),
        "startedAt": .req(.date), "live": .req(.bool), "limit": .req(.integer(1...16)),
    ]
    static let item: Shape = .tagged([
        "para": ["text": .req(.string(max: Limit.line)), "tone": .req(.swatch)],
        "pending": ["symbol": .req(.symbol), "text": .req(.string(max: Limit.line)), "clockSince": .opt(.date)],
        "iconLine": ["symbol": .req(.symbol), "text": .req(.string(max: Limit.line))],
        "choice": choice,
        "timeline": timeline,
        "steps": steps,
        "diff": ["label": .req(.string(max: Limit.short)), "old": .opt(.string(max: Limit.line)), "new": .req(.string(max: Limit.line))],
    ])
    static let block: Shape = .tagged([
        "section": ["title": .req(.string(max: Limit.short)), "value": .opt(.string(max: Limit.short)),
                    "valueTone": .opt(.swatch), "badge": .opt(.string(max: Limit.short)),
                    "items": .req(.array(item, max: 64))],   // 09-21：展开卡里滚动看全部改动句，一节不止 16 条
        "stats": ["cells": .req(.array(stat, max: 8))],
    ])
    static let line: Shape = .object(["label": .req(.string(max: Limit.short)), "text": .req(.string(max: Limit.long)), "tone": .req(.swatch)])
    static let legendKey: Shape = .object(["name": .req(.string(max: Limit.short)), "swatch": .req(.swatch), "count": .req(.integer(0...1_000_000))])
    /// 候选 A：改动集点开后的定位行。where 是显示用的定位，copy 是拿去贴的。
    static let row: Shape = .object(["label": .req(.string(max: Limit.short)), "where": .opt(.string(max: 256)), "copy": .opt(.string(max: 1024)),
                                     "old": .opt(.string(max: Limit.line)), "new": .req(.string(max: Limit.line))])

    static let overviewKey: Shape = .object(["name": .req(.string(max: Limit.short)), "swatch": .opt(.swatch), "dashed": .opt(.bool),
                                             "value": .opt(.string(max: 16))])
    static let overview: Shape = .object([
        "days": .req(.object([
            "title": .req(.string(max: Limit.short)), "note": .opt(.string(max: Limit.short)), "hint": .opt(.string(max: 256)),
            "bars": .req(.array(.object(["label": .opt(.string(max: 16)), "value": .opt(.integer(0...1_000_000)),
                                         "stage": .opt(.integer(0...16)), "gapDays": .opt(.integer(1...10_000))]), max: 60)),
        ])),
        "stages": .req(.array(.object([
            "title": .req(.string(max: Limit.short)), "name": .opt(.string(max: Limit.short)),
            "caption": .req(.string(max: Limit.short)),
            "profile": .req(.object([
                "title": .req(.string(max: Limit.short)), "note": .opt(.string(max: Limit.short)), "hint": .opt(.string(max: 256)),
                "caption": .opt(.string(max: 256)),
                "legend": .opt(.array(overviewKey, max: 6)),
                "cells": .req(.array(.object([
                    "id": .req(.string(max: Limit.short)), "label": .req(.string(max: Limit.short)),
                    "chapter": .opt(.string(max: Limit.short)), "weight": .req(.integer(0...1_000_000)),
                    "value": .req(.number(0...1)), "mark": .opt(.bool), "note": .opt(.string(max: 256)),
                ]), max: 120)),
            ])),
            "alignment": .opt(.object([
                "title": .req(.string(max: Limit.short)), "note": .opt(.string(max: Limit.short)), "hint": .opt(.string(max: 256)),
                "empty": .opt(.string(max: 256)),
                "headline": .opt(.array(.object(["value": .req(.string(max: 16)), "text": .req(.string(max: Limit.short)),
                                                  "tone": .req(.swatch)]), max: 4)),
                "caption": .opt(.string(max: 256)),
                "legend": .opt(.array(overviewKey, max: 6)),
                "trend": .opt(.object([
                    "points": .req(.array(.object(["scope": .req(.integer(0...1_000_000)), "done": .req(.integer(0...1_000_000)),
                                                   "missing": .opt(.integer(0...1_000_000))]), max: 200)),
                    "marker": .opt(.integer(0...199)), "markerLabel": .opt(.string(max: Limit.short)),
                    "startLabel": .opt(.string(max: 16)), "endLabel": .opt(.string(max: 16)),
                    "legend": .req(.array(overviewKey, max: 6)),
                ])),
                "items": .opt(.array(.object([
                    "place": .req(.string(max: Limit.short)), "tag": .req(.string(max: Limit.short)),
                    "key": .req(.string(max: 256)), "text": .req(.string(max: 256)), "tone": .req(.swatch),
                    "action": .opt(.object(["title": .req(.string(max: Limit.short)), "id": .req(.string(max: 512))])),
                ]), max: 64)),
                "folded": .opt(.string(max: Limit.short)),
            ])),
        ]), max: 8)),
        "selected": .req(.integer(0...7)),
        "todo": .opt(.object([
            "title": .req(.string(max: Limit.short)), "note": .opt(.string(max: Limit.short)), "hint": .opt(.string(max: 256)),
            "cells": .req(.array(.object(["title": .req(.string(max: Limit.short)), "text": .req(.string(max: Limit.short)),
                                          "value": .opt(.string(max: 16)),
                                          "sub": .opt(.string(max: 256)), "tone": .opt(.swatch)]), max: 4)),
        ])),
        "latest": .opt(.object([
            "at": .opt(.date), "tag": .req(.string(max: Limit.short)), "badge": .opt(.string(max: Limit.short)),
            "where": .opt(.string(max: Limit.short)), "more": .opt(.string(max: Limit.short)),
        ])),
    ])

    /// 对话的长清单（Activity.Chain）。字由来源写好；状态只认五种。
    static let chain: Shape = .object([
        "items": .req(.array(.object([
            "id": .req(.string(max: 16)), "text": .req(.string(max: Limit.line)),
            "state": .req(.oneOf(Set(Activity.Chain.State.allCases.map(\.rawValue)))),
            "note": .opt(.string(max: Limit.short)), "approved": .opt(.bool), "idle": .opt(.integer(0...100_000)),
            "was": .opt(.string(max: Limit.line)), "now": .opt(.string(max: Limit.line)), "wait": .opt(.string(max: Limit.short)),
        ]), max: Limit.list)),
        "problems": .req(.array(.string(max: Limit.line), max: 16)),
        "labels": .req(.object(["done": .req(.string(max: Limit.short)), "doing": .req(.string(max: Limit.short)),
                                "you": .req(.string(max: Limit.short)), "other": .req(.string(max: Limit.short)),
                                "later": .req(.string(max: Limit.short))])),
        "error": .opt(.string(max: Limit.line)),
    ])

    /// 稿件的环（Activity.Ring）。字由来源写好；状态、可见性只认列出的几种。
    static let ringItem: Shape = .object(["id": .req(.string(max: 32)), "text": .req(.string(max: Limit.line)), "you": .opt(.bool),
                                           "moved": .opt(.string(max: 16)), "detail": .opt(.string(max: Limit.line))])
    static let ring: Shape = .object([
        "name": .opt(.string(max: Limit.short)),
        "since": .req(.string(max: Limit.line)),
        "segments": .req(.array(.object([
            "key": .req(.string(max: 16)), "name": .req(.string(max: Limit.short)),
            "state": .req(.oneOf(Set(Activity.Ring.State.allCases.map(\.rawValue)))),
            "sight": .req(.oneOf(Set(Activity.Ring.Sight.allCases.map(\.rawValue)))),
            "sightNote": .req(.string(max: Limit.short)), "note": .req(.string(max: Limit.short)),
            "items": .req(.array(ringItem, max: 32)),
        ]), max: 8)),
        "current": .opt(.string(max: 16)), "latest": .opt(.string(max: 16)), "latestAt": .opt(.date), "reached": .opt(.string(max: 16)),
        "unhung": .req(.array(ringItem, max: 32)),
        "waiting": .req(.integer(0...100_000)),
        "closed": .req(.array(.object(["date": .req(.string(max: 16)), "items": .req(.array(.string(max: Limit.short), max: 64))]), max: 32)),
        "labels": .req(.object(["title": .req(.string(max: Limit.short)), "current": .req(.string(max: Limit.short)),
                                "latest": .req(.string(max: Limit.short)), "unhung": .req(.string(max: Limit.short)),
                                "closed": .req(.string(max: Limit.short)), "waiting": .req(.string(max: Limit.short))])),
        "error": .opt(.string(max: Limit.line)),
    ])

    static let activity: Shape = .object([
        "schema": .req(.integer(1...1)),
        "id": .req(.string(max: 128)),
        "revision": .opt(.string(max: 128)),
        "updatedAt": .opt(.date),
        "heartbeatSeconds": .opt(.number(1...86_400)),
        "open": .req(.bool), "running": .req(.bool), "stale": .req(.bool), "inProgress": .req(.bool),
        "rank": .req(.oneOf(Set(Activity.Rank.allCases.map(\.rawValue)))),
        "flagged": .req(.bool),
        "activityAt": .opt(.date), "closedAt": .opt(.date), "name": .opt(.string(max: Limit.short)),
        "group": .opt(.object(["id": .req(.string(max: 1024)), "name": .req(.string(max: Limit.short))])),
        "events": .req(.array(.object(["id": .req(.string(max: 256)), "type": .req(.string(max: Limit.short)), "at": .opt(.date)]), max: 64)),
        "status": .opt(.object([
            "center": .req(.oneOf(Set(Activity.Center.allCases.map(\.rawValue)))),
            "ringRemaining": .opt(.number(0...1)), "lastWriteAt": .opt(.date),
            "summary": .opt(.string(max: Limit.line)), "bounceAt": .opt(.date),
            "clock": .opt(.object(["style": .req(.oneOf(["live", "ago", "frozen"])), "since": .opt(.date),
                                   "seconds": .opt(.number(0...1_000_000)), "opacity": .opt(.number(0...1))])),
        ])),
        "label": .opt(label), "labelUntilSeen": .req(.bool), "labelSeen": .opt(label),
        "pill": .opt(pill),
        "pillUntilSeen": .req(.bool),
        "pillSeen": .opt(pill),
        "ears": .opt(.object(["leading": .req(.string(max: Limit.short)), "tag": .req(label), "tagSeen": .opt(label),
                              "phase": .req(.string(max: Limit.short))])),
        "popup": .req(.array(.object(["label": .req(.string(max: Limit.short)), "text": .req(.string(max: Limit.line)),
                                      "tone": .req(.oneOf(["primary", "secondary", "warning", "accent", "quiet"])),
                                      "lines": .req(.integer(1...4))]), max: 4)),
        "body": .req(.array(block, max: 8)),
        "flip": .opt(.object(["title": .req(.string(max: Limit.short)), "subtitle": .req(.string(max: Limit.short)),
                              "phase": .req(.string(max: Limit.short))])),
        "paged": .opt(.bool),
        "detail": .opt(.object([
            "listTitle": .req(.string(max: Limit.short)), "dot": .req(.swatch), "dotSeen": .opt(.swatch),
            "historyNote": .opt(.string(max: Limit.short)),
            "history": .req(.array(.object([
                "id": .req(.string(max: 256)), "at": .opt(.date), "tag": .opt(.string(max: Limit.short)),
                "badge": .opt(.string(max: Limit.short)), "duration": .opt(.string(max: Limit.short)),
                "lines": .req(.array(line, max: 4)), "expandable": .req(.bool),
                "rows": .opt(.array(row, max: 16)),
                "sections": .opt(.array(.string(max: Limit.short), max: 120)),
            ]), max: Limit.list)),
            "live": .opt(.object([
                "at": .opt(.date), "tag": .opt(.string(max: Limit.short)), "badge": .req(.string(max: Limit.short)),
                "clockSince": .opt(.date), "lines": .req(.array(line, max: 4)),
                "choice": .opt(.object(choice)), "timeline": .opt(.object(timeline)), "steps": .opt(.object(steps)),
            ])),
            "chart": .opt(.object([
                "title": .req(.string(max: Limit.short)), "headline": .req(.string(max: Limit.short)),
                "bars": .req(.array(.object(["seconds": .opt(.number(0...1_000_000)), "swatch": .req(.swatch),
                                             "label": .opt(.string(max: 16)), "note": .opt(.string(max: 256))]), max: Limit.list)),
                "runningSince": .opt(.date),
                "legend": .req(.array(legendKey, max: 12)),
                "hint": .opt(.string(max: 256)),
            ])),
            "strip": .opt(.object([
                "title": .req(.string(max: Limit.short)),
                "cells": .req(.array(.swatch, max: Limit.list)),
                "legend": .req(.array(legendKey, max: 12)),
            ])),
            "stats": .req(.array(stat, max: 8)),
            "overview": .opt(overview),
        ])),
        "chain": .opt(chain),
        "ring": .opt(ring),
        "within": .opt(.array(.object(["producer": .req(.string(max: 64)), "id": .req(.string(max: 128)),
                                       "role": .opt(.oneOf(Set(Activity.Link.Role.allCases.map(\.rawValue))))]), max: 16)),
    ])

    /// 校验一份活动文件。`registered`：这个来源程序登记过的事件类型；nil = 来源程序本身没登记。
    public static func check(data: Data, producer: String, file: String, registered: Set<String>?) -> (Activity?, [Reject]) {
        var rejects: [Reject] = []
        func reject(_ path: String, _ reason: String) {
            rejects.append(Reject(producer: producer, file: file, path: path, reason: reason))
        }
        guard let registered else {
            reject("", "来源程序「\(producer)」没有登记")
            return (nil, rejects)
        }
        guard file.hasSuffix(".json") else {
            reject("", "活动文件要以 .json 结尾")
            return (nil, rejects)
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            reject("", "不是合法的 JSON（可能还没写完）")
            return (nil, rejects)
        }
        walk(root, activity, "", reject)
        if let obj = root as? [String: Any] {
            let stem = String(file.dropLast(5))
            if let id = obj["id"] as? String, id != stem { reject("id", "id「\(id)」与文件名「\(stem)」不一致") }
            for (i, e) in ((obj["events"] as? [[String: Any]]) ?? []).enumerated() {
                if let t = e["type"] as? String, !registered.contains(t) { reject("events[\(i)].type", "事件类型「\(t)」没有登记") }
            }
        }
        guard rejects.isEmpty else { return (nil, rejects) }
        do {
            return (try LintelJSON.decoder.decode(Activity.self, from: data), [])
        } catch {
            reject("", "结构校验通过但解码失败：\(error)")
            return (nil, rejects)
        }
    }

    /// 结构表打印成 Markdown（`lintel schema`）：协议文档从这里生成，不另写一份会漂的。
    public static func describe() -> String {
        // 抬头也在这里生成。2026-09-17 重跑 `lintel schema > docs/protocol/activity-v1.md` 时发现它原来是手加的，
        // 一重跑就没了——文件自己写着「不手改」，却有一段只能手改。
        var lines = [
            "# lintel 活动格式 v1", "",
            "由 `lintel schema` 从 `Sources/LintelCore/Validation.swift` 的结构表生成，不手改。字段含义见 `Sources/LintelCore/Activity.swift` 的注释。", "",
            "- 位置：`producers/<来源程序 id>/activities/<活动 id>.json`，来源只由目录决定",
            "- 写法：先写临时文件再改名；时刻一律 ISO 8601 且带时区",
            "- 拒收：结构表外的字段、类型不对、超长、符号表与调色板以外的值、没登记的来源程序与事件类型；原因写进 `state/rejects.jsonl` 并在刘海上显示异常", "",
            "| 字段 | 类型 | 必填 |", "|---|---|---|",
        ]
        func typeText(_ s: Shape) -> String {
            switch s {
            case .object: return "对象"
            case .tagged(let v): return "按 kind 分：" + v.keys.sorted().joined(separator: " / ")
            case .array(let inner, let max): return "数组（≤\(max)）of " + typeText(inner)
            case .string(let max): return "字符串（≤\(max) 字）"
            case .oneOf(let set): return "取值 " + set.sorted().joined(separator: " / ")
            case .symbol: return "符号（符号表）"
            case .swatch: return "颜色（调色板）"
            case .date: return "ISO 8601 时刻，必须带时区"
            case .number(let r): return "数 \(r.lowerBound)…\(r.upperBound)"
            case .integer(let r): return "整数 \(r.lowerBound)…\(r.upperBound)"
            case .bool: return "布尔"
            }
        }
        func rows(_ spec: [String: Field], _ prefix: String) {
            for (k, f) in spec.sorted(by: { $0.key < $1.key }) {
                let path = prefix.isEmpty ? k : "\(prefix).\(k)"
                lines.append("| `\(path)` | \(typeText(f.shape)) | \(f.required ? "是" : "") |")
                expand(f.shape, path)
            }
        }
        func expand(_ shape: Shape, _ path: String) {
            switch shape {
            case .object(let spec): rows(spec, path)
            case .array(let inner, _): expand(inner, path + "[]")
            case .tagged(let variants):
                for (kind, spec) in variants.sorted(by: { $0.key < $1.key }) { rows(spec, "\(path){kind=\(kind)}") }
            default: break
            }
        }
        expand(activity, "")
        lines.append("")
        lines.append("符号表：" + symbols.sorted().map { "`\($0)`" }.joined(separator: " "))
        lines.append("")
        lines.append("调色板：" + Swatch.allCases.map { "`\($0.rawValue)`" }.joined(separator: " "))
        lines.append("")
        lines.append("内容里不许出现的顶层字段（来源只由目录决定）：" + claimedSourceKeys.sorted().map { "`\($0)`" }.joined(separator: " "))
        return lines.joined(separator: "\n")
    }

    static func walk(_ value: Any, _ shape: Shape, _ path: String, _ reject: (String, String) -> Void) {
        func typeName(_ v: Any) -> String {
            switch v {
            case is NSNull: return "null"
            case let n as NSNumber: return CFGetTypeID(n) == CFBooleanGetTypeID() ? "布尔" : "数"
            case is String: return "字符串"
            case is [Any]: return "数组"
            case is [String: Any]: return "对象"
            default: return "\(type(of: v))"
            }
        }
        func isBool(_ v: Any) -> Bool { (v as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() } ?? false }
        func fields(_ obj: [String: Any], _ spec: [String: Field], skip: Set<String> = []) {
            for (k, v) in obj where !skip.contains(k) {
                let p = path.isEmpty ? k : "\(path).\(k)"
                // 只查顶层：嵌套里的 from / to 是时间段的起止，不是来源
                if path.isEmpty, claimedSourceKeys.contains(k) { reject(p, "内容自称来源（来源只由目录决定）"); continue }
                guard let f = spec[k] else { reject(p, "未知字段"); continue }
                if v is NSNull {
                    if !f.nullable { reject(p, "不能为 null") }
                    continue
                }
                walk(v, f.shape, p, reject)
            }
            for (k, f) in spec where f.required && obj[k] == nil {
                reject(path.isEmpty ? k : "\(path).\(k)", "缺少必填字段")
            }
        }
        switch shape {
        case .object(let spec):
            guard let obj = value as? [String: Any] else { return reject(path, "应为对象，实际是\(typeName(value))") }
            fields(obj, spec)
        case .tagged(let variants):
            guard let obj = value as? [String: Any] else { return reject(path, "应为对象，实际是\(typeName(value))") }
            guard let kind = obj["kind"] as? String else { return reject(path.isEmpty ? "kind" : "\(path).kind", "缺少 kind") }
            guard let spec = variants[kind] else { return reject("\(path).kind", "未知的 kind「\(kind)」，可选 \(variants.keys.sorted())") }
            fields(obj, spec, skip: ["kind"])
        case .array(let inner, let max):
            guard let arr = value as? [Any] else { return reject(path, "应为数组，实际是\(typeName(value))") }
            if arr.count > max { reject(path, "超过 \(max) 项（\(arr.count)）") }
            for (i, v) in arr.enumerated() { walk(v, inner, "\(path)[\(i)]", reject) }
        case .string(let max):
            guard let s = value as? String else { return reject(path, "应为字符串，实际是\(typeName(value))") }
            if s.count > max { reject(path, "超长：\(s.count) 字，上限 \(max)") }
        case .oneOf(let allowed):
            guard let s = value as? String else { return reject(path, "应为字符串，实际是\(typeName(value))") }
            if !allowed.contains(s) { reject(path, "「\(s)」不在可选值 \(allowed.sorted()) 里") }
        case .symbol:
            guard let s = value as? String else { return reject(path, "应为符号名，实际是\(typeName(value))") }
            if !symbols.contains(s) { reject(path, "符号「\(s)」不在符号表里") }
        case .swatch:
            guard let s = value as? String else { return reject(path, "应为颜色名，实际是\(typeName(value))") }
            if !swatches.contains(s) { reject(path, "颜色「\(s)」不在调色板里") }
        case .date:
            guard let s = value as? String, LintelJSON.parseDate(s) != nil else { return reject(path, "应为 ISO 8601 时刻") }
        case .number(let range):
            guard let n = value as? NSNumber, !isBool(value) else { return reject(path, "应为数，实际是\(typeName(value))") }
            if !range.contains(n.doubleValue) { reject(path, "\(n) 超出 \(range)") }
        case .integer(let range):
            guard let n = value as? NSNumber, !isBool(value), n.doubleValue == n.doubleValue.rounded() else {
                return reject(path, "应为整数，实际是\(typeName(value))")
            }
            if !range.contains(n.intValue) { reject(path, "\(n) 超出 \(range)") }
        case .bool:
            if !isBool(value) { reject(path, "应为布尔，实际是\(typeName(value))") }
        }
    }
}
