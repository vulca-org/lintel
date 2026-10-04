import Foundation

/// 一项活动：来源程序写进 `producers/<来源 id>/activities/<活动 id>.json` 的全部内容。
///
/// 来源程序只交数据，不画界面。字段是从许愿柳 f4d6690 的界面代码逐项拆出来的（`docs/baseline/inventory.md` 的「拆分」类）：
/// 许愿柳原来在视图里现算的文字、语气、该用哪种排法，改由来源程序算好写进来；
/// 随时间走的东西（计时、结束了多久、时间轴的「现在」、圆心扇形的新鲜度）只给时刻，由 lintel 现算；
/// 依赖「你看过没有」的地方，来源程序写出两种写法或一个开关，看没看过由 lintel 记。
///
/// 来源是谁由文件所在目录决定；内容里没有、也不许有「我是谁」的字段（校验时拒收）。
public struct Activity: Codable, Sendable, Equatable, Identifiable {
    public var schema: Int
    /// 与文件名（去掉 .json）相同。
    public var id: String
    /// 看过是按「活动 id + 版本」记的。许愿柳：一轮一个版本（turnId）。没有版本的活动永远算看过。
    public var revision: String?
    /// 来源那边这份数据的时刻（许愿柳：状态文件的 updatedAt，面板里「几分钟前」按它算）。
    public var updatedAt: Date?
    /// 来源程序承诺多久至少重写一次；超过 1.5 倍没动静，lintel 显示异常（L4）。
    public var heartbeatSeconds: Double?

    // MARK: 生命周期与排序（lintel 的排序与配对只看这几个字段，见 Ordering）

    /// 来源那头还开着（许愿柳：会话进程还在、没有 endedAt）。
    public var open: Bool
    /// 在跑（许愿柳：这一轮没结束）。同一来源程序里「在跑 / 空闲」的计数由 lintel 按它数。
    public var running: Bool
    /// 过期：不再上刘海，只在面板里。
    public var stale: Bool
    /// 正在进行（许愿柳：declaration == .inProgress）。决定胶囊人选与收起后轮到谁。
    public var inProgress: Bool
    public var rank: Rank
    /// 来源程序转发的「自己标了不一致」（许愿柳：理解行以 ⚠ 开头）。不是 lintel 的判定。
    public var flagged: Bool
    /// 最近一次动静，排序用。
    public var activityAt: Date?
    /// 这件事的名字，不随每一轮变（许愿柳：Claude 桌面端给这场对话起的标题）。侧栏、窗口与弹出框的标题用它；
    /// 右翼的标签仍是这一轮在做什么。09-27 grill 4：侧栏里同一场对话每轮换一个名字（名字是最近一轮的标签）。
    public var name: String?
    /// 关掉的时刻，面板里已关闭一组按它排。
    public var closedAt: Date?
    public var group: Group?
    public var events: [Event]

    // MARK: 收起态

    public var status: Status?
    /// 右翼标签。没有 = 缩回刘海。
    public var label: Label?
    /// true：你看过这一版之后右翼缩回刘海。
    public var labelUntilSeen: Bool
    /// 看过之后右翼换成这个（`labelUntilSeen` 为 true 时才用）；没有 = 看过就缩回。
    /// 许愿柳：长清单里有等你的事时，看过之后右翼写「等你」加数，常驻（åé¨ spec 2026-09-24 对话层 V2）。
    public var labelSeen: Label?
    /// 作为第二项时的极简胶囊。
    public var pill: Pill?
    public var pillUntilSeen: Bool
    /// 看过之后胶囊换成这个（`pillUntilSeen` 为 true 时才用）；没有 = 看过就撤。
    /// 写作循环：看过之后只剩括号加「几时前」（作者 2026-09-22）。
    public var pillSeen: Pill?

    // MARK: 展开态

    public var ears: Ears?
    /// 主动弹出的精简版：两三行。
    public var popup: [PopupLine]
    /// 悬停展开的完整版：分节与数据条。
    public var body: [Block]
    /// 它作为「翻页行」目标时怎么写。
    public var flip: Flip?

    /// 展开态按 body[] 里的 section 分页（候选 E，作者 09-21 定「悬停点点」）。缺省不分页，许愿柳不变。
    public var paged: Bool?

    // MARK: 点击面板

    public var detail: Detail?

    // MARK: 对话的长清单

    /// 整场对话的长清单（åé¨ spec 2026-09-24 对话层 V1–V6，lintel 分镜 ⑦④ ⑦⑦ ⑦⑨）。字由来源写好；
    /// 宿主画收起态左翼的状态方块、展开卡最上面的「此刻」、面板右栏的整张。
    public var chain: Chain?

