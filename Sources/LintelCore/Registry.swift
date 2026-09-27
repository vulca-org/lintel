import Foundation

/// lintel 在磁盘上的位置。默认 `~/Library/Application Support/lintel/`；`LINTEL_HOME` 可以换（测试、演示、比对截图用）。
public struct LintelPaths: Sendable, Equatable {
    public let home: URL

    public init(home: URL) { self.home = home }

    public static func `default`(environment: [String: String] = ProcessInfo.processInfo.environment) -> LintelPaths {
        if let h = environment["LINTEL_HOME"], !h.isEmpty {
            return LintelPaths(home: URL(fileURLWithPath: h, isDirectory: true))
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return LintelPaths(home: base.appendingPathComponent("lintel", isDirectory: true))
    }

    public var registry: URL { home.appendingPathComponent("registry.json") }
    public var producers: URL { home.appendingPathComponent("producers", isDirectory: true) }
    public func activities(_ producer: String) -> URL {
        producers.appendingPathComponent(producer, isDirectory: true).appendingPathComponent("activities", isDirectory: true)
    }
    /// lintel 交给来源程序的东西（拖到刘海上的目录，候选 B）。lintel 只写文件，不运行来源的程序；来源自己来读。
    public func inbox(_ producer: String) -> URL {
        producers.appendingPathComponent(producer, isDirectory: true).appendingPathComponent("inbox", isDirectory: true)
    }
    /// lintel 自己写的东西（看过、拒收日志）。来源程序不写这里。
    public var state: URL { home.appendingPathComponent("state", isDirectory: true) }
    public var seen: URL { state.appendingPathComponent("seen.json") }
    /// 每个活动最近看过的一组版本（`SeenStore`）。`seen.json` 照写最后一个，旧宿主只认那个。
    public var seenRecent: URL { state.appendingPathComponent("seen-v2.json") }
    public var rejects: URL { state.appendingPathComponent("rejects.jsonl") }
}

/// 登记：哪些来源程序可以交活动、各自有哪些事件类型、哪些事件「需要你注意」。
/// 只能由你在终端运行 `lintel register` 或手写 registry.json 完成；来源程序不能给自己登记。
public struct Registry: Codable, Sendable, Equatable {
    public var schema: Int
    public var producers: [String: Producer]

    public struct Producer: Codable, Sendable, Equatable {
        /// 面板与来源标记上写的名字。
        public var name: String
        /// 极简呈现里的识别字母（无障碍标签与面板全名仍用它；画在刘海上的身份见 `mark`）。
        public var initial: String
        public var events: [String: EventSpec]
        /// 面板里的名词（第一版只有许愿柳，沿用它的说法）：一项活动叫什么、历史叫什么。
        public var nouns: Nouns?
        /// 刘海上的身份：形状与身份色（设计研究 2026-09-18 §6，B1/B2/B3）。没登记就画识别字母的小圆标。
        public var mark: Mark?
        /// 这个来源收什么拖放（候选 B）：目前只有 "folder"。没登记就不收，拖上来的东西不落到它的收件目录。
        public var accepts: [String]?

        public init(name: String, initial: String, events: [String: EventSpec], nouns: Nouns? = nil, mark: Mark? = nil, accepts: [String]? = nil) {
            self.name = name; self.initial = initial; self.events = events; self.nouns = nouns; self.mark = mark; self.accepts = accepts
        }
    }

    /// 一个来源在刘海上长什么样：靠形状和颜色分得开（HIG B1、B2），标志不加容器（B3）。
    public struct Mark: Codable, Sendable, Equatable {
        public var shape: Shape
        /// 身份色，调色板里的名字；不给就用次级墨色。
        public var tint: Swatch?

        public enum Shape: String, Codable, Sendable, CaseIterable {
            /// 许愿柳：合一状态圆（外圈弧、底部四点、圆心符号）。
            case circle
            /// 写作循环：两个方括号夹一条线（作者 2026-09-18 定的身份 B）。
            case bracket
        }

        public init(shape: Shape, tint: Swatch? = nil) { self.shape = shape; self.tint = tint }
    }

    public struct EventSpec: Codable, Sendable, Equatable {
        /// 需要你注意：到达时主动展开精简版。
        public var attention: Bool
        /// 到达时如果正展开着，停这么多秒后收起（许愿柳：打断一轮后「你撤回了这一轮」停 1.8 秒）。
        public var dismissExpandedAfter: Double?
        public init(attention: Bool, dismissExpandedAfter: Double? = nil) {
            self.attention = attention; self.dismissExpandedAfter = dismissExpandedAfter
        }
    }

    public struct Nouns: Codable, Sendable, Equatable {
        public var activities: String
        public var history: String
        public var recentHistory: String
        public var noTag: String
        public init(activities: String, history: String, recentHistory: String, noTag: String) {
            self.activities = activities; self.history = history; self.recentHistory = recentHistory; self.noTag = noTag
        }
    }

    public init(producers: [String: Producer] = [:]) {
        schema = 1
        self.producers = producers
    }

    /// 来源程序 id：小写字母、数字、连字符，1–32 个字符。它就是目录名，所以不许有路径分隔符和点。
    public static func isValidProducerId(_ id: String) -> Bool {
        id.range(of: #"^[a-z0-9][a-z0-9-]{0,31}$"#, options: .regularExpression) != nil
    }

    public static func load(_ paths: LintelPaths) throws -> Registry {
        let data = try Data(contentsOf: paths.registry)
        return try LintelJSON.decoder.decode(Registry.self, from: data)
    }

    public func save(_ paths: LintelPaths) throws {
        try FileManager.default.createDirectory(at: paths.home, withIntermediateDirectories: true)
        try LintelJSON.writeAtomically(self, to: paths.registry)
    }
}

public enum LintelJSON {
    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleContainer().decode(String.self)
            guard let date = parseDate(s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "不是 ISO 8601 时刻：\(s)"))
            }
            return date
        }
        return d
    }

    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(formatDate(date))
        }
        return e
    }

    /// 必须带时区（`Z` 或 `+01:00`）。不带时区的时刻读方只能猜是哪个钟，拒收。
    /// 先前写方与读方都用了不带时区的格式，两边自洽、校验不报，时刻却差着一个时区（2026-09-17 导出样例时发现）。
    public static func parseDate(_ s: String) -> Date? {
        if let d = try? Date(s, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return d }
        return try? Date(s, strategy: Date.ISO8601FormatStyle())
    }

    public static func formatDate(_ d: Date) -> String {
        d.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    /// 先写临时文件再改名：读方永远读不到半个文件。
    public static func writeAtomically<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try writeAtomically(data, to: url)
    }

    public static func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(getpid()).tmp")
        try data.write(to: tmp)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
    }
}

private extension Decoder {
    func singleContainer() throws -> SingleDecodingContainerBox { SingleDecodingContainerBox(try singleValueContainer()) }
}

private struct SingleDecodingContainerBox {
    var c: SingleValueDecodingContainer
    init(_ c: SingleValueDecodingContainer) { self.c = c }
    func decode<T: Decodable>(_ t: T.Type) throws -> T { try c.decode(t) }
}
