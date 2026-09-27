# lintel 活动格式 v1

由 `lintel schema` 从 `Sources/LintelCore/Validation.swift` 的结构表生成，不手改。字段含义见 `Sources/LintelCore/Activity.swift` 的注释。

- 位置：`producers/<来源程序 id>/activities/<活动 id>.json`，来源只由目录决定
- 写法：先写临时文件再改名；时刻一律 ISO 8601 且带时区
- 拒收：结构表外的字段、类型不对、超长、符号表与调色板以外的值、没登记的来源程序与事件类型；原因写进 `state/rejects.jsonl` 并在刘海上显示异常

| 字段 | 类型 | 必填 |
|---|---|---|
| `activityAt` | ISO 8601 时刻，必须带时区 |  |
| `body` | 数组（≤8）of 按 kind 分：section / stats | 是 |
| `body[]{kind=section}.badge` | 字符串（≤64 字） |  |
| `body[]{kind=section}.items` | 数组（≤64）of 按 kind 分：choice / diff / iconLine / para / pending / steps / timeline | 是 |
| `body[]{kind=section}.items[]{kind=choice}.action` | 字符串（≤64 字） | 是 |
| `body[]{kind=section}.items[]{kind=choice}.at` | ISO 8601 时刻，必须带时区 |  |
| `body[]{kind=section}.items[]{kind=choice}.choiceKind` | 取值 plan / question | 是 |
| `body[]{kind=section}.items[]{kind=choice}.countNote` | 字符串（≤64 字） |  |
| `body[]{kind=section}.items[]{kind=choice}.options` | 数组（≤32）of 字符串（≤64 字） | 是 |
| `body[]{kind=section}.items[]{kind=choice}.question` | 字符串（≤20000 字） |  |
| `body[]{kind=section}.items[]{kind=choice}.title` | 字符串（≤64 字） | 是 |
| `body[]{kind=section}.items[]{kind=diff}.label` | 字符串（≤64 字） | 是 |
| `body[]{kind=section}.items[]{kind=diff}.new` | 字符串（≤20000 字） | 是 |
| `body[]{kind=section}.items[]{kind=diff}.old` | 字符串（≤20000 字） |  |
| `body[]{kind=section}.items[]{kind=iconLine}.symbol` | 符号（符号表） | 是 |
| `body[]{kind=section}.items[]{kind=iconLine}.text` | 字符串（≤20000 字） | 是 |
| `body[]{kind=section}.items[]{kind=para}.text` | 字符串（≤20000 字） | 是 |
| `body[]{kind=section}.items[]{kind=para}.tone` | 颜色（调色板） | 是 |
| `body[]{kind=section}.items[]{kind=pending}.clockSince` | ISO 8601 时刻，必须带时区 |  |
| `body[]{kind=section}.items[]{kind=pending}.symbol` | 符号（符号表） | 是 |
| `body[]{kind=section}.items[]{kind=pending}.text` | 字符串（≤20000 字） | 是 |
| `body[]{kind=section}.items[]{kind=steps}.items` | 数组（≤16）of 对象 | 是 |
| `body[]{kind=section}.items[]{kind=steps}.items[].at` | ISO 8601 时刻，必须带时区 |  |
| `body[]{kind=section}.items[]{kind=steps}.items[].symbol` | 符号（符号表） | 是 |
| `body[]{kind=section}.items[]{kind=steps}.items[].text` | 字符串（≤20000 字） | 是 |
| `body[]{kind=section}.items[]{kind=steps}.limit` | 整数 1…16 | 是 |
| `body[]{kind=section}.items[]{kind=steps}.live` | 布尔 | 是 |
| `body[]{kind=section}.items[]{kind=steps}.offset` | 整数 0…1000000 | 是 |
| `body[]{kind=section}.items[]{kind=steps}.startedAt` | ISO 8601 时刻，必须带时区 | 是 |
| `body[]{kind=section}.items[]{kind=timeline}.endLabel` | 字符串（≤64 字） | 是 |
| `body[]{kind=section}.items[]{kind=timeline}.endedAt` | ISO 8601 时刻，必须带时区 |  |
| `body[]{kind=section}.items[]{kind=timeline}.markAt` | ISO 8601 时刻，必须带时区 |  |
| `body[]{kind=section}.items[]{kind=timeline}.segments` | 数组（≤8）of 对象 | 是 |
| `body[]{kind=section}.items[]{kind=timeline}.segments[].from` | ISO 8601 时刻，必须带时区 |  |
| `body[]{kind=section}.items[]{kind=timeline}.segments[].mergeIfEmpty` | 布尔 |  |
| `body[]{kind=section}.items[]{kind=timeline}.segments[].name` | 字符串（≤64 字） | 是 |
| `body[]{kind=section}.items[]{kind=timeline}.segments[].swatch` | 颜色（调色板） | 是 |
| `body[]{kind=section}.items[]{kind=timeline}.segments[].to` | ISO 8601 时刻，必须带时区 |  |
| `body[]{kind=section}.items[]{kind=timeline}.sentPrefix` | 字符串（≤64 字） |  |
| `body[]{kind=section}.items[]{kind=timeline}.startedAt` | ISO 8601 时刻，必须带时区 | 是 |
| `body[]{kind=section}.items[]{kind=timeline}.ticks` | 数组（≤500）of ISO 8601 时刻，必须带时区 | 是 |
| `body[]{kind=section}.title` | 字符串（≤64 字） | 是 |
| `body[]{kind=section}.value` | 字符串（≤64 字） |  |
| `body[]{kind=section}.valueTone` | 颜色（调色板） |  |
| `body[]{kind=stats}.cells` | 数组（≤8）of 对象 | 是 |
| `body[]{kind=stats}.cells[].dots` | 整数 0…4 |  |
| `body[]{kind=stats}.cells[].gauge` | 数 0.0…1.0 |  |
| `body[]{kind=stats}.cells[].hint` | 字符串（≤20000 字） |  |
| `body[]{kind=stats}.cells[].label` | 字符串（≤64 字） | 是 |
| `body[]{kind=stats}.cells[].series` | 数组（≤400）of 数 0.0…1.0 |  |
| `body[]{kind=stats}.cells[].tone` | 颜色（调色板） |  |
| `body[]{kind=stats}.cells[].value` | 字符串（≤64 字） | 是 |
| `chain` | 对象 |  |
| `chain.error` | 字符串（≤20000 字） |  |
| `chain.items` | 数组（≤500）of 对象 | 是 |
| `chain.items[].approved` | 布尔 |  |
| `chain.items[].id` | 字符串（≤16 字） | 是 |
| `chain.items[].idle` | 整数 0…100000 |  |
| `chain.items[].note` | 字符串（≤64 字） |  |
| `chain.items[].now` | 字符串（≤20000 字） |  |
| `chain.items[].state` | 取值 doing / done / later / other / you | 是 |
| `chain.items[].text` | 字符串（≤20000 字） | 是 |
| `chain.items[].wait` | 字符串（≤64 字） |  |
| `chain.items[].was` | 字符串（≤20000 字） |  |
| `chain.labels` | 对象 | 是 |
| `chain.labels.doing` | 字符串（≤64 字） | 是 |
| `chain.labels.done` | 字符串（≤64 字） | 是 |
| `chain.labels.later` | 字符串（≤64 字） | 是 |
| `chain.labels.other` | 字符串（≤64 字） | 是 |
| `chain.labels.you` | 字符串（≤64 字） | 是 |
| `chain.problems` | 数组（≤16）of 字符串（≤20000 字） | 是 |
| `closedAt` | ISO 8601 时刻，必须带时区 |  |
| `detail` | 对象 |  |
| `detail.chart` | 对象 |  |
| `detail.chart.bars` | 数组（≤500）of 对象 | 是 |
| `detail.chart.bars[].label` | 字符串（≤16 字） |  |
| `detail.chart.bars[].note` | 字符串（≤256 字） |  |
| `detail.chart.bars[].seconds` | 数 0.0…1000000.0 |  |
| `detail.chart.bars[].swatch` | 颜色（调色板） | 是 |
| `detail.chart.headline` | 字符串（≤64 字） | 是 |
| `detail.chart.hint` | 字符串（≤256 字） |  |
| `detail.chart.legend` | 数组（≤12）of 对象 | 是 |
| `detail.chart.legend[].count` | 整数 0…1000000 | 是 |
| `detail.chart.legend[].name` | 字符串（≤64 字） | 是 |
| `detail.chart.legend[].swatch` | 颜色（调色板） | 是 |
| `detail.chart.runningSince` | ISO 8601 时刻，必须带时区 |  |
| `detail.chart.title` | 字符串（≤64 字） | 是 |
| `detail.dot` | 颜色（调色板） | 是 |
| `detail.dotSeen` | 颜色（调色板） |  |
| `detail.history` | 数组（≤500）of 对象 | 是 |
| `detail.history[].at` | ISO 8601 时刻，必须带时区 |  |
| `detail.history[].badge` | 字符串（≤64 字） |  |
| `detail.history[].duration` | 字符串（≤64 字） |  |
| `detail.history[].expandable` | 布尔 | 是 |
| `detail.history[].id` | 字符串（≤256 字） | 是 |
| `detail.history[].lines` | 数组（≤4）of 对象 | 是 |
| `detail.history[].lines[].label` | 字符串（≤64 字） | 是 |
| `detail.history[].lines[].text` | 字符串（≤200000 字） | 是 |
| `detail.history[].lines[].tone` | 颜色（调色板） | 是 |
| `detail.history[].rows` | 数组（≤16）of 对象 |  |
| `detail.history[].rows[].copy` | 字符串（≤1024 字） |  |
| `detail.history[].rows[].label` | 字符串（≤64 字） | 是 |
| `detail.history[].rows[].new` | 字符串（≤20000 字） | 是 |
| `detail.history[].rows[].old` | 字符串（≤20000 字） |  |
| `detail.history[].rows[].where` | 字符串（≤256 字） |  |
| `detail.history[].sections` | 数组（≤120）of 字符串（≤64 字） |  |
| `detail.history[].tag` | 字符串（≤64 字） |  |
| `detail.historyNote` | 字符串（≤64 字） |  |
| `detail.listTitle` | 字符串（≤64 字） | 是 |
| `detail.live` | 对象 |  |
| `detail.live.at` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.badge` | 字符串（≤64 字） | 是 |
| `detail.live.choice` | 对象 |  |
| `detail.live.choice.action` | 字符串（≤64 字） | 是 |
| `detail.live.choice.at` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.choice.choiceKind` | 取值 plan / question | 是 |
| `detail.live.choice.countNote` | 字符串（≤64 字） |  |
| `detail.live.choice.options` | 数组（≤32）of 字符串（≤64 字） | 是 |
| `detail.live.choice.question` | 字符串（≤20000 字） |  |
| `detail.live.choice.title` | 字符串（≤64 字） | 是 |
| `detail.live.clockSince` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.lines` | 数组（≤4）of 对象 | 是 |
| `detail.live.lines[].label` | 字符串（≤64 字） | 是 |
| `detail.live.lines[].text` | 字符串（≤200000 字） | 是 |
| `detail.live.lines[].tone` | 颜色（调色板） | 是 |
| `detail.live.steps` | 对象 |  |
| `detail.live.steps.items` | 数组（≤16）of 对象 | 是 |
| `detail.live.steps.items[].at` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.steps.items[].symbol` | 符号（符号表） | 是 |
| `detail.live.steps.items[].text` | 字符串（≤20000 字） | 是 |
| `detail.live.steps.limit` | 整数 1…16 | 是 |
| `detail.live.steps.live` | 布尔 | 是 |
| `detail.live.steps.offset` | 整数 0…1000000 | 是 |
| `detail.live.steps.startedAt` | ISO 8601 时刻，必须带时区 | 是 |
| `detail.live.tag` | 字符串（≤64 字） |  |
| `detail.live.timeline` | 对象 |  |
| `detail.live.timeline.endLabel` | 字符串（≤64 字） | 是 |
| `detail.live.timeline.endedAt` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.timeline.markAt` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.timeline.segments` | 数组（≤8）of 对象 | 是 |
| `detail.live.timeline.segments[].from` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.timeline.segments[].mergeIfEmpty` | 布尔 |  |
| `detail.live.timeline.segments[].name` | 字符串（≤64 字） | 是 |
| `detail.live.timeline.segments[].swatch` | 颜色（调色板） | 是 |
| `detail.live.timeline.segments[].to` | ISO 8601 时刻，必须带时区 |  |
| `detail.live.timeline.sentPrefix` | 字符串（≤64 字） |  |
| `detail.live.timeline.startedAt` | ISO 8601 时刻，必须带时区 | 是 |
| `detail.live.timeline.ticks` | 数组（≤500）of ISO 8601 时刻，必须带时区 | 是 |
| `detail.overview` | 对象 |  |
| `detail.overview.days` | 对象 | 是 |
| `detail.overview.days.bars` | 数组（≤60）of 对象 | 是 |
| `detail.overview.days.bars[].gapDays` | 整数 1…10000 |  |
| `detail.overview.days.bars[].label` | 字符串（≤16 字） |  |
| `detail.overview.days.bars[].stage` | 整数 0…16 |  |
| `detail.overview.days.bars[].value` | 整数 0…1000000 |  |
| `detail.overview.days.hint` | 字符串（≤256 字） |  |
| `detail.overview.days.note` | 字符串（≤64 字） |  |
| `detail.overview.days.title` | 字符串（≤64 字） | 是 |
| `detail.overview.latest` | 对象 |  |
| `detail.overview.latest.at` | ISO 8601 时刻，必须带时区 |  |
| `detail.overview.latest.badge` | 字符串（≤64 字） |  |
| `detail.overview.latest.more` | 字符串（≤64 字） |  |
| `detail.overview.latest.tag` | 字符串（≤64 字） | 是 |
| `detail.overview.latest.where` | 字符串（≤64 字） |  |
| `detail.overview.selected` | 整数 0…7 | 是 |
| `detail.overview.stages` | 数组（≤8）of 对象 | 是 |
| `detail.overview.stages[].alignment` | 对象 |  |
| `detail.overview.stages[].alignment.caption` | 字符串（≤256 字） |  |
| `detail.overview.stages[].alignment.empty` | 字符串（≤256 字） |  |
| `detail.overview.stages[].alignment.folded` | 字符串（≤64 字） |  |
| `detail.overview.stages[].alignment.headline` | 数组（≤4）of 对象 |  |
| `detail.overview.stages[].alignment.headline[].text` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].alignment.headline[].tone` | 颜色（调色板） | 是 |
| `detail.overview.stages[].alignment.headline[].value` | 字符串（≤16 字） | 是 |
| `detail.overview.stages[].alignment.hint` | 字符串（≤256 字） |  |
| `detail.overview.stages[].alignment.items` | 数组（≤64）of 对象 |  |
| `detail.overview.stages[].alignment.items[].action` | 对象 |  |
| `detail.overview.stages[].alignment.items[].action.id` | 字符串（≤512 字） | 是 |
| `detail.overview.stages[].alignment.items[].action.title` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].alignment.items[].key` | 字符串（≤256 字） | 是 |
| `detail.overview.stages[].alignment.items[].place` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].alignment.items[].tag` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].alignment.items[].text` | 字符串（≤256 字） | 是 |
| `detail.overview.stages[].alignment.items[].tone` | 颜色（调色板） | 是 |
| `detail.overview.stages[].alignment.legend` | 数组（≤6）of 对象 |  |
| `detail.overview.stages[].alignment.legend[].dashed` | 布尔 |  |
| `detail.overview.stages[].alignment.legend[].name` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].alignment.legend[].swatch` | 颜色（调色板） |  |
| `detail.overview.stages[].alignment.legend[].value` | 字符串（≤16 字） |  |
| `detail.overview.stages[].alignment.note` | 字符串（≤64 字） |  |
| `detail.overview.stages[].alignment.title` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].alignment.trend` | 对象 |  |
| `detail.overview.stages[].alignment.trend.endLabel` | 字符串（≤16 字） |  |
| `detail.overview.stages[].alignment.trend.legend` | 数组（≤6）of 对象 | 是 |
| `detail.overview.stages[].alignment.trend.legend[].dashed` | 布尔 |  |
| `detail.overview.stages[].alignment.trend.legend[].name` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].alignment.trend.legend[].swatch` | 颜色（调色板） |  |
| `detail.overview.stages[].alignment.trend.legend[].value` | 字符串（≤16 字） |  |
| `detail.overview.stages[].alignment.trend.marker` | 整数 0…199 |  |
| `detail.overview.stages[].alignment.trend.markerLabel` | 字符串（≤64 字） |  |
| `detail.overview.stages[].alignment.trend.points` | 数组（≤200）of 对象 | 是 |
| `detail.overview.stages[].alignment.trend.points[].done` | 整数 0…1000000 | 是 |
| `detail.overview.stages[].alignment.trend.points[].missing` | 整数 0…1000000 |  |
| `detail.overview.stages[].alignment.trend.points[].scope` | 整数 0…1000000 | 是 |
| `detail.overview.stages[].alignment.trend.startLabel` | 字符串（≤16 字） |  |
| `detail.overview.stages[].caption` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].name` | 字符串（≤64 字） |  |
| `detail.overview.stages[].profile` | 对象 | 是 |
| `detail.overview.stages[].profile.caption` | 字符串（≤256 字） |  |
| `detail.overview.stages[].profile.cells` | 数组（≤120）of 对象 | 是 |
| `detail.overview.stages[].profile.cells[].chapter` | 字符串（≤64 字） |  |
| `detail.overview.stages[].profile.cells[].id` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].profile.cells[].label` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].profile.cells[].mark` | 布尔 |  |
| `detail.overview.stages[].profile.cells[].note` | 字符串（≤256 字） |  |
| `detail.overview.stages[].profile.cells[].value` | 数 0.0…1.0 | 是 |
| `detail.overview.stages[].profile.cells[].weight` | 整数 0…1000000 | 是 |
| `detail.overview.stages[].profile.hint` | 字符串（≤256 字） |  |
| `detail.overview.stages[].profile.legend` | 数组（≤6）of 对象 |  |
| `detail.overview.stages[].profile.legend[].dashed` | 布尔 |  |
| `detail.overview.stages[].profile.legend[].name` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].profile.legend[].swatch` | 颜色（调色板） |  |
| `detail.overview.stages[].profile.legend[].value` | 字符串（≤16 字） |  |
| `detail.overview.stages[].profile.note` | 字符串（≤64 字） |  |
| `detail.overview.stages[].profile.title` | 字符串（≤64 字） | 是 |
| `detail.overview.stages[].title` | 字符串（≤64 字） | 是 |
| `detail.overview.todo` | 对象 |  |
| `detail.overview.todo.cells` | 数组（≤4）of 对象 | 是 |
| `detail.overview.todo.cells[].sub` | 字符串（≤256 字） |  |
| `detail.overview.todo.cells[].text` | 字符串（≤64 字） | 是 |
| `detail.overview.todo.cells[].title` | 字符串（≤64 字） | 是 |
| `detail.overview.todo.cells[].tone` | 颜色（调色板） |  |
| `detail.overview.todo.cells[].value` | 字符串（≤16 字） |  |
| `detail.overview.todo.hint` | 字符串（≤256 字） |  |
| `detail.overview.todo.note` | 字符串（≤64 字） |  |
| `detail.overview.todo.title` | 字符串（≤64 字） | 是 |
| `detail.stats` | 数组（≤8）of 对象 | 是 |
| `detail.stats[].dots` | 整数 0…4 |  |
| `detail.stats[].gauge` | 数 0.0…1.0 |  |
| `detail.stats[].hint` | 字符串（≤20000 字） |  |
| `detail.stats[].label` | 字符串（≤64 字） | 是 |
| `detail.stats[].series` | 数组（≤400）of 数 0.0…1.0 |  |
| `detail.stats[].tone` | 颜色（调色板） |  |
| `detail.stats[].value` | 字符串（≤64 字） | 是 |
| `detail.strip` | 对象 |  |
| `detail.strip.cells` | 数组（≤500）of 颜色（调色板） | 是 |
| `detail.strip.legend` | 数组（≤12）of 对象 | 是 |
| `detail.strip.legend[].count` | 整数 0…1000000 | 是 |
| `detail.strip.legend[].name` | 字符串（≤64 字） | 是 |
| `detail.strip.legend[].swatch` | 颜色（调色板） | 是 |
| `detail.strip.title` | 字符串（≤64 字） | 是 |
| `ears` | 对象 |  |
| `ears.leading` | 字符串（≤64 字） | 是 |
| `ears.phase` | 字符串（≤64 字） | 是 |
| `ears.tag` | 对象 | 是 |
| `ears.tag.count` | 整数 0…1000000 |  |
| `ears.tag.text` | 字符串（≤64 字） | 是 |
| `ears.tag.tone` | 颜色（调色板） | 是 |
| `ears.tagSeen` | 对象 |  |
| `ears.tagSeen.count` | 整数 0…1000000 |  |
| `ears.tagSeen.text` | 字符串（≤64 字） | 是 |
| `ears.tagSeen.tone` | 颜色（调色板） | 是 |
| `events` | 数组（≤64）of 对象 | 是 |
| `events[].at` | ISO 8601 时刻，必须带时区 |  |
| `events[].id` | 字符串（≤256 字） | 是 |
| `events[].type` | 字符串（≤64 字） | 是 |
| `flagged` | 布尔 | 是 |
| `flip` | 对象 |  |
| `flip.phase` | 字符串（≤64 字） | 是 |
| `flip.subtitle` | 字符串（≤64 字） | 是 |
| `flip.title` | 字符串（≤64 字） | 是 |
| `group` | 对象 |  |
| `group.id` | 字符串（≤1024 字） | 是 |
| `group.name` | 字符串（≤64 字） | 是 |
| `heartbeatSeconds` | 数 1.0…86400.0 |  |
| `id` | 字符串（≤128 字） | 是 |
| `inProgress` | 布尔 | 是 |
| `label` | 对象 |  |
| `label.count` | 整数 0…1000000 |  |
| `label.text` | 字符串（≤64 字） | 是 |
| `label.tone` | 颜色（调色板） | 是 |
| `labelSeen` | 对象 |  |
| `labelSeen.count` | 整数 0…1000000 |  |
| `labelSeen.text` | 字符串（≤64 字） | 是 |
| `labelSeen.tone` | 颜色（调色板） | 是 |
| `labelUntilSeen` | 布尔 | 是 |
| `name` | 字符串（≤64 字） |  |
| `open` | 布尔 | 是 |
| `paged` | 布尔 |  |
| `pill` | 对象 |  |
| `pill.agoSince` | ISO 8601 时刻，必须带时区 |  |
| `pill.clockSince` | ISO 8601 时刻，必须带时区 |  |
| `pill.dot` | 颜色（调色板） |  |
| `pill.preview` | 字符串（≤64 字） |  |
| `pill.pulse` | 布尔 | 是 |
| `pill.symbol` | 符号（符号表） |  |
| `pill.tint` | 颜色（调色板） |  |
| `pill.title` | 字符串（≤64 字） |  |
| `pillSeen` | 对象 |  |
| `pillSeen.agoSince` | ISO 8601 时刻，必须带时区 |  |
| `pillSeen.clockSince` | ISO 8601 时刻，必须带时区 |  |
| `pillSeen.dot` | 颜色（调色板） |  |
| `pillSeen.preview` | 字符串（≤64 字） |  |
| `pillSeen.pulse` | 布尔 | 是 |
| `pillSeen.symbol` | 符号（符号表） |  |
| `pillSeen.tint` | 颜色（调色板） |  |
| `pillSeen.title` | 字符串（≤64 字） |  |
| `pillUntilSeen` | 布尔 | 是 |
| `popup` | 数组（≤4）of 对象 | 是 |
| `popup[].label` | 字符串（≤64 字） | 是 |
| `popup[].lines` | 整数 1…4 | 是 |
| `popup[].text` | 字符串（≤20000 字） | 是 |
| `popup[].tone` | 取值 accent / primary / quiet / secondary / warning | 是 |
| `rank` | 取值 anomaly / event / none / waiting | 是 |
| `revision` | 字符串（≤128 字） |  |
| `ring` | 对象 |  |
| `ring.closed` | 数组（≤32）of 对象 | 是 |
| `ring.closed[].date` | 字符串（≤16 字） | 是 |
| `ring.closed[].items` | 数组（≤64）of 字符串（≤64 字） | 是 |
| `ring.current` | 字符串（≤16 字） |  |
| `ring.error` | 字符串（≤20000 字） |  |
| `ring.labels` | 对象 | 是 |
| `ring.labels.closed` | 字符串（≤64 字） | 是 |
| `ring.labels.current` | 字符串（≤64 字） | 是 |
| `ring.labels.latest` | 字符串（≤64 字） | 是 |
| `ring.labels.title` | 字符串（≤64 字） | 是 |
| `ring.labels.unhung` | 字符串（≤64 字） | 是 |
| `ring.labels.waiting` | 字符串（≤64 字） | 是 |
| `ring.latest` | 字符串（≤16 字） |  |
| `ring.latestAt` | ISO 8601 时刻，必须带时区 |  |
| `ring.name` | 字符串（≤64 字） |  |
| `ring.reached` | 字符串（≤16 字） |  |
| `ring.segments` | 数组（≤8）of 对象 | 是 |
| `ring.segments[].items` | 数组（≤32）of 对象 | 是 |
| `ring.segments[].items[].detail` | 字符串（≤20000 字） |  |
| `ring.segments[].items[].id` | 字符串（≤32 字） | 是 |
| `ring.segments[].items[].moved` | 字符串（≤16 字） |  |
| `ring.segments[].items[].text` | 字符串（≤20000 字） | 是 |
| `ring.segments[].items[].you` | 布尔 |  |
| `ring.segments[].key` | 字符串（≤16 字） | 是 |
| `ring.segments[].name` | 字符串（≤64 字） | 是 |
| `ring.segments[].note` | 字符串（≤64 字） | 是 |
| `ring.segments[].sight` | 取值 commits / inferred / seen | 是 |
| `ring.segments[].sightNote` | 字符串（≤64 字） | 是 |
| `ring.segments[].state` | 取值 done / open / stale / unseen / waiting | 是 |
| `ring.since` | 字符串（≤20000 字） | 是 |
| `ring.unhung` | 数组（≤32）of 对象 | 是 |
| `ring.unhung[].detail` | 字符串（≤20000 字） |  |
| `ring.unhung[].id` | 字符串（≤32 字） | 是 |
| `ring.unhung[].moved` | 字符串（≤16 字） |  |
| `ring.unhung[].text` | 字符串（≤20000 字） | 是 |
| `ring.unhung[].you` | 布尔 |  |
| `ring.waiting` | 整数 0…100000 | 是 |
| `running` | 布尔 | 是 |
| `schema` | 整数 1…1 | 是 |
| `stale` | 布尔 | 是 |
| `status` | 对象 |  |
| `status.bounceAt` | ISO 8601 时刻，必须带时区 |  |
| `status.center` | 取值 assumed / broken / done / flagged / idle / live / superseded / waiting / withdrawn | 是 |
| `status.clock` | 对象 |  |
| `status.clock.opacity` | 数 0.0…1.0 |  |
| `status.clock.seconds` | 数 0.0…1000000.0 |  |
| `status.clock.since` | ISO 8601 时刻，必须带时区 |  |
| `status.clock.style` | 取值 ago / frozen / live | 是 |
| `status.lastWriteAt` | ISO 8601 时刻，必须带时区 |  |
| `status.ringRemaining` | 数 0.0…1.0 |  |
| `status.summary` | 字符串（≤20000 字） |  |
| `updatedAt` | ISO 8601 时刻，必须带时区 |  |
| `within` | 数组（≤16）of 对象 |  |
| `within[].id` | 字符串（≤128 字） | 是 |
| `within[].producer` | 字符串（≤64 字） | 是 |
| `within[].role` | 取值 history / primary |  |

符号表：`arrow.uturn.backward` `checklist` `circle.dotted` `doc.text` `ellipsis` `exclamationmark.triangle.fill` `globe` `magnifyingglass` `pencil` `person.2` `questionmark.bubble` `questionmark.bubble.fill` `terminal`

调色板：`inkPrimary` `inkSecondary` `inkTertiary` `inkQuaternary` `white` `white85` `white70` `white55` `white50` `white45` `white35` `white28` `white25` `white18` `orange` `red` `coral` `blue` `slate` `purple` `mint` `deepBlue` `gray` `indigo`

内容里不许出现的顶层字段（来源只由目录决定）：`app` `from` `origin` `producer` `sender` `source`