    // MARK: 稿件的环

    /// 一篇稿件这一轮走到哪（åé¨ spec 2026-09-24 W1–W4，加「设计」一环；lintel 分镜 ⑦⑥ ⑦⑧ ⑧⓪）。字由来源写好；
    /// 宿主画胶囊前的环形小图标、展开卡最上面的一行七格、面板顶上的整条环。
    public var ring: Ring?

    // MARK: 嵌套

    /// 这件活动嵌在哪几件别的活动里（作者 09-24：写作循环的一份稿件嵌在正在改它的对话里，不该像两个平行的 app）。
    /// 有一件开着，宿主就把它画进那一件、不再单独占位子；一件都不在，照旧单独画。
    public var within: [Link]?

    public init(id: String) {
        schema = 1
        self.id = id
        open = true
        running = false
        stale = false
        inProgress = false
        rank = .none
        flagged = false
        events = []
        labelUntilSeen = false
        pillUntilSeen = false
        popup = []
        body = []
    }
}

extension Activity {
    /// 排序分层。只有四种：异常 > 等你 > 刚发生的事（例如撤回，只停几秒）> 其他。
    public struct Chain: Codable, Sendable, Equatable {
        public enum State: String, Codable, Sendable, CaseIterable { case done, doing, you, other, later }
        public struct Item: Codable, Sendable, Equatable, Identifiable {
            public var id: String
            public var text: String
            public var state: State
            /// 注：证据（提交号、CI）或依据；预测不带注（作者 09-24）。
            public var note: String?
            public var approved: Bool?
            /// 「在做」几轮没动（来源只在 ≥5 时写）。
            public var idle: Int?
            /// 旧写法（09-27 grill 1 到第二轮之间）：来源把「现在要你做什么」放进 text、建项原句挪到这里。
            /// 新来源不写它，改写 now；宿主读到只有 was 的项，按「was 是标题、text 是现在那句」读（见 title / current）。
            public var was: String?
            /// 现在要做什么的那一句（最近一次转状态时写的）。标题仍在 text：09-27 grill 第二轮 N3，
            /// 说明句多是增量写法（「4 已修已装……」），离开标题读不懂。
            public var now: String?
            /// 「等别的」在等什么（CI、回信、额度）。单独一栏，和 now 各管各的（第二轮 N2：有了 now，等什么就被顶掉了）。
            public var wait: String?
            /// 它一落地就能放开的项（本对话的编号）或外部的事（投稿）（09-28 spec「清单与下一步的分工」D1）。
            public var blocks: [String]?
            /// 作者在面板里可以直接点的动作（09-28 spec「清单实时」C）：第一个画成可点的复选框，全部进右键菜单。
            /// lintel 不解析 id，点了原样写回来源的收件目录（`kind: action`），由来源决定做不做。
            public var actions: [Action]?

            public struct Action: Codable, Sendable, Equatable, Hashable {
                public var id: String
                public var title: String
                public init(id: String, title: String) { self.id = id; self.title = title }
            }

            /// 这一项是什么：主行。
            public var title: String { now == nil ? (was ?? text) : text }
            /// 现在要做什么：第二行；没有就不画。
            public var current: String? { now ?? (was == nil ? nil : text) }
        }
        /// 分组名，来源按界面语言写好。
        public struct Labels: Codable, Sendable, Equatable {
            public var done: String
            public var doing: String
            public var you: String
            public var other: String
            public var later: String
        }
        public var items: [Item]
        public var problems: [String]
        public var labels: Labels
        /// 清单读不出时的一句；有它时 items 为空，不能读成「没有开着的事」。
        public var error: String?
    }

    /// 指向另一件活动：来源 id 加活动 id；role 是那一场对话和这份稿件的关系（主会话 / 历史会话）。
    public struct Link: Codable, Sendable, Equatable {
        public enum Role: String, Codable, Sendable, CaseIterable { case primary, history }
        public var producer: String
        public var id: String
        public var role: Role?
        public init(producer: String, id: String, role: Role? = nil) { self.producer = producer; self.id = id; self.role = role }
        /// 宿主里那件活动的 id（`来源/活动`）。
        public var hostedId: String { "\(producer)/\(id)" }
    }

