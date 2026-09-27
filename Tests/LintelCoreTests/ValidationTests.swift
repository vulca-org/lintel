import Foundation
import Testing
@testable import LintelCore

/// 1.3 拒收：每一类违规都要被拒，并且原因带字段路径；合规的全部接受。
@Suite("活动校验与拒收")
struct ValidationTests {
    let registered: Set<String> = ["declaration", "choice"]

    func check(_ a: Activity, file: String? = nil) throws -> (Activity?, [Validation.Reject]) {
        let data = try LintelJSON.encoder.encode(a)
        return Validation.check(data: data, producer: "willow", file: file ?? "\(a.id).json", registered: registered)
    }

    func check(json: String, file: String = "x.json") -> [Validation.Reject] {
        Validation.check(data: Data(json.utf8), producer: "willow", file: file, registered: registered).1
    }

    /// 把一份合规活动编码成字典、改一处、再校验。
    func mutate(_ change: (inout [String: Any]) -> Void) throws -> [Validation.Reject] {
        let data = try LintelJSON.encoder.encode(fullActivity(id: "x"))
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        change(&obj)
        return check(json: String(data: try JSONSerialization.data(withJSONObject: obj), encoding: .utf8)!)
    }

    @Test("每个字段都填上的活动：编码出来的键全在结构表里，校验通过、解码回来相等")
    func fullRoundTrip() throws {
        let a = fullActivity()
        let (decoded, rejects) = try check(a)
        #expect(rejects.isEmpty, "\(rejects)")
        #expect(decoded == a)
    }

    @Test("paged 是可选布尔：缺省接受，true 接受，别的类型拒收并带字段路径")
    func paged() throws {
        #expect(try mutate { $0["paged"] = true }.isEmpty)
        #expect(try mutate { $0.removeValue(forKey: "paged") }.isEmpty)
        let bad = try mutate { $0["paged"] = "yes" }
        #expect(bad.contains { $0.path == "paged" }, "\(bad)")
    }

    @Test("history[].rows 是可选的定位行：合规的接受，缺 new 拒收并带路径，超过 16 行拒收")
    func rows() throws {
        func withRows(_ rows: [[String: Any]]) throws -> [Validation.Reject] {
            try mutate { obj in
                var d = obj["detail"] as! [String: Any]
                var h = d["history"] as! [[String: Any]]
                h[0]["rows"] = rows
                d["history"] = h; obj["detail"] = d
            }
        }
        let ok: [String: Any] = ["label": "X6.2", "where": "§5.5 第 6 段 · sections/06_results.tex:209",
                                 "copy": "sections/06_results.tex:209 · X6.2", "old": "a b", "new": "a c"]
        #expect(try withRows([ok]).isEmpty)
        #expect(try withRows([["label": "X1", "new": "only new"]]).isEmpty)
        let missing = try withRows([["label": "X1"]])
        #expect(missing.contains { $0.path.hasSuffix("rows[0].new") }, "\(missing)")
        let tooMany = try withRows(Array(repeating: ok, count: 17))
        #expect(tooMany.contains { $0.path.hasSuffix("rows") }, "\(tooMany)")
    }

    @Test("label.count 是可选整数；chart 现在可选；strip 合规接受、格子不是调色板色拒收")
    func countChartStrip() throws {
        #expect(try mutate { var l = $0["label"] as! [String: Any]; l["count"] = 15; $0["label"] = l }.isEmpty)
        let badCount = try mutate { var l = $0["label"] as! [String: Any]; l["count"] = "15"; $0["label"] = l }
        #expect(badCount.contains { $0.path == "label.count" }, "\(badCount)")
        #expect(try mutate { var d = $0["detail"] as! [String: Any]; d.removeValue(forKey: "chart"); $0["detail"] = d }.isEmpty)
        let strip: [String: Any] = ["title": "改动集 · 旧 → 新", "cells": ["indigo", "white28", "white28"],
                                    "legend": [["name": "追到", "swatch": "indigo", "count": 1]]]
        #expect(try mutate { var d = $0["detail"] as! [String: Any]; d["strip"] = strip; $0["detail"] = d }.isEmpty)
        let bad = try mutate { var d = $0["detail"] as! [String: Any]; var st = strip; st["cells"] = ["indigo", "green"]; d["strip"] = st; $0["detail"] = d }
        #expect(bad.contains { $0.path.hasPrefix("detail.strip.cells") }, "\(bad)")
    }

    @Test("diff 条目：label 与 new 必填，old 可缺（新增的句子）；缺 new 拒收并带路径")
    func diffItem() throws {
        func withItem(_ item: [String: Any]) throws -> [Validation.Reject] {
            try mutate { obj in
                var body = obj["body"] as! [[String: Any]]
                guard let i = body.firstIndex(where: { $0["kind"] as? String == "section" }) else { return }
                body[i]["items"] = [item]; obj["body"] = body
            }
        }
        #expect(try withItem(["kind": "diff", "label": "X6.2", "old": "a b", "new": "a c"]).isEmpty)
        #expect(try withItem(["kind": "diff", "label": "A03", "new": "new sentence"]).isEmpty)
        let bad = try withItem(["kind": "diff", "label": "A03"])
        #expect(bad.contains { $0.path.hasSuffix(".new") }, "\(bad)")
    }

