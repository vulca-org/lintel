import Foundation

/// 词级改动：改前改后按空白切词，最长公共子序列对齐，相邻同类合成一段。给面板画「改了哪几个词」（分镜 ⑪，09-18 ⑧ 用 difflib 画的那种）。
public enum WordDiff {
    public enum Op: Equatable, Sendable {
        case equal([String]), delete([String]), insert([String])
    }

    /// 超过这个词数不做对齐（O(n·m) 的表），整句当作删旧加新。
    public static let maxWords = 400

    public static func ops(old: String, new: String) -> [Op] {
        let a = old.split(whereSeparator: \.isWhitespace).map(String.init)
        let b = new.split(whereSeparator: \.isWhitespace).map(String.init)
        var out: [Op] = []
        func push(_ op: Op) {
            switch (out.last, op) {
            case (.equal(let x)?, .equal(let y)): out[out.count - 1] = .equal(x + y)
            case (.delete(let x)?, .delete(let y)): out[out.count - 1] = .delete(x + y)
            case (.insert(let x)?, .insert(let y)): out[out.count - 1] = .insert(x + y)
            default: out.append(op)
            }
        }
        if a.count > maxWords || b.count > maxWords {
            if !a.isEmpty { out.append(.delete(a)) }
            if !b.isEmpty { out.append(.insert(b)) }
            return out
        }
        var dp = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        if !a.isEmpty && !b.isEmpty {
            for i in stride(from: a.count - 1, through: 0, by: -1) {
                for j in stride(from: b.count - 1, through: 0, by: -1) {
                    dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        var i = 0, j = 0
        while i < a.count && j < b.count {
            if a[i] == b[j] { push(.equal([a[i]])); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { push(.delete([a[i]])); i += 1 }
            else { push(.insert([b[j]])); j += 1 }
        }
        while i < a.count { push(.delete([a[i]])); i += 1 }
        while j < b.count { push(.insert([b[j]])); j += 1 }
        return out
    }
}