    /// 稿件的环：一轮改稿分成几环，每环的状态、看不看得见、挂着的事；另有当前环、最近动静、没挂上环节的事、已关的门。
    public struct Ring: Codable, Sendable, Equatable {
        /// 等你（台账里要作者裁的事挂在这环）、过期（检查或读者组比稿子旧）、做过、还没到、看不见（这一环引擎只能推断）。
        public enum State: String, Codable, Sendable, CaseIterable { case waiting, stale, done, open, unseen }
        /// 看得见、推出来（从作者凭 uuid 关的门推断）、只看得到提交。
        public enum Sight: String, Codable, Sendable, CaseIterable { case seen, inferred, commits }
        public struct Item: Codable, Sendable, Equatable, Identifiable {
            public var id: String
            public var text: String
            /// 要作者裁的（台账条目）；过期的检查不是。
            public var you: Bool?
            /// 最近一次进展的日期（台账里这一项最后一行「进展：」的日期，写法照台账，如 09-24）；没有就不写。刘海用它说「挂了多久」。
            public var moved: String?
            /// 第二行：要做什么、由哪个门决定（台账的「消除它的证据」「由哪个门决定」）。09-27 面板 grill 14：
            /// 只有标题的台账条目离开台账读不懂，看不出要你裁什么。
            public var detail: String?
        }
        public struct Segment: Codable, Sendable, Equatable, Identifiable {
            public var key: String
            public var name: String
            public var state: State
            public var sight: Sight
            /// 「看得见」「推出来」「只看得到提交」，来源按界面语言写好。
            public var sightNote: String
            /// 格子里那一小句：「等你 1」「过期」「做过」「还没到」「看不见」。
            public var note: String
            public var items: [Item]
            public var id: String { key }
        }
        public struct Gate: Codable, Sendable, Equatable {
            public var date: String
            public var items: [String]
        }
        public struct Labels: Codable, Sendable, Equatable {
            public var title: String
            public var current: String
            public var latest: String
            public var unhung: String
            public var closed: String
            public var waiting: String
        }
        /// 稿名。
        public var name: String?
        /// 这一轮从哪算起、精度到哪（「这一轮从 09-24 算起（台账只记日期，精确到日）」）。
        public var since: String
        public var segments: [Segment]
        public var current: String?
        public var latest: String?
        public var latestAt: Date?
        /// 这一轮最远做到哪一环（有动静落在这一轮里的环里最靠后的那个）。与 current（等你的第一环）、latest（最后动的那环）不同：
        /// 作者 09-24 问「为什么还在设计这个阶段」——当前被一条旧未决钉在设计，最近动静是一条评论，都说不出做到哪。
        public var reached: String?
        /// 冻结期（稿件只收正确性）读者组过期时的那一句（「冻结期不重读（改动 12 处）」）：说出来，但不挂成要重跑。
        public var frozenNote: String?
        /// 逐段改稿时航线上方那一句（「第 2/7 部分：相关工作（已落 1）」）：环这时是当前这一部分的几步。
        public var progress: String?
        public var unhung: [Item]
        public var waiting: Int
        public var closed: [Gate]
        public var labels: Labels
        public var error: String?
    }

    public enum Rank: String, Codable, Sendable, CaseIterable {
        case anomaly, waiting, event, none
    }

