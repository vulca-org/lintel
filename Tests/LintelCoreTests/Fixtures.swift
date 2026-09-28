import Foundation
@testable import LintelCore

/// 测试用的临时 lintel 目录。
struct TempHome {
    let paths: LintelPaths

    init() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lintel-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        paths = LintelPaths(home: url)
    }

    func register(_ id: String = "willow", events: [String: Registry.EventSpec] = ["declaration": .init(attention: true), "choice": .init(attention: true)]) throws {
        var r = (try? Registry.load(paths)) ?? Registry()
        r.producers[id] = .init(name: id == "willow" ? "许愿柳" : id, initial: String(id.prefix(1)).uppercased(), events: events)
        try r.save(paths)
    }

    @discardableResult
    func write(_ a: Activity, producer: String = "willow", file: String? = nil) throws -> URL {
        let url = paths.activities(producer).appendingPathComponent(file ?? "\(a.id).json")
        try LintelJSON.writeAtomically(a, to: url)
        return url
    }

    func writeRaw(_ json: String, producer: String = "willow", file: String) throws -> URL {
        let dir = paths.activities(producer)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(file)
        try Data(json.utf8).write(to: url)
        return url
    }
}

let t0 = Date(timeIntervalSince1970: 1_789_700_000)

/// 每个字段都填上的一份活动：编码出来的键必须全在结构表里（Codable 与校验表不漂成两套）。
func fullActivity(id: String = "sess-a") -> Activity {
    var a = Activity(id: id)
    a.revision = "\(id)-turn"
    a.updatedAt = t0
    a.heartbeatSeconds = 60
    a.running = true
    a.inProgress = true
    a.rank = .waiting
    a.flagged = true
    a.activityAt = t0
    a.closedAt = t0
    a.group = .init(id: "/work/atlas", name: "atlas")
    a.events = [.init(id: "declaration|t1", type: "declaration", at: t0)]
    var st = Activity.Status(center: .waiting)
    st.ringRemaining = 0.46
    st.lastWriteAt = t0
    st.summary = "上下文剩 46%"
    st.bounceAt = t0
    var clock = Activity.Clock(style: .live)
    clock.since = t0; clock.seconds = 12; clock.opacity = 0.8
    st.clock = clock
    a.status = st
    a.label = .init(text: "等你选择", tone: .white)
    a.labelUntilSeen = true
    a.labelSeen = .init(text: "等你", tone: .white, count: 3)
    a.chain = .init(items: [.init(id: "L1", text: "合并 PR", state: .done, note: "main 8d68286", approved: true, idle: nil),
                            .init(id: "L2", text: "重画分镜", state: .doing, note: nil, approved: nil, idle: 6)],
                    problems: ["L9 不存在"],
                    labels: .init(done: "做完", doing: "在做", you: "等你", other: "等别的", later: "以后"),
                    error: nil)
    a.ring = .init(name: "合成稿", since: "这一轮从 2026-09-24 算起（台账只记日期，精确到日）",
                   segments: [.init(key: "comment", name: "你的意见", state: .done, sight: .seen, sightNote: "看得见", note: "做过", items: []),
                              .init(key: "design", name: "设计", state: .waiting, sight: .inferred, sightNote: "推出来", note: "等你 1",
                                    items: [.init(id: "A2", text: "风险 A2 合成标题", you: true)]),
                              .init(key: "readers", name: "读者组", state: .stale, sight: .seen, sightNote: "看得见", note: "过期",
                                    items: [.init(id: "readers", text: "读者组 · 过期", you: nil)]),
                              .init(key: "land", name: "落稿", state: .unseen, sight: .commits, sightNote: "只看得到提交", note: "看不见", items: [])],
                   current: "design", latest: "comment", latestAt: t0,
                   unhung: [.init(id: "A5", text: "风险 A5 合成标题", you: true)], waiting: 2,
                   closed: [.init(date: "2026-09-23", items: ["B1（bbbb2222）"])],
                   labels: .init(title: "这一轮", current: "当前", latest: "最近动静", unhung: "没挂上环节", closed: "已关的门", waiting: "等你"),
                   error: nil)
    var p = Activity.Pill()
    p.symbol = "questionmark.bubble.fill"; p.dot = .orange; p.tint = .blue; p.pulse = true
    p.clockSince = t0; p.title = "等你选"; p.preview = "修上传测试"
    a.pill = p
    a.pillUntilSeen = true
    var ps = Activity.Pill()
    ps.agoSince = t0
    a.pillSeen = ps
    var ears = Activity.Ears(leading: "atlas", tag: .init(text: "修上传测试", tone: .inkPrimary), phase: "等你选择")
    ears.tagSeen = .init(text: "修上传测试", tone: .inkTertiary)
    a.ears = ears
    a.popup = [.init(label: "等你", text: "重试策略用哪种？", tone: .accent, lines: 2)]
    let choice = Activity.Choice(choiceKind: .question, title: "Claude 在等你选择", countNote: "共 2 题", at: t0, question: "重试策略用哪种？",
                                 options: ["指数退避", "固定重试 3 次"], action: "回到 Claude Code 里选择")
    let tl = Activity.Timeline(startedAt: t0, endedAt: t0.addingTimeInterval(30),
                               segments: [.init(name: "写出理解前", swatch: .purple, from: nil, to: t0.addingTimeInterval(5)),
                                          .init(name: "写出理解后", swatch: .mint, from: t0.addingTimeInterval(5), to: nil)],
                               markAt: t0.addingTimeInterval(5), ticks: [t0.addingTimeInterval(8)], endLabel: "现在", sentPrefix: "回车 ")
    let steps = Activity.Steps(offset: 1, items: [.init(symbol: "terminal", text: "运行上传测试", at: t0)], startedAt: t0, live: true, limit: 2)
    a.body = [
        .section(.init(title: "你的要求", value: "09:12 · 56 字", valueTone: .orange, badge: "实时",
                       items: [.para(text: "上传测试为什么只在 CI 上挂？", tone: .inkPrimary),
                               .pending(symbol: "ellipsis", text: "思考中", clockSince: t0),
                               .iconLine(symbol: "arrow.uturn.backward", text: "你撤回了这一轮")])),
        .section(.init(title: "Claude 在做", items: [.choice(choice), .timeline(tl), .steps(steps)])),
        .stats([.init(label: "上下文", value: "412K · 41%", tone: .inkPrimary, gauge: 0.41, dots: 3)]),
    ]
    a.flip = .init(title: "修上传测试", subtitle: "atlas", phase: "等你选择")
    var d = Activity.Detail(listTitle: "修上传测试", dot: .blue,
                            history: [.init(id: "t0", at: t0, tag: "加试运行", badge: "被打断", duration: "3 分 4 秒",
                                            lines: [.init(label: "要求", text: "给上传命令加 --dry-run", tone: .inkPrimary)], expandable: true)],
                            chart: .init(title: "各轮时长", headline: "5 轮 · 中位 1 分 55 秒", bars: [.init(seconds: 184, swatch: .white85), .init(seconds: nil, swatch: .white18)],
                                         runningSince: t0, legend: [.init(name: "写了理解", swatch: .white85, count: 1)]),
                            stats: [.init(label: "最长一轮", value: "9 分")])
    d.dotSeen = .white35
    d.historyNote = "17:10–17:31 · 5 轮"
    var live = Activity.LiveTurn(at: t0, tag: "修上传测试", badge: "进行中", clockSince: t0,
                                 lines: [.init(label: "理解", text: "重写重试逻辑", tone: .orange)])
    live.choice = choice; live.timeline = tl; live.steps = steps
    d.live = live
    a.detail = d
    return a
}

