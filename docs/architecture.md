# Architecture / 架构

> **EN TL;DR** — Four layers. This tree has one client (Retail 12.x), so the
> adapter is about normalizing API shapes and guarding missing capabilities, not
> about branching on client flavor. Business code calls `ns.Env.*`. The UI
> renders; the data layer calculates; the entry layer wires. Every file has
> exactly one home.
>
> **中文摘要** — 四层：入口装配 / 适配层 / 数据层 / 表现层。本仓只有一个客户端
> （正式服 12.x），适配层负责归一化 API 形状、兜住缺失能力，不做客户端分支。
> 业务代码只调用 `ns.Env.*`。UI 负责画，数据层负责算，入口层负责接线。
> 每个文件只有一个归属。

## English

### The four layers

| Layer | Allowed | Forbidden | Files in this demo |
| --- | --- | --- | --- |
| Entry wiring | namespace, slash commands, event wiring, load-time self-check | business math, building business widgets | `Core/Init.lua`, `UI/Main.lua` (loader block) |
| Adapter | the **only** place for raw modern APIs; normalizes tables and guards missing APIs | business decisions (should I buy? is it worth it?) | `Core/Env.lua` |
| Data | pure calculations, saved-variable reads/writes, definitions | touching UI or raw client APIs | `Core/Probe.lua` |
| Presentation | widgets, rendering, forwarding clicks, formatting | holding buy/list primitives, writing business rules | `UI/Main.lua` |

### Three placement questions

1. Would this code change if the API shape changed? **Yes → adapter.**
2. Is it calculating, deciding, or recording? **Yes → data.**
3. Is it drawing something or waiting for a click? **Yes → presentation.**
4. None of the above? The requirement is not decomposed enough. Split it first.

### Why an adapter when there is only one client

“One client” does not mean “one shape”. In Retail:

- Some documented APIs are missing in a given build. The adapter probes before
  use and returns an explicit failure.
- The Auction House is shared by a connected realm; the storage key is not the
  character's realm name.
- The market is factionless, and the level cap is 90.
- Browse results arrive as a whole table, not row by row.

Keeping those facts in one file means the rest of the add-on never has to know
them.

### Load order

`AHProbe.toc` order is dependency order. `Init` must run before `Env`; `Env`
before anything that calls it; `Probe` before the UI that reads it. A file that
is not in the toc is not loaded, and a value that is read too early is `nil`
forever.

When adding a file, update three places:

1. `AHProbe.toc` — between its dependencies and its dependents.
2. The test loader — it reads the toc, so no hand-written list is needed.
3. The expected file list in `tests/test_retail.py`.

### Why not one big file

The demo is small on purpose, but the failure mode is the same at any size: when
raw API calls and business rules live together, every change risks breaking an
unrelated feature. The layers make the difference explicit and testable.

## 中文

### 四层模型

| 层 | 允许 | 禁止 | 本示例中的文件 |
| --- | --- | --- | --- |
| 入口装配 | 命名空间、斜杠命令、事件装配、加载期自检 | 业务计算、建业务控件 | `Core/Init.lua`、`UI/Main.lua` 的 loader 段 |
| 适配层 | **唯一**允许原始现代 API 的地方；归一化表结构、兜住缺失能力 | 业务决策（买不买、值不值） | `Core/Env.lua` |
| 数据层 | 纯计算、存档读写、口径定义 | 直接碰 UI、直接碰原始 API | `Core/Probe.lua` |
| 表现层 | 建控件、渲染、转发点击、格式化 | 持有买入/上架原语、写业务判定 | `UI/Main.lua` |

### 落层三问

1. 这段代码在 API 形状变化时会不会改？**会 → 适配层。**
2. 它是在算、在判、在记吗？**是 → 数据层。**
3. 它是在画出来、在等玩家点吗？**是 → 表现层。**
4. 三句都答不上？说明需求拆得不够，先拆需求，再写代码。

### 只有一个客户端，为什么还要适配层

“只有一个客户端”不等于“只有一种形状”。正式服里：

- 文档里有的 API，某个版本可能没有。适配层先探测再用，缺了显式失败。
- 拍卖行按连接服共享，存档键不是角色所在服名。
- 市场不分阵营，等级上限是 90。
- 浏览结果是一整张表，不是逐行取。

把这些事实收在一个文件里，插件其它部分就不需要知道它们。

### 加载顺序

`AHProbe.toc` 的顺序就是依赖顺序。`Init` 必须在 `Env` 之前，`Env` 必须在所有
调用它的文件之前，`Probe` 必须在读取它的 UI 之前。没进 toc 的文件不会被加载；
读得太早的值永远是 `nil`。

新增文件时同步三处：

1. `AHProbe.toc` —— 放在“它依赖的”之后、“依赖它的”之前。
2. 测试加载器 —— 它直接读 toc，不需要手写清单。
3. `tests/test_retail.py` 里的期望文件清单。

### 为什么不做成一个大文件

示例很小，但失败模式与大型插件相同：原始 API 调用和业务规则混在一起后，每次改动
都可能影响不相关的功能。分层把差异显式化，也让差异变得可测试。