    /// 同组的活动在面板「已关闭」里合并。`id` 用完整路径：同名不同路径不合并。
    public struct Group: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public init(id: String, name: String) { self.id = id; self.name = name }
    }

    /// 来源程序声明的时刻。事件类型必须在登记里；登记为「需要你注意」的才会让 lintel 主动展开。
    /// lintel 按 `id` 去重：启动时已经在文件里的事件不展开（没人刚看到它发生）。
    public struct Event: Codable, Sendable, Equatable {
        public var id: String
        public var type: String
        public var at: Date?
        public init(id: String, type: String, at: Date?) { self.id = id; self.type = type; self.at = at }
    }

    /// 左翼：合一状态图标加一个真在走的数。
    public struct Status: Codable, Sendable, Equatable {
        public var center: Center
        /// 外圈弧：还剩多少（0…1）。没有数据时只画暗轨道。
        public var ringRemaining: Double?
        /// 圆心扇形的新鲜度按它现算（10 秒 / 1 分 / 5 分三档）。
        public var lastWriteAt: Date?
        /// 悬停提示里的一句话。
        public var summary: String?
        /// 变了就让图标弹一下（许愿柳：撤回的时刻）。
        public var bounceAt: Date?
        public var clock: Clock?
        public init(center: Center) { self.center = center }
    }

    /// 圆心词表（宿主统一，来源程序只能从中选）。
    ///
    /// 前七个来自许愿柳。后两个是 2026-09-17 为 awt-loop 加的：它要显示的两件事在别的词里会消失——
    /// `superseded` 是「你批准过，但那以后文字又改了」，`assumed` 是「这一项是我替你定的，你还没确认」。
    /// 都挤进 `flagged` 的话，真正的异常和「等你看一眼」就长得一样了。
    public enum Center: String, Codable, Sendable, CaseIterable {
        case live, waiting, done, flagged, broken, withdrawn, idle
        case superseded, assumed
    }

    public struct Clock: Codable, Sendable, Equatable {
        public enum Style: String, Codable, Sendable { case live, ago, frozen }
        public var style: Style
        /// live：从这一刻开始走；ago：从这一刻算「结束了多久」。
        public var since: Date?
        /// frozen：停住的秒数（许愿柳：打断时停在撤回那一刻，划掉）。
        public var seconds: Double?
        /// live 的亮度。
        public var opacity: Double?
        public init(style: Style) { self.style = style }
    }

    public struct Label: Codable, Sendable, Equatable {
        public var text: String
        public var tone: Swatch
        /// 右翼字后面的小数字（channel-separation §5：一个表面一个数，字里不再有数）。
        public var count: Int?
        public init(text: String, tone: Swatch, count: Int? = nil) { self.text = text; self.tone = tone; self.count = count }
    }

    /// 极简胶囊：一个符号或圆点，加一个计时或两三个字。
    public struct Pill: Codable, Sendable, Equatable {
        public var symbol: String?
        public var dot: Swatch?
        public var tint: Swatch?
        public var pulse: Bool
        public var clockSince: Date?
        /// 「几时前」：从这一刻算起过了多久，画成「3 时」，不走秒。与 `clockSince`（走动的计时）二选一。
        public var agoSince: Date?
        public var title: String?
        /// 鼠标停在胶囊上时向右长出来的那段字（lintel 在后面接「· N 个在跑」）。
        public var preview: String?
        public init() { pulse = false }
    }

    /// 展开态刘海两侧：左耳工作区名（合一图标在它右边，用 status），右耳标签 … 阶段词。
    public struct Ears: Codable, Sendable, Equatable {
        public var leading: String
        public var tag: Label
        /// 看过之后右耳标签换成这个；没有 = 不变。
        public var tagSeen: Label?
        public var phase: String
        public init(leading: String, tag: Label, phase: String) { self.leading = leading; self.tag = tag; self.phase = phase }
    }

    public struct PopupLine: Codable, Sendable, Equatable {
        public enum Tone: String, Codable, Sendable { case primary, secondary, warning, accent, quiet }
        public var label: String
        public var text: String
        public var tone: Tone
        public var lines: Int
        public init(label: String, text: String, tone: Tone, lines: Int) { self.label = label; self.text = text; self.tone = tone; self.lines = lines }
    }

    public struct Flip: Codable, Sendable, Equatable {
        public var title: String
        public var subtitle: String
        public var phase: String
        public init(title: String, subtitle: String, phase: String) { self.title = title; self.subtitle = subtitle; self.phase = phase }
    }
}

// MARK: - 内容块

extension Activity {
    public enum Block: Codable, Sendable, Equatable {
        case section(Section)
        case stats([StatCell])