    @Test("chain：合规的接受；状态不在五种之内拒收并带路径；labels 缺一种拒收")
    func chain() throws {
        #expect(try mutate { _ in }.isEmpty)
        let bad = try mutate { o in
            var c = o["chain"] as! [String: Any]
            var items = c["items"] as! [[String: Any]]
            items[0]["state"] = "maybe"
            c["items"] = items
            o["chain"] = c
        }
        #expect(bad.contains { $0.path.contains("chain") && $0.path.contains("state") }, "\(bad)")
        let noLabel = try mutate { o in
            var c = o["chain"] as! [String: Any]
            var l = c["labels"] as! [String: Any]
            l.removeValue(forKey: "later")
            c["labels"] = l
            o["chain"] = c
        }
        #expect(!noLabel.isEmpty)
    }

    @Test("name（对话的名字）可选；是字符串就收，超长拒收并带路径（09-27 grill 4）")
    func activityName() throws {
        #expect(try mutate { o in o["name"] = "Wishing Willow、AWT 和 Lintel 进展" }.isEmpty)
        let long = try mutate { o in o["name"] = String(repeating: "长", count: Validation.Limit.short + 1) }
        #expect(long.contains { $0.path.contains("name") }, "\(long)")
    }

    @Test("chain：was（建项原句）可选；是字符串就收，超长拒收并带路径（09-27 grill 1）")
    func chainWas() throws {
        func withWas(_ v: Any) throws -> [Validation.Reject] {
            try mutate { o in
                var c = o["chain"] as! [String: Any]
                var items = c["items"] as! [[String: Any]]
                items[0]["was"] = v
                c["items"] = items
                o["chain"] = c
            }
        }
        #expect(try withWas("建项时的原句").isEmpty)
        let long = try withWas(String(repeating: "长", count: Validation.Limit.line + 1))
        #expect(long.contains { $0.path.contains("was") }, "\(long)")
        let notString = try withWas(3)
        #expect(notString.contains { $0.path.contains("was") }, "\(notString)")
    }

    @Test("chain：now（现在要做什么）与 wait（在等什么）可选；wait 超过短字上限拒收并带路径（09-27 grill 第二轮 N2/N3）")
    func chainNowWait() throws {
        func with(_ key: String, _ v: Any) throws -> [Validation.Reject] {
            try mutate { o in
                var c = o["chain"] as! [String: Any]
                var items = c["items"] as! [[String: Any]]
                items[0][key] = v
                c["items"] = items
                o["chain"] = c
            }
        }
        #expect(try with("now", "CI 绿了合 #78").isEmpty)
        #expect(try with("wait", "CI").isEmpty)
        let longWait = try with("wait", String(repeating: "等", count: Validation.Limit.short + 1))
        #expect(longWait.contains { $0.path.contains("wait") }, "\(longWait)")
        let notString = try with("now", 3)
        #expect(notString.contains { $0.path.contains("now") }, "\(notString)")
    }

    @Test("ring：合规的接受；状态、可见性不在列出的几种之内拒收并带路径；一环挂的事超过上限拒收")
    func ring() throws {
        #expect(try mutate { _ in }.isEmpty)
        func segs(_ change: (inout [String: Any]) -> Void) throws -> [Validation.Reject] {
            try mutate { o in
                var r = o["ring"] as! [String: Any]
                var ss = r["segments"] as! [[String: Any]]
                change(&ss[1])
                r["segments"] = ss
                o["ring"] = r
            }
        }
        let badState = try segs { $0["state"] = "hanging" }
        #expect(badState.contains { $0.path.contains("ring") && $0.path.contains("state") }, "\(badState)")
        let badSight = try segs { $0["sight"] = "guess" }
        #expect(badSight.contains { $0.path.contains("sight") }, "\(badSight)")
        let tooMany = try segs { $0["items"] = (0..<33).map { ["id": "A\($0)", "text": "t"] } }
        #expect(!tooMany.isEmpty)
        // 环上条目的第二行 detail 可选（09-27 面板 grill 14）；是字符串就收，不是就拒并带路径。
        #expect(try segs { $0["items"] = [["id": "W5", "text": "t", "detail": "要做什么 · 由哪个门决定"]] }.isEmpty)
        let badDetail = try segs { $0["items"] = [["id": "W5", "text": "t", "detail": 3]] }
        #expect(badDetail.contains { $0.path.contains("detail") }, "\(badDetail)")
    }

    @Test("最小的活动（只有必填字段）也接受")
    func minimal() throws {
        let (decoded, rejects) = try check(Activity(id: "m"))
        #expect(rejects.isEmpty, "\(rejects)")
        #expect(decoded?.id == "m")
    }

