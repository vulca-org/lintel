import Foundation
import Observation

/// 宿主里的一项活动：来源程序 id 由目录定，活动本身来自文件。
public struct Hosted: Sendable, Equatable, Identifiable {
    public let producer: String
    public var activity: Activity
    /// 文件最后一次被写的时刻（宿主自己看到的，不信来源程序写的时刻）。心跳按它算。
    public var writtenAt: Date?

    public var id: String { "\(producer)/\(activity.id)" }
    public init(producer: String, activity: Activity, writtenAt: Date?) {
        self.producer = producer; self.activity = activity; self.writtenAt = writtenAt
    }
}

/// 宿主自己的健康问题。常亮，不受「有新内容才出现」约束（spec 5.6）。
public struct HealthIssue: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable { case registryUnreadable, producersMissing, rejected, heartbeat }
    public var kind: Kind
    public var text: String
    public var producer: String?
    public var id: String { "\(kind.rawValue)|\(producer ?? "")|\(text)" }
}

/// 一次扫描的结果。纯函数，好测。
public struct Scan: Sendable, Equatable {
    public var registry: Registry?
    public var activities: [Hosted]
    public var rejects: [Validation.Reject]
    public var issues: [HealthIssue]
}

/// 扫描缓存：按文件的修改时刻、大小、inode，以及校验时用的那份登记，记住上一次读出与校验的结果。
/// 没变的文件不再读、不再校验（F1，负担实测 2026-09-18：先前每 5 秒与每次文件变动都把 53 份全读一遍，其中 50 份已关闭、不会再变）。
/// 心跳不进缓存：它按此刻算。
public final class ScanCache {
    struct Key: Equatable {
        let modified: Date?
        let size: Int?
        let inode: Int?
        let registered: Set<String>?
    }
    struct Entry {
        let key: Key
        let activity: Activity?
        let rejects: [Validation.Reject]
    }
    var entries: [String: Entry] = [:]
    /// 真正读了几次文件。测试用它确认没变的文件没有被读。
    public private(set) var reads = 0
    public init() {}

    func lookup(_ path: String, _ key: Key) -> Entry? {
        guard key.modified != nil, let e = entries[path], e.key == key else { return nil }
        return e
    }

    func store(_ path: String, _ key: Key, _ checked: (Activity?, [Validation.Reject])) {
        reads += 1
        entries[path] = Entry(key: key, activity: checked.0, rejects: checked.1)
    }

    /// 文件删掉了，缓存里也删。
    func keepOnly(_ paths: Set<String>) {
        entries = entries.filter { paths.contains($0.key) }
    }
}