        private enum K: String, CodingKey { case kind, section, cells }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            switch try c.decode(String.self, forKey: .kind) {
            case "section": self = .section(try Section(from: decoder))
            case "stats": self = .stats(try c.decode([StatCell].self, forKey: .cells))
            case let k: throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "未知内容块 \(k)")
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: K.self)
            switch self {
            case .section(let s):
                try c.encode("section", forKey: .kind)
                try s.encode(to: encoder)
            case .stats(let cells):
                try c.encode("stats", forKey: .kind)
                try c.encode(cells, forKey: .cells)
            }
        }
    }

    /// 分节：左边标题、右边一个可以核对的数，下面若干项。
    public struct Section: Codable, Sendable, Equatable {
        public var title: String
        public var value: String?
        public var valueTone: Swatch?
        public var badge: String?
        public var items: [Item]
        public init(title: String, value: String? = nil, valueTone: Swatch? = nil, badge: String? = nil, items: [Item]) {
            self.title = title; self.value = value; self.valueTone = valueTone; self.badge = badge; self.items = items
        }
    }

    public enum Item: Codable, Sendable, Equatable {
        /// 正文，13pt，最多两行。
        case para(text: String, tone: Swatch)
        /// 还没有结果：跳动的符号、一句状态、右侧走动的计时。
        case pending(symbol: String, text: String, clockSince: Date?)
        /// 一个符号加一句话（许愿柳：你撤回了这一轮）。
        case iconLine(symbol: String, text: String)
        case choice(Choice)
        case timeline(Timeline)
        case steps(Steps)
        /// 一句改前改后，宿主只画动了的词（分镜 ㊱，作者 09-21）。old 缺 = 新增的句子。
        case diff(label: String, old: String?, new: String)

        private enum K: String, CodingKey { case kind, text, tone, symbol, clockSince, label, old, new }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            switch try c.decode(String.self, forKey: .kind) {
            case "para": self = .para(text: try c.decode(String.self, forKey: .text), tone: try c.decode(Swatch.self, forKey: .tone))
            case "pending": self = .pending(symbol: try c.decode(String.self, forKey: .symbol), text: try c.decode(String.self, forKey: .text),
                                            clockSince: try c.decodeIfPresent(Date.self, forKey: .clockSince))
            case "iconLine": self = .iconLine(symbol: try c.decode(String.self, forKey: .symbol), text: try c.decode(String.self, forKey: .text))
            case "choice": self = .choice(try Choice(from: decoder))
            case "timeline": self = .timeline(try Timeline(from: decoder))
            case "steps": self = .steps(try Steps(from: decoder))
            case "diff": self = .diff(label: try c.decode(String.self, forKey: .label), old: try c.decodeIfPresent(String.self, forKey: .old),
                                     new: try c.decode(String.self, forKey: .new))
            case let k: throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "未知项 \(k)")
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: K.self)
            switch self {
            case .para(let text, let tone):
                try c.encode("para", forKey: .kind); try c.encode(text, forKey: .text); try c.encode(tone, forKey: .tone)
            case .pending(let symbol, let text, let since):
                try c.encode("pending", forKey: .kind); try c.encode(symbol, forKey: .symbol); try c.encode(text, forKey: .text)
                try c.encodeIfPresent(since, forKey: .clockSince)
            case .iconLine(let symbol, let text):
                try c.encode("iconLine", forKey: .kind); try c.encode(symbol, forKey: .symbol); try c.encode(text, forKey: .text)
            case .choice(let x): try c.encode("choice", forKey: .kind); try x.encode(to: encoder)
            case .timeline(let x): try c.encode("timeline", forKey: .kind); try x.encode(to: encoder)
            case .steps(let x): try c.encode("steps", forKey: .kind); try x.encode(to: encoder)
            case .diff(let label, let old, let new):
                try c.encode("diff", forKey: .kind); try c.encode(label, forKey: .label); try c.encodeIfPresent(old, forKey: .old); try c.encode(new, forKey: .new)
            }
        }
    }

    /// 数据条的一格。gauge：细胶囊表示已用多少（0…1）；dots：四个点亮几个。
    public struct StatCell: Codable, Sendable, Equatable {
        public var label: String
        public var value: String
        public var tone: Swatch?
        public var gauge: Double?
        public var dots: Int?
        /// 走势线（分镜 53）：一点一轮，0…1，旧 → 新；有它就画折线不画量表。
        public var series: [Double]?
        /// 悬停说明（C7）：这一格背后是哪几项，例如「有发现」列检查的名字与一句结果。第一页只放数字，说明进悬停。
        public var hint: String?
        public init(label: String, value: String, tone: Swatch? = nil, gauge: Double? = nil, dots: Int? = nil, series: [Double]? = nil) {
            self.label = label; self.value = value; self.tone = tone; self.gauge = gauge; self.dots = dots; self.series = series
        }
    }

    /// 等你做选择的卡片。lintel 不替你选，只负责把你叫回来源程序。
    public struct Choice: Codable, Sendable, Equatable {
        public enum Kind: String, Codable, Sendable { case question, plan }
        public var choiceKind: Kind
        public var title: String
        public var countNote: String?
        public var at: Date?
        public var question: String?
        public var options: [String]
        public var action: String
        public init(choiceKind: Kind, title: String, countNote: String?, at: Date?, question: String?, options: [String], action: String) {
            self.choiceKind = choiceKind; self.title = title; self.countNote = countNote; self.at = at
            self.question = question; self.options = options; self.action = action
        }
    }

    /// 一段时间轴：分段胶囊、工具调用细缝、一个圆点标记、刻度与图例。比例由 lintel 按「现在」现算。
    public struct Timeline: Codable, Sendable, Equatable {
        public struct Segment: Codable, Sendable, Equatable {
            public var name: String
            public var swatch: Swatch
            /// nil = 从头。
            public var from: Date?
            /// nil = 到尾（进行中就是「现在」）。
            public var to: Date?
            /// true：按比例算出来这一段为空（起点不在终点之前）时，不画这一段、图例里也不写，前一段一直延伸到这一段的终点。
            /// 许愿柳「写出理解后」那一段就是这样：它按比例（截到 0…1）判断要不要分段，不按时刻先后——
            /// 理解写出的时刻落在这一轮结束之后时，比例截成 1，不分段（2026-09-17 状态比对抓到按时刻判断会多出「写出理解后 0:00」）。
            public var mergeIfEmpty: Bool?
            public init(name: String, swatch: Swatch, from: Date?, to: Date?, mergeIfEmpty: Bool? = nil) {
                self.name = name; self.swatch = swatch; self.from = from; self.to = to; self.mergeIfEmpty = mergeIfEmpty
            }
        }
        public var startedAt: Date
        /// nil = 还在进行。
        public var endedAt: Date?
        public var segments: [Segment]
        public var markAt: Date?
        public var ticks: [Date]
        /// 右端写的词（现在 / 结束 / 撤回）。
        public var endLabel: String
        /// 图例末尾「回车 09:12:03」的前缀；nil = 只写时刻。
        public var sentPrefix: String?
        public init(startedAt: Date, endedAt: Date?, segments: [Segment], markAt: Date?, ticks: [Date], endLabel: String, sentPrefix: String?) {
            self.startedAt = startedAt; self.endedAt = endedAt; self.segments = segments; self.markAt = markAt
            self.ticks = ticks; self.endLabel = endLabel; self.sentPrefix = sentPrefix
        }
    }

    public struct Steps: Codable, Sendable, Equatable {
        public struct Step: Codable, Sendable, Equatable {
            public var symbol: String
            public var text: String
            public var at: Date?
            public init(symbol: String, text: String, at: Date?) { self.symbol = symbol; self.text = text; self.at = at }
        }
        /// 第一项在整轮步骤里的下标（步骤只追加，下标就是身份）。
        public var offset: Int
        public var items: [Step]
        public var startedAt: Date
        public var live: Bool
        public var limit: Int
        public init(offset: Int, items: [Step], startedAt: Date, live: Bool, limit: Int) {
            self.offset = offset; self.items = items; self.startedAt = startedAt; self.live = live; self.limit = limit
        }
    }
}

