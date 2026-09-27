<h1 align="center">lintel</h1>

<p align="center">
  <b>Mac 刘海上的一个共用显示位。</b><br>
  各个程序写小的 JSON 文件，说自己在做什么；lintel 把它们画在刘海上、悬停卡里、弹出框里和窗口里。
</p>

<p align="center"><a href="README.md">English</a> · 简体中文</p>

> 状态：实验中。活动格式是 v1，还可能变；一变就升 `schema`。

## 为什么有它

我有两个工具都想用刘海：[许愿柳](https://github.com/yha9806/wishing-willow)（把 Claude 理解的你的请求和你的原话并排放）和一个跟稿件修订轮次的写作循环。两个各画各的岛，抢同一小块地方。lintel 是唯一负责画的程序，别的只写文件。

## 来源程序要做什么

每件活动写一个 JSON 文件：

```
~/Library/Application Support/lintel/producers/<来源 id>/activities/<活动 id>.json
```

先写临时文件再改名。lintel 盯着这个目录，每个文件按 v1 格式校验后再画。不合格的文件被拒收，原因记下来，刘海上会显示有东西被拒收；lintel 不替你修。

格式见 [`docs/protocol/activity-v1.md`](docs/protocol/activity-v1.md)。这一页由 `lintel schema` 从 `Sources/LintelCore/Validation.swift` 的校验表生成，和宿主实际接受的一致。每个字段的含义写在 `Sources/LintelCore/Activity.swift` 的注释里。

lintel 用这些文件画出：

- 收起的刘海：左边是来源的标记，右边一个短标签；
- 悬停卡：活动的各节内容；
- 点刘海出的弹出框：讲刘海上正显示的那场对话；
- 窗口：左侧是对话列表，嵌在对话里的稿件挂在下面。

## 编译和运行

需要 macOS 26 和 Swift 6.2（Xcode 26 或对应的工具链）。

```bash
git clone https://github.com/vulca-org/lintel
cd lintel
make build        # swift build -c release
make test         # 可选
make autostart    # 现在就起宿主，以后每次登录也起（LaunchAgent）
```

`make run` 在终端里起一次；`make autostart-off` 去掉登录项；`make agent-plist` 只打印将要装的 LaunchAgent，不装。

常用命令：

| 命令 | 做什么 |
|---|---|
| `lintel paths` | 显示登记表、活动目录和 lintel 自己的状态放在哪 |
| `lintel register <id> --name <名字> [--initial X] [--event 类型[:attention]]` | 登记一个来源；没登记的来源写的文件一律拒收 |
| `lintel validate [文件…]` | 按宿主的规则检查活动文件；不带参数就检查全部 |
| `lintel schema` | 打印 v1 格式 |

## 配合许愿柳

许愿柳的 macOS app 是 lintel 的一个来源。两个都开着时，Claude Code 的会话会出现在刘海上：你的请求和 Claude 的理解、整场对话的长清单、到目前为止的各轮。安装步骤见许愿柳的 README。

## 它不做什么

- 只读文件，不连任何网络服务。来源写的内容不会离开这台 Mac。
- 不签名、不公证。你自己编译。
- 没有插件机制。新的内容种类要在格式里加字段。
- Windows 版宿主还在做，不在这个仓里。`windows/fixtures/` 放的是两边宿主都必须接受的两份活动样例。

## 许可

MIT
