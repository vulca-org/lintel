import AppKit
import Foundation
import LintelCore
import LintelUI

/// lintel 命令行。
///   lintel register <id> --name <名字> --initial <字母> [--shape circle|bracket] [--tint <调色板色>] [--accepts folder] [--event <类型>[:attention][:dismiss=<秒>]]…
///   lintel validate [<活动文件>…]      不给文件就校验全部来源程序目录
///   lintel schema                      打印活动格式 v1 的结构表（Markdown）
///   lintel paths                       打印目录位置
///   lintel import-seen <id> <seen.json> 把来源程序原来记的「看过哪一版」搬进来（切换时用一次）
///   lintel [host] [--log] [--present <秒> [--passive] [--backdrop] [演示开关…]]   宿主：画刘海
///     --log：把「为什么弹出、为什么换一张、为什么收起」写到 stderr（试用时用来回查）
let args = Array(CommandLine.arguments.dropFirst())
let paths = LintelPaths.default()

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("lintel: \(msg)\n".utf8))
    exit(2)
}

func value(_ flag: String, in xs: [String]) -> [String] {
    var out: [String] = []
    var i = 0
    while i < xs.count {
        if xs[i] == flag, i + 1 < xs.count { out.append(xs[i + 1]); i += 2 } else { i += 1 }
    }
    return out
}

switch args.first {
case "register":
    guard args.count >= 2 else { fail("用法：lintel register <id> --name <名字> --initial <字母> [--shape circle|bracket] [--tint 调色板色] [--event 类型[:attention][:dismiss=秒]]") }
    let id = args[1]
    guard Registry.isValidProducerId(id) else { fail("来源程序 id 只能是小写字母、数字、连字符（1–32 个字符）：\(id)") }
    guard let name = value("--name", in: args).first else { fail("缺 --name") }
    let initial = value("--initial", in: args).first ?? String(name.prefix(1)).uppercased()
    var mark: Registry.Mark? = nil
    if let shapeName = value("--shape", in: args).first {
        guard let shape = Registry.Mark.Shape(rawValue: shapeName) else {
            fail("--shape 只能是 \(Registry.Mark.Shape.allCases.map(\.rawValue).joined(separator: " / "))：\(shapeName)")
        }
        var tint: Swatch? = nil
        if let tintName = value("--tint", in: args).first {
            guard let sw = Swatch(rawValue: tintName) else {
                fail("--tint 要用调色板里的名字（\(Swatch.allCases.map(\.rawValue).joined(separator: " "))）：\(tintName)")
            }
            tint = sw
        }
        mark = .init(shape: shape, tint: tint)
    }
    var events: [String: Registry.EventSpec] = [:]
    for spec in value("--event", in: args) {
        let parts = spec.split(separator: ":").map(String.init)
        guard let type = parts.first, !type.isEmpty else { fail("事件写法：类型[:attention][:dismiss=秒]") }
        let attention = parts.contains("attention")
        let dismiss = parts.first { $0.hasPrefix("dismiss=") }.flatMap { Double($0.dropFirst(8)) }
        events[type] = .init(attention: attention, dismissExpandedAfter: dismiss)
    }
    let accepts = value("--accepts", in: args)
    for a in accepts where a != Drop.folder { fail("--accepts 目前只有 \(Drop.folder)：\(a)") }
    var r = (try? Registry.load(paths)) ?? Registry()
    let existed = r.producers[id] != nil
    r.producers[id] = .init(name: name, initial: initial, events: events, nouns: r.producers[id]?.nouns, mark: mark ?? r.producers[id]?.mark,
                            accepts: accepts.isEmpty ? r.producers[id]?.accepts : accepts)
    do { try r.save(paths) } catch { fail("写不进 \(paths.registry.path)：\(error)") }
    try? FileManager.default.createDirectory(at: paths.activities(id), withIntermediateDirectories: true)
    print("\(existed ? "更新" : "登记")了 \(id)（\(name)），事件 \(events.keys.sorted())；活动写到 \(paths.activities(id).path)")

case "validate":
    let files = Array(args.dropFirst())
    let registry = try? Registry.load(paths)
    var bad = 0, good = 0
    func report(_ producer: String, _ url: URL) {
        let registered = registry?.producers[producer].map { Set($0.events.keys) }
        guard let data = try? Data(contentsOf: url) else { print("  ✗ \(url.path)：读不到"); bad += 1; return }
        let (_, rejects) = Validation.check(data: data, producer: producer, file: url.lastPathComponent, registered: registered)
        if rejects.isEmpty { good += 1; return }
        bad += 1
        for r in rejects { print("  ✗ \(producer)/\(r.file) \(r.path.isEmpty ? "" : r.path + "：")\(r.reason)") }
    }
    if files.isEmpty {
        let s = Scanner.scan(paths)
        for i in s.issues where i.kind != .rejected { print("  ⚠ \(i.text)") }
        for r in s.rejects { print("  ✗ \(r.producer)/\(r.file) \(r.path.isEmpty ? "" : r.path + "：")\(r.reason)") }
        good = s.activities.count
        bad = Set(s.rejects.map { "\($0.producer)/\($0.file)" }).count
    } else {
        for f in files {
            let url = URL(fileURLWithPath: f)
            // 来源程序由目录决定：…/producers/<id>/activities/<文件>
            let parts = url.standardizedFileURL.pathComponents
            guard let i = parts.lastIndex(of: "activities"), i >= 2, parts[i - 2] == "producers" else {
                print("  ✗ \(f)：不在 producers/<id>/activities/ 下，判不出来源程序"); bad += 1; continue
            }
            report(parts[i - 1], url)
        }
    }
    print("validate：接受 \(good)，拒收 \(bad)")
    exit(bad == 0 ? 0 : 1)

case "schema":
    print(Validation.describe())

case "paths":
    print("home      \(paths.home.path)\nregistry  \(paths.registry.path)\nproducers \(paths.producers.path)\nstate     \(paths.state.path)")

case "import-seen":
    // 切换时把许愿柳记下的「看过哪一轮」搬进 lintel，免得切过来那一刻所有已结束的会话都变回「没看过」、两翼一起亮。
    // 用法：lintel import-seen <来源程序 id> <许愿柳 seen.json>（许愿柳的在 ~/Library/Application Support/WishingWillow/seen.json）
    guard args.count >= 3 else { fail("用法：lintel import-seen <来源程序 id> <seen.json>") }
    guard let data = FileManager.default.contents(atPath: args[2]),
          let map = try? JSONDecoder().decode([String: String].self, from: data) else { fail("读不懂 \(args[2])（应为 会话 id → 轮次 id 的对象）") }
    var current = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: paths.seen))) ?? [:]
    var added = 0
    for (sid, rev) in map where current["\(args[1])/\(sid)"] == nil {
        current["\(args[1])/\(sid)"] = rev
        added += 1
    }
    do {
        try LintelJSON.writeAtomically(try JSONEncoder().encode(current), to: paths.seen)
    } catch { fail("写不进 \(paths.seen.path)：\(error)") }
    print("import-seen：\(map.count) 条里新加 \(added) 条（已有的不覆盖）→ \(paths.seen.path)")

case nil, "host":
    Host.run(arguments: args)

case let flag? where flag.hasPrefix("--"):
    Host.run(arguments: args)

default:
    fail("命令：register / validate / schema / paths / import-seen / host")
}