// MARK: - 点击面板

extension Activity {
    public struct Detail: Codable, Sendable, Equatable {
        /// 左栏一行的标题。
        public var listTitle: String
        public var dot: Swatch
        /// 看过之后圆点换成这个；没有 = 不变。
        public var dotSeen: Swatch?
        /// 右栏标题旁的一句（时间范围 · 几轮）。
        public var historyNote: String?
        /// 新 → 旧。
        public var history: [Turn]
        public var live: LiveTurn?
        /// 时长直方图（许愿柳）。稿件类来源没有时长，不写（09-21 起可选）。
        public var chart: Chart?
        /// 进度条：一格一件事（写作循环：一格一个改动集，旧 → 新），只有颜色，超过 60 格宿主缩格（作者 09-21）。
        public var strip: Strip?
        public var stats: [StatCell]
        /// 点进去的第一层：整份稿子按阶段走到哪（分镜 ㊸–㊽，作者 09-21）。有它时宿主先画总览，`history` 退到第二层。
        public var overview: Overview?
        public init(listTitle: String, dot: Swatch, history: [Turn], chart: Chart?, stats: [StatCell]) {
            self.listTitle = listTitle; self.dot = dot; self.history = history; self.chart = chart; self.stats = stats
        }
    }

    public struct Strip: Codable, Sendable, Equatable {
        public var title: String
        public var cells: [Swatch]
        public var legend: [Chart.Key]
        public init(title: String, cells: [Swatch], legend: [Chart.Key]) { self.title = title; self.cells = cells; self.legend = legend }
    }

    public struct Line: Codable, Sendable, Equatable {
        public var label: String
        public var text: String
        public var tone: Swatch
        public init(label: String, text: String, tone: Swatch) { self.label = label; self.text = text; self.tone = tone }
    }

    /// 一条改动集点开后的一行：改的是哪句、在哪、拿去贴的定位、改前改后（候选 A，作者 09-21 定「面板里看 + 复制定位」）。
    public struct Row: Codable, Sendable, Equatable {
        public var label: String
        /// 「节 · 第 N 段 · 文件:行」，显示用。JSON 里叫 where。
        public var place: String?
        /// 点复制按钮放进剪贴板的字。
        public var copy: String?
        public var old: String?
        public var new: String
        enum CodingKeys: String, CodingKey { case label, place = "where", copy, old, new }
        public init(label: String, place: String?, copy: String?, old: String?, new: String) {
            self.label = label; self.place = place; self.copy = copy; self.old = old; self.new = new
        }
    }

