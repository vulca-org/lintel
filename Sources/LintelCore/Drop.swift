import Foundation

/// 拖到刘海上的东西（候选 B，作者 09-21：只收目录，PDF 先不收）。
///
/// lintel 只做两件事：判断收不收，把路径写进来源程序的收件目录（`producers/<id>/inbox/<uuid>.json`，先写临时文件再改名）。
/// 不运行来源的程序、不认识登记表里的任何字段；来源自己的看门进程读到收件就登记、就回话（写一条新活动）。
public enum Drop {
    public static let folder = "folder"
    public static let schema = 1

    public enum Kind: Equatable, Sendable { case handed, refused }

    public struct Outcome: Equatable, Sendable {
        public let kind: Kind
        /// 收下它的来源 id 与登记名；拒收时是拒收的理由。
        public let producer: String?
        public let name: String
        public let reason: String
        public let file: URL?
    }

    /// 谁收目录：登记了 `accepts: ["folder"]` 的来源里 id 最小的那个（一般只有一个）。
    public static func taker(_ registry: Registry?) -> (id: String, producer: Registry.Producer)? {
        guard let r = registry else { return nil }
        return r.producers.filter { ($0.value.accepts ?? []).contains(folder) }
            .sorted { $0.key < $1.key }.first.map { ($0.key, $0.value) }
    }

    public static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    public static func receive(urls: [URL], registry: Registry?, paths: LintelPaths, now: Date = Date()) -> [Outcome] {
        urls.map { receive(url: $0, registry: registry, paths: paths, now: now) }
    }

    public static func receive(url: URL, registry: Registry?, paths: LintelPaths, now: Date = Date()) -> Outcome {
        guard isDirectory(url) else {
            return Outcome(kind: .refused, producer: nil, name: "", reason: L("只收目录，PDF 先不收", "Folders only, not PDFs yet"), file: nil)
        }
        guard let (id, producer) = taker(registry) else {
            return Outcome(kind: .refused, producer: nil, name: "", reason: L("没有来源收目录", "No source takes folders"), file: nil)
        }
        let dir = paths.inbox(id)
        let name = UUID().uuidString.lowercased()
        let final = dir.appendingPathComponent("\(name).json")
        let tmp = dir.appendingPathComponent(".\(name).json.tmp")
        let body: [String: Any] = ["schema": schema, "kind": "drop", "path": url.standardizedFileURL.path,
                                   "at": ISO8601DateFormatter().string(from: now), "from": "lintel"]
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .prettyPrinted])
            try data.write(to: tmp)
            try FileManager.default.moveItem(at: tmp, to: final)
        } catch {
            return Outcome(kind: .refused, producer: id, name: producer.name, reason: L("写不进收件目录", "Could not write the inbox"), file: nil)
        }
        return Outcome(kind: .handed, producer: id, name: producer.name, reason: "", file: final)
    }

    /// 面板上的一个按钮（总览 ㊺「是方法署名」）：把来源给的动作 id 原样写回那个来源的收件目录，`kind: action`。
    /// lintel 不解析 id、不判断对不对；来源只认它自己当前给出的动作。写成了返回文件，写不进返回 nil。
    @discardableResult
    public static func act(producer: String, activity: String, action: String, paths: LintelPaths, now: Date = Date()) -> URL? {
        let dir = paths.inbox(producer)
        let name = UUID().uuidString.lowercased()
        let final = dir.appendingPathComponent("\(name).json")
        let tmp = dir.appendingPathComponent(".\(name).json.tmp")
        let body: [String: Any] = ["schema": schema, "kind": "action", "activity": activity, "action": action,
                                   "at": ISO8601DateFormatter().string(from: now), "from": "lintel"]
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .prettyPrinted])
            try data.write(to: tmp)
            try FileManager.default.moveItem(at: tmp, to: final)
        } catch {
            return nil
        }
        return final
    }
}