public enum Scanner {
    /// 读登记、逐个来源程序目录读活动。只读，不写来源程序的任何文件。
    public static func scan(_ paths: LintelPaths, now: Date = Date(), cache: ScanCache? = nil) -> Scan {
        let fm = FileManager.default
        var issues: [HealthIssue] = []
        var registry: Registry?
        do {
            registry = try Registry.load(paths)
        } catch {
            issues.append(HealthIssue(kind: .registryUnreadable,
                                      text: fm.fileExists(atPath: paths.registry.path) ? L("读不到登记：\(error.localizedDescription)", "Can’t read the registry: \(error.localizedDescription)")
                                                                                        : L("还没有登记任何来源程序", "No producer is registered yet"),
                                      producer: nil))
        }
        var activities: [Hosted] = []
        var rejects: [Validation.Reject] = []
        guard fm.fileExists(atPath: paths.producers.path) else {
            if registry != nil {
                issues.append(HealthIssue(kind: .producersMissing, text: L("来源目录不存在", "The producers folder is missing"), producer: nil))
            }
            return Scan(registry: registry, activities: Health.activities(issues, now: now), rejects: [], issues: issues)
        }
        let producerDirs = ((try? fm.contentsOfDirectory(atPath: paths.producers.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
        var present: Set<String> = []
        defer { cache?.keepOnly(present) }
        for producer in producerDirs {
            let dir = paths.activities(producer)
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            let registered = registry?.producers[producer].map { Set($0.events.keys) }
            for name in names.sorted() where !name.hasPrefix(".") {
                let url = dir.appendingPathComponent(name)
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let written = attrs?[.modificationDate] as? Date
                let key = ScanCache.Key(modified: written, size: (attrs?[.size] as? NSNumber)?.intValue,
                                        inode: (attrs?[.systemFileNumber] as? NSNumber)?.intValue, registered: registered)
                let activity: Activity?, why: [Validation.Reject]
                if let hit = cache?.lookup(url.path, key) {
                    (activity, why) = (hit.activity, hit.rejects)
                } else {
                    guard let data = try? Data(contentsOf: url) else { continue }
                    (activity, why) = Validation.check(data: data, producer: producer, file: name, registered: registered)
                    cache?.store(url.path, key, (activity, why))
                }
                present.insert(url.path)
                rejects.append(contentsOf: why)
                guard var a = activity else { continue }
                if let hb = a.heartbeatSeconds, let w = written, now.timeIntervalSince(w) > hb * 1.5 {
                    Heartbeat.markSilent(&a, silentFor: now.timeIntervalSince(w))
                    issues.append(HealthIssue(kind: .heartbeat, text: Heartbeat.text(now.timeIntervalSince(w)), producer: producer))
                }
                activities.append(Hosted(producer: producer, activity: a, writtenAt: written))
            }
        }
        if !rejects.isEmpty {
            let byProducer = Dictionary(grouping: rejects, by: \.producer)
            for (p, rs) in byProducer.sorted(by: { $0.key < $1.key }) {
                issues.append(HealthIssue(kind: .rejected, text: L("拒收 \(Set(rs.map(\.file)).count) 份活动", "Rejected \(Set(rs.map(\.file)).count) activities"), producer: p))
            }
        }
        return Scan(registry: registry, activities: Ordering.sorted(activities + Health.activities(issues, now: now)), rejects: rejects, issues: issues)
    }
}

/// 宿主自己的健康问题画成刘海上的一项异常活动，来源写 lintel 自己（spec 5.6：常亮，不受「有新内容才出现」约束）。
/// 心跳超时不在这里：那一项活动本身已经被改成异常态。
public enum Health {
    public static let producer = "lintel"

    static func line(_ i: HealthIssue) -> String { i.producer.map { "\($0)：\(i.text)" } ?? i.text }

    /// 两翼上的短句。整句在展开卡里。
    static func short(_ i: HealthIssue) -> String {
        switch i.kind {
        case .registryUnreadable: L("没有登记", "No registry")
        case .producersMissing: L("目录不见了", "No folder")
        case .rejected: L("有拒收", "Rejected")
        case .heartbeat: L("没消息", "Silent")
        }
    }

    public static func activities(_ issues: [HealthIssue], now: Date) -> [Hosted] {
        let shown = issues.filter { $0.kind != .heartbeat }
        guard let first = shown.first else { return [] }
        var a = Activity(id: "health")
        a.rank = .anomaly
        a.activityAt = now
        a.open = false
        var st = Activity.Status(center: .broken)
        st.summary = shown.map(line).joined(separator: "；")
        a.status = st
        // 两翼只放得下 6 个汉字：这里写短句，整句在展开卡与悬停提示里（先前直接截长句，屏幕上是「还没有登记任何来…」）。
        a.label = Activity.Label(text: shown.count > 1 ? L("\(shown.count) 个问题", "\(shown.count) issues") : Self.short(first), tone: .red)
        var pill = Activity.Pill()
        pill.symbol = "exclamationmark.triangle.fill"
        pill.tint = .red
        pill.title = L("异常", "Alert")
        pill.preview = String(line(first).prefix(24))
        a.pill = pill
        a.ears = Activity.Ears(leading: "lintel", tag: Activity.Label(text: L("宿主异常", "Host issue"), tone: .red), phase: "")
        a.popup = shown.prefix(3).map { Activity.PopupLine(label: L("异常", "Alert"), text: line($0), tone: .warning, lines: 2) }
        a.body = [.section(Activity.Section(title: L("lintel 自己的问题", "lintel’s own issues"), items: shown.map { .para(text: line($0), tone: .red) }))]
        return [Hosted(producer: producer, activity: a, writtenAt: now)]
    }
}

/// 心跳超时：来源程序说过每 N 秒至少重写一次，超过 1.5 倍没写。
/// 「没有消息」与「已经结束」在屏幕上必须是两件事（全局规则〈八〉那次事故）。
public enum Heartbeat {
    public static func text(_ silent: TimeInterval) -> String {
        let m = Int(silent / 60)
        return m >= 1 ? L("\(m) 分钟没有消息，不代表已经结束", "No word for \(m) min — that doesn’t mean it ended")
                      : L("\(Int(silent)) 秒没有消息，不代表已经结束", "No word for \(Int(silent))s — that doesn’t mean it ended")
    }

    /// 把活动改成异常态：排到最前，左翼圆心变异常，右翼写「多久没有消息」。原来的内容留在展开态里。
    public static func markSilent(_ a: inout Activity, silentFor: TimeInterval) {
        a.rank = .anomaly
        a.inProgress = false
        var s = a.status ?? Activity.Status(center: .broken)
        s.center = .broken
        s.clock = nil
        a.status = s
        let m = max(1, Int(silentFor / 60))
        a.label = Activity.Label(text: L("\(m) 分钟没消息", "Silent \(m)m"), tone: .red)
        a.labelUntilSeen = false
        a.labelSeen = nil
        var p = Activity.Pill()
        p.symbol = "exclamationmark.triangle.fill"
        p.tint = .red
        p.title = L("没消息", "Silent")
        a.pill = p
        a.pillUntilSeen = false
        a.pillSeen = nil
        a.popup = [Activity.PopupLine(label: L("异常", "Alert"), text: text(silentFor), tone: .warning, lines: 2)] + a.popup.prefix(1)
    }
}

/// 你看过哪一版。lintel 自己的文件，来源程序不写。
///
/// 每个活动记最近看过的一组版本（设计 2026-09-22-awt-live M1）：刘海在几件事之间切换再切回来时，看过的那件不再重新亮起
/// （09-22 写作循环在「在跑」与旧改动之间来回，只记一个版本时旧标签一天亮了四次）。
/// `seen.json` 照写每个活动最后看过的那一个：旧宿主与 `lintel import-seen` 只认那个格式，读到别的会当成空表再整个覆盖掉。
/// 一组另存 `seen-v2.json`。
@MainActor
public final class SeenStore {
    /// 一个活动最多记这么多个版本，按最近使用淘汰；再看一次算刷新。
    public static let perActivity = 32
    private var latest: [String: String] = [:]
    private var recent: [String: [String]] = [:]
    private let url: URL?
    private let recentURL: URL?

    /// 不落盘的一份：演示与测试用，结果不取决于这台机器上恰好看过什么。
    public init(ephemeral: Bool) {
        url = nil
        recentURL = nil
    }

    public init(paths: LintelPaths) {
        url = paths.seen
        recentURL = paths.seenRecent
        if let data = try? Data(contentsOf: paths.seen), let d = try? JSONDecoder().decode([String: String].self, from: data) {
            latest = d
        }
        if let data = try? Data(contentsOf: paths.seenRecent), let f = try? JSONDecoder().decode(RecentFile.self, from: data) {
            recent = f.recent
        }
        // 旧宿主在两次之间写过 seen.json（回滚、import-seen）：它记下的那一版也算看过。
        for (id, rev) in latest where !(recent[id]?.contains(rev) ?? false) {
            recent[id, default: []].append(rev)
            trim(id)
        }
    }

    public func isUnread(_ h: Hosted) -> Bool {
        guard let rev = h.activity.revision else { return false }
        return !(recent[h.id]?.contains(rev) ?? false)
    }

    public func markSeen(_ h: Hosted) {
        guard let rev = h.activity.revision else { return }
        markSeen(id: h.id, revision: rev)
    }

    public func markSeen(id: String, revision: String) {
        var list = recent[id] ?? []
        guard latest[id] != revision || list.last != revision else { return }
        list.removeAll { $0 == revision }
        list.append(revision)
        recent[id] = list
        trim(id)
        latest[id] = revision
        persist()
    }

    private func trim(_ id: String) {
        if let n = recent[id]?.count, n > Self.perActivity { recent[id]?.removeFirst(n - Self.perActivity) }
    }

    private struct RecentFile: Codable {
        var schema: Int
        var recent: [String: [String]]
    }

    private func persist() {
        if let url, let data = try? JSONEncoder().encode(latest) { try? LintelJSON.writeAtomically(data, to: url) }
        if let recentURL, let data = try? JSONEncoder().encode(RecentFile(schema: 2, recent: recent)) {
            try? LintelJSON.writeAtomically(data, to: recentURL)
        }
    }
}

/// 宿主的活动存储：FSEvents 监听 producers/，外加 5 秒一次的扫描（目录刚建出来时 FSEvents 不报，心跳超时也没有文件事件）。
@MainActor
@Observable
public final class ActivityStore {
    public private(set) var registry: Registry?
    public private(set) var activities: [Hosted] = []
    public private(set) var rejects: [Validation.Reject] = []
    public private(set) var issues: [HealthIssue] = []
    public private(set) var lastScan: Date?

    public let paths: LintelPaths
    /// 每次扫描之后。
    @ObservationIgnored public var onReload: (() -> Void)?
    /// 新到的事件（启动时文件里已有的不算）。
    @ObservationIgnored public var onEvent: ((Hosted, Activity.Event, Registry.EventSpec) -> Void)?

    @ObservationIgnored private var announced: Set<String> = []
    @ObservationIgnored private var primed = false
    @ObservationIgnored private var watcher: DirectoryWatcher?
    @ObservationIgnored private var poll: Timer?
    @ObservationIgnored private var loggedRejects: Set<String> = []
    @ObservationIgnored private let cache = ScanCache()

    public init(paths: LintelPaths) { self.paths = paths }

    public func start() {
        reload()
        try? FileManager.default.createDirectory(at: paths.producers, withIntermediateDirectories: true)
        watcher = DirectoryWatcher(url: paths.home) { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        watcher?.start()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        poll = t
    }

    public func stop() {
        watcher?.stop(); watcher = nil
        poll?.invalidate(); poll = nil
    }

    public func reload(now: Date = Date()) {
        var s = Scanner.scan(paths, now: now, cache: cache)
        lastScan = now
        // 健康那一项每次扫描都按此刻重做一份；问题没变就沿用上一份（位置照新扫描的排），
        // 否则它的时刻每 5 秒变一次，「没变」被当成「变了」，整块刘海跟着重排重绘（F1）。
        let persistent = { (xs: [HealthIssue]) in xs.filter { $0.kind != .heartbeat } }
        if persistent(s.issues) == persistent(issues),
           let old = activities.first(where: { $0.producer == Health.producer }),
           let i = s.activities.firstIndex(where: { $0.producer == Health.producer }) {
            s.activities[i] = old
        }
        let changed = registry != s.registry || activities != s.activities || rejects != s.rejects || issues != s.issues
        if registry != s.registry { registry = s.registry }
        if activities != s.activities { activities = s.activities }
        if rejects != s.rejects { rejects = s.rejects }
        if issues != s.issues { issues = s.issues }
        logRejects(s.rejects, now: now)

        var fresh: [(Hosted, Activity.Event, Registry.EventSpec)] = []
        for h in s.activities {
            for e in h.activity.events {
                let key = "\(h.producer)|\(e.id)"
                guard !announced.contains(key) else { continue }
                announced.insert(key)
                if primed, let spec = s.registry?.producers[h.producer]?.events[e.type] { fresh.append((h, e, spec)) }
            }
        }
        let first = !primed
        primed = true
        // 什么都没变就不回调：回调会重排刘海，展开着时还要按内容量一次高度（F1）。
        if changed || first { onReload?() }
        // 同一次扫描里到了好几个：按事件时刻，最后到的最后处理（与许愿柳「取最近的那个」一致）。
        for (h, e, spec) in fresh.sorted(by: { ($0.1.at ?? .distantPast) < ($1.1.at ?? .distantPast) }) {
            onEvent?(h, e, spec)
        }
    }

    /// 拒收写进 state/rejects.jsonl。同一份文件同一个原因只记一次，免得每 5 秒重复一行。
    private func logRejects(_ rs: [Validation.Reject], now: Date) {
        let new = rs.filter { !loggedRejects.contains("\($0.producer)|\($0.file)|\($0.path)|\($0.reason)") }
        guard !new.isEmpty else { return }
        for r in new { loggedRejects.insert("\(r.producer)|\(r.file)|\(r.path)|\(r.reason)") }
        try? FileManager.default.createDirectory(at: paths.state, withIntermediateDirectories: true)
        var lines = Data()
        for r in new {
            let row: [String: String] = ["at": LintelJSON.formatDate(now), "producer": r.producer, "file": r.file, "path": r.path, "reason": r.reason]
            if let d = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) { lines.append(d); lines.append(0x0A) }
        }
        if let h = try? FileHandle(forWritingTo: paths.rejects) {
            h.seekToEndOfFile(); h.write(lines); try? h.close()
        } else {
            try? lines.write(to: paths.rejects)
        }
    }
}
