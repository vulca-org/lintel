import Foundation
import Testing
@testable import LintelCore

/// 总览（分镜 ㊸–㊽）：协议收它、收得严。
@Suite("总览协议")
struct OverviewTests {
    func check(_ obj: [String: Any]) throws -> [Validation.Reject] {
        let data = try JSONSerialization.data(withJSONObject: obj)
        return Validation.check(data: data, producer: "awt-loop", file: "loop-paper.json", registered: []).1
    }

    func encoded() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: LintelJSON.encoder.encode(overviewActivity())) as! [String: Any]
    }

    @Test("带总览与历史 sections 的活动：校验通过、解码回来相等；Latest 的 place 在 JSON 里叫 where")
    func roundTrip() throws {
        let a = overviewActivity()
        let data = try LintelJSON.encoder.encode(a)
        let (decoded, rejects) = Validation.check(data: data, producer: "awt-loop", file: "loop-paper.json", registered: [])
        #expect(rejects.isEmpty, "\(rejects)")
        #expect(decoded == a)
        let obj = try encoded()
        let latest = ((obj["detail"] as! [String: Any])["overview"] as! [String: Any])["latest"] as! [String: Any]
        #expect(latest["where"] as? String == "§7.2 · §6.2")
    }

    @Test("总览里的未知字段拒收，带字段路径")
    func unknownField() throws {
        var obj = try encoded()
        var d = obj["detail"] as! [String: Any]
        var ov = d["overview"] as! [String: Any]
        ov["score"] = 87
        d["overview"] = ov; obj["detail"] = d
        #expect(try check(obj).contains { $0.path == "detail.overview.score" })
    }

    @Test("互借的新字段都是可选的：老活动文件（没有 hint / legend / value / series）照样通过")
    func borrowedFieldsOptional() throws {
        var obj = try encoded()
        var d = obj["detail"] as! [String: Any]
        var ov = d["overview"] as! [String: Any]
        var days = ov["days"] as! [String: Any]; days.removeValue(forKey: "hint"); ov["days"] = days
        var stages = ov["stages"] as! [[String: Any]]
        var prof = stages[1]["profile"] as! [String: Any]
        prof.removeValue(forKey: "hint"); prof.removeValue(forKey: "legend"); stages[1]["profile"] = prof
        var al = stages[1]["alignment"] as! [String: Any]; al.removeValue(forKey: "hint")
        var trend = al["trend"] as! [String: Any]
        trend["legend"] = [["name": "引用 55", "swatch": "white45"]]      // 老写法：数在名字里、没有 value
        al["trend"] = trend; stages[1]["alignment"] = al; ov["stages"] = stages
        var todo = ov["todo"] as! [String: Any]; todo.removeValue(forKey: "hint")
        todo["cells"] = [["title": "稿件仓 issue", "text": "已关 1 / 共 1"]]; ov["todo"] = todo
        d["overview"] = ov
        d["stats"] = [["label": "句", "value": "646"]]
        obj["detail"] = d
        #expect(try check(obj).isEmpty)
    }

    @Test("新字段越界各自拒收：走势点超出 0…1、图例的数太长、待办的数太长、图例项超过 6")
    func borrowedFieldsRanges() throws {
        var obj = try encoded()
        var d = obj["detail"] as! [String: Any]
        var stats = d["stats"] as! [[String: Any]]
        stats[2]["series"] = [0.1, 1.5]
        d["stats"] = stats
        var ov = d["overview"] as! [String: Any]
        var stages = ov["stages"] as! [[String: Any]]
        var prof = stages[1]["profile"] as! [String: Any]
        prof["legend"] = (0..<7).map { ["name": "k\($0)", "value": "1"] }
        stages[1]["profile"] = prof
        var al = stages[1]["alignment"] as! [String: Any]
        var trend = al["trend"] as! [String: Any]
        trend["legend"] = [["name": "引用", "swatch": "white45", "value": String(repeating: "9", count: 17)]]
        al["trend"] = trend; stages[1]["alignment"] = al; ov["stages"] = stages
        var todo = ov["todo"] as! [String: Any]
        todo["cells"] = [["title": "t", "text": "x", "value": String(repeating: "9", count: 17)]]
        ov["todo"] = todo
        d["overview"] = ov; obj["detail"] = d
        let r = try check(obj)
        for path in ["detail.stats[2].series[1]", "detail.overview.stages[1].profile.legend",
                     "detail.overview.stages[1].alignment.trend.legend[0].value", "detail.overview.todo.cells[0].value"] {
            #expect(r.contains { $0.path == path }, "\(path) 没拒：\(r.map(\.path))")
        }
    }

    @Test("剖面格的比例超出 0…1、选中的段超出范围：各自拒收")
    func ranges() throws {
        var obj = try encoded()
        var d = obj["detail"] as! [String: Any]
        var ov = d["overview"] as! [String: Any]
        var stages = ov["stages"] as! [[String: Any]]
        var prof = stages[0]["profile"] as! [String: Any]
        var cells = prof["cells"] as! [[String: Any]]
        cells[0]["value"] = 1.5
        prof["cells"] = cells; stages[0]["profile"] = prof
        ov["stages"] = stages; ov["selected"] = 9
        d["overview"] = ov; obj["detail"] = d
        let r = try check(obj)
        #expect(r.contains { $0.path == "detail.overview.stages[0].profile.cells[0].value" }, "\(r)")
        #expect(r.contains { $0.path == "detail.overview.selected" }, "\(r)")
    }
}
