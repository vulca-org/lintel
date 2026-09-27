# lintel 收件格式 v1（拖放，候选 B）

作者把一个目录拖到刘海上（2026-09-21 裁定：只收目录，PDF 先不收）。lintel 做的只有两件事：

1. 判断收不收：不是目录 → 拒；没有来源登记 `--accepts folder` → 拒；否则交给登记了的来源里 id 最小的那个。
2. 写一个文件到 `producers/<id>/inbox/<uuid>.json`（先写 `.<uuid>.json.tmp` 再改名，读的人永远看到完整的一份）：

```json
{
  "at": "2026-09-21T11:54:28Z",
  "from": "lintel",
  "kind": "drop",
  "path": "/absolute/path/to/the/folder",
  "schema": 1
}
```

lintel **不运行来源的程序**，也不认识登记表里的任何字段。来源自己读收件（写作循环：`loop inbox --workspaces <root>`），
登记、建索引、写一条新活动回话；处理过的收件移到 `inbox/done/`，结果写在旁边。

登记：`lintel register <id> … --accepts folder`。旧登记表没有这一项，照读，等于不收。

## 面板动作（`kind: action`，总览 ㊺，2026-09-21）

面板上来源给出的按钮（例：写作循环在「依据」清单里给每句缺依据的一个「是方法署名」）。点了之后 lintel 把来源给的动作 id
**原样**写回同一个收件目录：

```json
{
  "action": "credit|z1934=report bootstrap intervals",
  "activity": "loop-paper",
  "at": "2026-09-21T19:40:00Z",
  "from": "lintel",
  "kind": "action",
  "schema": 1
}
```

lintel 不解析 id，也不判断它对不对；来源只认它自己当前给出的动作（写作循环：常驻产出每轮读一次，只收 `activity` 是自己的，
不在当前面板上的动作写明理由移到 `done/`，不执行）。拖放的收件器（`loop inbox`）跳过 `kind: action` 的文件。