    @Test("来源程序没登记：拒收")
    func unregisteredProducer() throws {
        let data = try LintelJSON.encoder.encode(Activity(id: "m"))
        let r = Validation.check(data: data, producer: "stranger", file: "m.json", registered: nil)
        #expect(r.0 == nil)
        #expect(r.1.first?.reason.contains("没有登记") == true)
    }

    @Test("事件类型没登记：拒收，路径指到那一项")
    func unregisteredEvent() throws {
        var a = Activity(id: "m")
        a.events = [.init(id: "e1", type: "sneaky", at: t0)]
        let r = try check(a).1
        #expect(r.contains { $0.path == "events[0].type" && $0.reason.contains("没有登记") })
    }

    @Test("超长文字：标签超过 64 字拒收；正文放得下真实原话（507 字接受），离谱长度才拒")
    func tooLong() throws {
        var a = Activity(id: "m")
        a.label = .init(text: String(repeating: "长", count: Validation.Limit.short + 1), tone: .white)
        let r = try check(a).1
        #expect(r.contains { $0.path == "label.text" && $0.reason.contains("超长") })

        // 2026-09-17 试用时被拒的那种真实长度（507 字）必须接受：正文存完整原话，截断是画法的事。
        var real = Activity(id: "m")
        real.body = [.section(.init(title: "你的要求", items: [.para(text: String(repeating: "字", count: 507), tone: .inkPrimary)]))]
        real.popup = [.init(label: "要求", text: String(repeating: "字", count: 507), tone: .secondary, lines: 1)]
        #expect(try check(real).1.isEmpty)

        var absurd = Activity(id: "m")
        absurd.body = [.section(.init(title: "你的要求", items: [.para(text: String(repeating: "字", count: Validation.Limit.line + 1), tone: .inkPrimary)]))]
        #expect(try check(absurd).1.contains { $0.path == "body[0].items[0].text" })
    }

    @Test("符号表以外的符号、调色板以外的颜色、词表以外的圆心：拒收")
    func outsideVocabulary() throws {
        #expect(try mutate { o in var p = o["pill"] as! [String: Any]; p["symbol"] = "star.fill"; o["pill"] = p }
            .contains { $0.path == "pill.symbol" && $0.reason.contains("符号表") })
        #expect(try mutate { o in var p = o["label"] as! [String: Any]; p["tone"] = "green"; o["label"] = p }
            .contains { $0.path == "label.tone" && $0.reason.contains("调色板") })
        #expect(try mutate { o in var s = o["status"] as! [String: Any]; s["center"] = "success"; o["status"] = s }
            .contains { $0.path == "status.center" })
    }

    @Test("为 awt-loop 加的两个圆心词（批准的是旧版、我替你定的）被接受；结构表是从词表现算的，不是手抄的")
    func awtLoopCenters() throws {
        for c in ["superseded", "assumed"] {
            #expect(try mutate { o in var s = o["status"] as! [String: Any]; s["center"] = c; o["status"] = s }
                .isEmpty, "\(c) 应该被接受")
        }
        #expect(Validation.describe().contains("superseded"))
    }

    @Test("内容里自称来源：拒收（来源只由目录决定）")
    func claimedSource() throws {
        let r = try mutate { $0["producer"] = "awt-loop" }
        #expect(r.contains { $0.path == "producer" && $0.reason.contains("自称来源") })
    }

    @Test("未知字段、缺少必填、id 与文件名不一致、坏时刻、未知内容块：各自拒收")
    func structure() throws {
        #expect(try mutate { $0["colour"] = "red" }.contains { $0.path == "colour" && $0.reason == "未知字段" })
        #expect(try mutate { $0["running"] = nil }.contains { $0.path == "running" && $0.reason == "缺少必填字段" })
        #expect(try mutate { $0["id"] = "y" }.contains { $0.path == "id" })
        #expect(try mutate { $0["updatedAt"] = "昨天" }.contains { $0.path == "updatedAt" })
        // 不带时区的时刻：拒收（读方不知道是哪个钟）
        #expect(try mutate { $0["updatedAt"] = "2026-09-17T17:22:08.036" }.contains { $0.path == "updatedAt" })
        #expect(try mutate { $0["updatedAt"] = "2026-09-17T17:22:08.036Z" }.isEmpty)
        #expect(try mutate { $0["updatedAt"] = "2026-09-17T18:22:08+01:00" }.isEmpty)
        #expect(try mutate { o in var b = o["body"] as! [[String: Any]]; b[0]["kind"] = "video"; o["body"] = b }
            .contains { $0.path == "body[0].kind" })
        #expect(try mutate { o in
            var b = o["body"] as! [[String: Any]]; var items = b[0]["items"] as! [[String: Any]]
            items[0]["tone"] = "neon"; b[0]["items"] = items; o["body"] = b
        }.contains { $0.path == "body[0].items[0].tone" })
        #expect(check(json: "{\"schema\":1,", file: "x.json").first?.reason.contains("不是合法的 JSON") == true)
        #expect(try mutate { $0["open"] = 1 }.contains { $0.path == "open" && $0.reason.contains("布尔") })
    }
}