/// 带总览的写作循环活动（分镜 ㊸–㊽）：两段、剖面三格、依据带走势与一个动作、还差什么两格、最近一轮。
func overviewActivity(id: String = "loop-paper") -> Activity {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    var a = Activity(id: id)
    a.rank = .event
    typealias O = Activity.Overview
    let cells = [O.Cell(id: "A", label: "摘要", chapter: "摘要", weight: 12, value: 1, mark: nil, note: "摘要 · 12 句"),
                 O.Cell(id: "I", label: "§1", chapter: "§1", weight: 85, value: 0.79, mark: nil, note: nil),
                 O.Cell(id: "Ri", label: "§5.9", chapter: "§5", weight: 7, value: 1, mark: true, note: nil)]
    let al = O.Alignment(title: "依据", note: "台账 54 行", hint: "正文各节（不含摘要）· 片段都在存档原文里", empty: nil,
                         headline: [O.Figure(value: "5", text: "句在转述文献却没绑原文", tone: .orange)],
                         caption: nil,
                         trend: O.Trend(points: [O.Point(scope: 36, done: 0, missing: 13), O.Point(scope: 55, done: 30, missing: 5)],
                                        marker: 1, markerLabel: "09-19 建台账", startLabel: "09-16", endLabel: "09-21",
                                        legend: [O.Key(name: "引用", swatch: .white45, dashed: nil, value: "55"),
                                                 O.Key(name: "缺", swatch: .orange, dashed: true, value: "13→5"),
                                                 O.Key(name: "只署名", swatch: nil, dashed: nil, value: "20")]),
                         items: [O.Item(place: "§4", tag: "缺依据", key: "z1934", text: "We report bootstrap intervals …", tone: .orange,
                                        action: O.Action(title: "是方法署名", id: "credit|z1934=report bootstrap intervals"))],
                         folded: "只署名的 20 句收起了")
    let ov = O(days: O.Days(title: "阶段", note: "08-30 → 今天 · 59 版", hint: "柱 = 那天改过或新加的句数 · 空 3 天以上就分段",
                            bars: [O.Bar(label: "08/30", value: 28, stage: 0, gapDays: nil), O.Bar(label: nil, value: nil, stage: nil, gapDays: 11),
                                   O.Bar(label: "16", value: 29, stage: 1, gapDays: nil)]),
               stages: [O.Stage(title: "08-30 – 09-04", name: nil, caption: "43 版 · 359→543 句",
                                profile: O.Profile(title: "剖面", note: "相对第一版正文", hint: nil, caption: "543 句里 393 句改过", legend: nil, cells: cells),
                                alignment: O.Alignment(title: "依据", note: nil, hint: nil, empty: "这一段还没有台账，不画这一块",
                                                       headline: nil, caption: nil, trend: nil, items: nil, folded: nil)),
                        O.Stage(title: "09-16 – 今天", name: "改投", caption: "16 版 · 543→646 句",
                                profile: O.Profile(title: "剖面", note: "相对 09-04 · 6df87aa", hint: "一格一节 · 宽 = 句数 · 高 = 这一段改过的比例",
                                                   caption: nil,
                                                   legend: [O.Key(name: "改过或新加", swatch: .indigo, dashed: nil, value: "194"),
                                                            O.Key(name: "删", swatch: nil, dashed: nil, value: "91")],
                                                   cells: cells),
                                alignment: al)],
               selected: 1,
               todo: O.Todo(title: "待办", note: nil, hint: "只对着清单算，不打总分",
                            cells: [O.TodoCell(title: "稿件仓 issue", text: "已关 1 / 共 1", value: "1/1", sub: "范围就是这 1 条", tone: nil),
                                    O.TodoCell(title: "投稿构建", text: "失败 0 项 · 标题页 6 处待填", value: "待填 6", sub: "所以还不能上传", tone: .orange)]),
               latest: O.Latest(at: t0, tag: "补出处压缩", badge: "9", place: "§7.2 · §6.2", more: "这一段 16 个改动集"))
    var turn = Activity.Turn(id: "96afd2c", at: t0, tag: "补出处压缩", badge: "9 句", duration: "96afd2c", lines: [], expandable: true)
    turn.sections = ["Lb", "Db"]
    var other = Activity.Turn(id: "7e95405", at: t0.addingTimeInterval(-3600), tag: "并入摘要引言", badge: "94 句", duration: "7e95405", lines: [], expandable: true)
    other.sections = ["A", "I"]
    other.quiet = true
    var d = Activity.Detail(listTitle: "paper · 9 句 · 已追到", dot: .indigo, history: [turn, other], chart: nil,
                            stats: [Activity.StatCell(label: "句", value: "646"), { var c = Activity.StatCell(label: "缺依据", value: "5", tone: .orange); c.hint = "台账 3 行 · 证据 2 份"; return c }(),
                                    Activity.StatCell(label: "上下文", value: "18%", gauge: 0.18, series: [0.1, 0.9, 0.18])])
    d.overview = ov
    a.detail = d
    a.updatedAt = t0
    return a
}