    public struct Turn: Codable, Sendable, Equatable, Identifiable {
        public var id: String
        public var at: Date?
        public var tag: String?
        public var badge: String?
        /// 右侧写的用时（已经格式化）。
        public var duration: String?
        public var lines: [Line]
        public var expandable: Bool
        /// 点开之后多出来的定位行（候选 A）；没有就只有 lines。
        public var rows: [Row]?
        /// 这一条碰过的节（总览剖面格的 id）；第二层按节筛时用（分镜 ㊻）。
        public var sections: [String]?
        /// 这一轮不是你说的（许愿柳：后台任务通知等系统消息开始的一轮）。宿主画成一行细条，不占整张卡（09-28 面板 grill 第三轮 R3）。
        public var quiet: Bool?
        public init(id: String, at: Date?, tag: String?, badge: String?, duration: String?, lines: [Line], expandable: Bool) {
            self.id = id; self.at = at; self.tag = tag; self.badge = badge; self.duration = duration; self.lines = lines; self.expandable = expandable
        }
    }

    public struct LiveTurn: Codable, Sendable, Equatable {
        public var at: Date?
        public var tag: String?
        public var badge: String
        public var clockSince: Date?
        public var lines: [Line]
        public var choice: Choice?
        public var timeline: Timeline?
        public var steps: Steps?
        public init(at: Date?, tag: String?, badge: String, clockSince: Date?, lines: [Line]) {
            self.at = at; self.tag = tag; self.badge = badge; self.clockSince = clockSince; self.lines = lines
        }
    }

    /// 对数纵轴（1 秒 … 1 小时）的柱状图，图例带计数。
    public struct Chart: Codable, Sendable, Equatable {
        public struct Bar: Codable, Sendable, Equatable {
            public var seconds: Double?
            public var swatch: Swatch
            /// 柱下写的时刻（分镜 52，只写第一根与最后一根）。
            public var label: String?
            /// 悬停这根柱出的小卡。
            public var note: String?
            public init(seconds: Double?, swatch: Swatch, label: String? = nil, note: String? = nil) {
                self.seconds = seconds; self.swatch = swatch; self.label = label; self.note = note
            }
        }
        public struct Key: Codable, Sendable, Equatable {
            public var name: String
            public var swatch: Swatch
            public var count: Int
            public init(name: String, swatch: Swatch, count: Int) { self.name = name; self.swatch = swatch; self.count = count }
        }
        public var title: String
        public var headline: String
        public var bars: [Bar]
        public var runningSince: Date?
        public var legend: [Key]
        /// 标题悬停出的说明（「对数纵轴」这类怎么读的话，不占版面；分镜 52）。
        public var hint: String?
        public init(title: String, headline: String, bars: [Bar], runningSince: Date?, legend: [Key]) {
            self.title = title; self.headline = headline; self.bars = bars; self.runningSince = runningSince; self.legend = legend
        }
    }
}

// MARK: - 总览（分镜 ㊸–㊽）

