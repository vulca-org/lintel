import Foundation
import Testing
@testable import LintelCore

/// 候选 A：面板里画逐词改动。对齐按最长公共子序列，相邻同类合段。
@Suite("词级改动")
struct WordDiffTests {
    @Test("一字不改：一段 equal")
    func same() {
        #expect(WordDiff.ops(old: "a b c", new: "a b c") == [.equal(["a", "b", "c"])])
    }

    @Test("中间换一个词：equal · delete · insert · equal，且相邻同类合成一段")
    func replaceMiddle() {
        let ops = WordDiff.ops(old: "the quick brown fox", new: "the slow brown fox")
        #expect(ops == [.equal(["the"]), .delete(["quick"]), .insert(["slow"]), .equal(["brown", "fox"])])
    }

    @Test("只有改后（新增句）与只有改前（删句）")
    func oneSided() {
        #expect(WordDiff.ops(old: "", new: "x y") == [.insert(["x", "y"])])
        #expect(WordDiff.ops(old: "x y", new: "") == [.delete(["x", "y"])])
        #expect(WordDiff.ops(old: "", new: "") == [])
    }

    @Test("真实改句的形状：删两处、加两处，其余不动")
    func realShape() {
        let old = "Model A, against 3 of 12 for model B, whose encoder is not a language model."
        let new = "Model A, against 3 of 12 for model B, although its encoder is also a language model."
        let ops = WordDiff.ops(old: old, new: new)
        let deleted = ops.flatMap { op -> [String] in if case .delete(let w) = op { return w }; return [] }
        let inserted = ops.flatMap { op -> [String] in if case .insert(let w) = op { return w }; return [] }
        #expect(deleted == ["whose", "not"])
        #expect(inserted == ["although", "its", "also"])
    }

    @Test("超过上限的长句不做对齐：删旧加新")
    func tooLong() {
        let long = Array(repeating: "w", count: WordDiff.maxWords + 1).joined(separator: " ")
        #expect(WordDiff.ops(old: long, new: "x") == [.delete(Array(repeating: "w", count: WordDiff.maxWords + 1)), .insert(["x"])])
    }
}