extension Activity {
    /// 整份稿子的总览。字都是来源写好的；宿主只排版：阶段条、剖面、依据、还差什么、最近一轮。
    public struct Overview: Codable, Sendable, Equatable {
        public struct Days: Codable, Sendable, Equatable {
            public var title: String
            public var note: String?
            /// 标题悬停出的说明（怎么读这张图；分镜 ㊿）。下同。
            public var hint: String?
            public var bars: [Bar]
        }
        /// 一天一根柱；`gapDays` 有值时是折起来的一段空档（不画柱，写「⋯ N 天 ⋯」）。
        public struct Bar: Codable, Sendable, Equatable {
            public var label: String?
            public var value: Int?
            public var stage: Int?
            public var gapDays: Int?
        }
        public struct Stage: Codable, Sendable, Equatable {
            public var title: String
            /// 作者在登记表里起的名字；没有就只写日期。
            public var name: String?
            public var caption: String
            public var profile: Profile
            public var alignment: Alignment?
        }
        /// 剖面：一格一节，宽按 weight（句数），高按 value（改过的比例，0…1）。
        public struct Profile: Codable, Sendable, Equatable {
            public var title: String
            public var note: String?
            public var hint: String?
            public var caption: String?
            /// 图下面的图例格（改过 / 删 / 一句没动 / 新开各一个数；分镜 ㊾）。有它就不画 caption。
            public var legend: [Key]?
            public var cells: [Cell]
        }
        public struct Cell: Codable, Sendable, Equatable, Identifiable {
            public var id: String
            public var label: String
            /// 格子下面写的章名；和前一格相同就不写。
            public var chapter: String?
            public var weight: Int
            public var value: Double
            /// 白点：这一段新开的节。
            public var mark: Bool?
            /// 悬停小卡的字。
            public var note: String?
        }
        public struct Alignment: Codable, Sendable, Equatable {
            public var title: String
            public var note: String?
            public var hint: String?
            /// 有它就只写这一句（这一段没有台账），不画别的。
            public var empty: String?
            public var headline: [Figure]?
            public var caption: String?
            /// 一句下面的图例格（引用 / 已绑 / 缺 / 只署名各一个数；分镜 ㊾）。有它就画格、不画 caption，走势图自己的图例也不画。
            public var legend: [Key]?
            public var trend: Trend?
            public var items: [Item]?
            public var folded: String?
        }
        public struct Figure: Codable, Sendable, Equatable {
            public var value: String
            public var text: String
            public var tone: Swatch
        }
        /// 范围 / 完成两线（Linear 的项目图），外加一条虚线（缺的）。一点一个提交，旧 → 新。
        public struct Trend: Codable, Sendable, Equatable {
            public var points: [Point]
            public var marker: Int?
            public var markerLabel: String?
            public var startLabel: String?
            public var endLabel: String?
            public var legend: [Key]
        }
        public struct Point: Codable, Sendable, Equatable {
            public var scope: Int
            public var done: Int
            public var missing: Int?
        }
        /// 图例的一项。`swatch` 可以没有（只是一个数，图上没有它的线或色）；`value` 有值时名字旁边写这个数（分镜 ㊾）。
        public struct Key: Codable, Sendable, Equatable {
            public var name: String
            public var swatch: Swatch?
            public var dashed: Bool?
            public var value: String?
        }
        /// 点开依据那一块之后的一行；`action` 有值时行尾有个按钮，点了宿主把 id 写进来源的收件目录。
        public struct Item: Codable, Sendable, Equatable {
            public var place: String
            public var tag: String
            public var key: String
            public var text: String
            public var tone: Swatch
            public var action: Action?
        }
        public struct Action: Codable, Sendable, Equatable {
            public var title: String
            public var id: String
        }
        public struct Todo: Codable, Sendable, Equatable {
            public var title: String
            public var note: String?
            public var hint: String?
            public var cells: [TodoCell]
        }
        /// 左栏一行（分镜 51）：`title` 左、`value` 右；没有 `value` 的老来源写 `text`。`text` 与 `sub` 进悬停。
        public struct TodoCell: Codable, Sendable, Equatable {
            public var title: String
            public var text: String
            public var value: String?
            public var sub: String?
            public var tone: Swatch?
        }
        /// 最下一行：最近一轮；点它进第二层。
        public struct Latest: Codable, Sendable, Equatable {
            public var at: Date?
            public var tag: String
            public var badge: String?
            /// 改到哪几节。JSON 里叫 where。
            public var place: String?
            public var more: String?
            enum CodingKeys: String, CodingKey { case at, tag, badge, place = "where", more }
        }
        public var days: Days
        public var stages: [Stage]
        public var selected: Int
        public var todo: Todo?
        public var latest: Latest?
    }
}

extension Activity.Pill {
    /// 只有一个数的胶囊（来源级的数：在跑的会话数）。
    public static func count(_ n: Int) -> Activity.Pill {
        try! JSONDecoder().decode(Activity.Pill.self, from: Data(#"{"pulse":false,"title":"\#(n)"}"#.utf8))
    }
}

/// lintel 调色板。来源程序只能从这里选颜色，不能自带。
///
/// 名字直接写颜色而不写含义：含义由来源程序在自己的文字里说，调色板不替它说「好 / 坏」。
/// `mint` 是许愿柳时间轴「写出理解后」那一段原有的颜色；spec 写「调色板里没有绿色」，两者冲突，第一版按「行为不变」保留，待作者裁。
public enum Swatch: String, Codable, Sendable, CaseIterable {
    case inkPrimary, inkSecondary, inkTertiary, inkQuaternary
    case white, white85, white70, white55, white50, white45, white35, white28, white25, white18
    case orange, red, coral, blue, slate, purple, mint, deepBlue, gray, indigo
}
