# WoW Addon Harness · Retail

**人人都能做魔兽插件。 / Anyone can build WoW addons.**

A test-first development harness for **World of Warcraft Retail 12.x**
(Interface `120105`) add-ons that use the modern Auction House.

One source tree. One client. No legacy branches, no “if retail then” in business
code.

> Looking for the dual-client tree (Classic Era 1.15.x + a 1.60.x modern-AH
> client)? That lives in the companion repository,
> **wow-addon-harness-classic**.

[中文](#中文) · [English](#english)

---

## 中文

### 这是什么

这是一套“能被验证”的正式服插件开发骨架，不是又一个空白模板。它把最容易出错的
部分收口成四条可执行的规则：

- **四层架构**：入口装配 / 适配层 / 数据层 / 表现层，每个文件只有一个归属。
- **单一现代 API**：正式服没有老拍卖行，代码里也不保留任何老 API 的“万一”分支。
  原始 API 只允许出现在 `Core/Init.lua` 与 `Core/Env.lua`。
- **lupa 离线仿真**：不开游戏，按真实 `.toc` 顺序加载全部 Lua 文件，用最小 API
  mock 跑行为级测试，专抓 nil 崩溃、返回值形状错误、事件注册错误。
- **门禁 + 打包**：一条命令检查 toc、越层、老 API 残留、版本、LF/BOM、敏感信息，
  并打出可直接安装的 `AHProbe` 目录。

### 为什么单独一个仓库

正式服的插件架构与“经典 + 现代双客户端”不是同一件事：正式服只有现代拍卖行，
但多了连接服（ConnectedRealm）、无阵营市场、90 级等级上限、以及“文档里有、真机
可能没有”的能力差异。把这些差异和双客户端适配混在一起，会让两边都难读。

所以：

| 仓库 | 客户端 | 核心难点 |
| --- | --- | --- |
| `wow-addon-harness-classic` | Classic Era 1.15 + 1.60 现代 AH | 两套 API 的适配与互斥事件 |
| `wow-addon-harness-retail` | Retail 12.x | 连接服键、无阵营、能力探测、限流 |

### 为什么叫 Harness

Harness 是“试验台”。插件真正的风险不是语法错误，而是“看起来加载了，实际上没跑”：
事件名写错、API 返回整张表却当成单行、拍卖行开着却读了错误的宿主窗口。
这些问题在游戏里排查很慢，在试验台上几秒钟就能复现。

### 30 秒上手

```bash
python -m pip install lupa

# 跑行为级测试
python -m unittest discover -s tests -t . -v

# 跑仓库门禁
python tools/gate.py

# 打出安装包
python tools/package.py --out dist
```

把 `dist/AHProbe/AHProbe` 放进正式服的 `Interface/AddOns/`，进游戏输入 `/ahprobe`。

### 目录

```text
addon/AHProbe/        最小示例插件（只读拍卖行浏览结果，不自动交易）
  Core/Init.lua       入口、环境探测、共享工具
  Core/Env.lua        唯一适配层（原始现代 API 只允许出现在这里）
  Core/Probe.lua      数据层：查限流、发查询、读结果
  UI/Main.lua         表现层：建控件、转发点击
harness/              lupa 运行时、toc 加载器、Retail API mock
tests/                行为测试 / 门禁 / 打包测试
tools/                gate.py（门禁）、package.py（打包）
docs/                 架构、API 映射、踩坑、工作流（中英双语）
AGENTS.md             给 AI Agent 的可执行规则（中英双语）
```

### 示例插件 AHProbe

只做一件事：拍卖行打开后点“扫描”，显示当前浏览结果的条数。它故意演示了四个
正式服真实坑：

1. `C_AuctionHouse.GetBrowseResults()` **不接受索引**，直接返回整张表。
2. 正式服拍卖行**没有** `AuctionFrame`，宿主是 `AuctionHouseFrame`。
3. 拍卖行可能处于**限流**状态，发查询前要先问 `IsThrottled()`。
4. 文档里的部分商品搜索 API 在真机可能不存在，所以先跑 `Env.CapMissing()` 探测。

它不自动购买、不自动上架、不模拟点击，只调用暴雪公开 API。你可以把它当最小起点，
替换成自己的功能。

### 四层架构

| 层 | 允许 | 禁止 |
| --- | --- | --- |
| 入口装配 | 命名空间、命令、事件装配、加载自检 | 业务计算、建业务控件 |
| 适配层 | 唯一允许原始现代 API 的地方；对外只吐统一结构 | 业务决策（买不买、值不值） |
| 数据层 | 纯计算、存档读写、口径定义 | 直接碰 UI、直接碰原始 API |
| 表现层 | 建控件、渲染、转发点击、格式化 | 持有买入/上架原语、写业务判定 |

拿不准时问三句：换环境会变吗？会 → 适配层。在算值不值/记不记？是 → 数据层。
在把它画出来/等玩家点？是 → 表现层。

详见 [`docs/architecture.md`](docs/architecture.md)。

### 正式服 API 的四个关键口径

写任何涉及 API 的代码前，先查 [`docs/api-map.md`](docs/api-map.md)。最重要的四条：

- **连接服键**：拍卖行按连接服共享。存档键取排序后的首个连接服名，通常**不是**
  角色所在服名；区域唯一名开启时还要按规则集（PvP/RP/HC/PvE）分组。
- **无阵营市场**：联盟与部落共用一个拍卖行，价格库没有阵营维度。
- **等级上限 90**：装备筛选的 ilvl 上界是 90，不是 60。
- **能力不是全集**：`Env.Has("C_AuctionHouse.X")` 先问再写，缺了就显式降级。

### 加一个新功能

1. 在 `docs/api-map.md` 找到要用的 API，确认真机签名。
2. 判断落层：会随环境变 → `Core/Env.lua` 加接口；纯计算 → `Core/*`；画界面 → `UI/*`。
3. 先改 `addon/AHProbe/`，再按需在 `tests/` 加一条行为测试。
4. 跑测试与门禁。
5. 打包，进游戏验一次。

### 给第一次写插件的人

不需要先学完整个 WoW API。先让最小示例跑起来，再每次只改一个点：

- 改 UI 文案？只动 `UI/Main.lua`。
- 加一个查询条件？先看 `Core/Env.lua` 是否已有接口，再加测试。
- 报错“请先打开拍卖行”？先看 `Env.IsAuctionOpen()`，不要自己判窗口名。
- 不确定某个 API 在不在？在游戏里跑 `ns.Env.CapMissing()`。

写插件不是少数人的技能。这个仓库的目的，就是把“能跑起来”的门槛降到一条命令。

### 给 AI Agent

把 [`AGENTS.md`](AGENTS.md) 放在仓库根目录，Agent 会按同一套约束工作：先查 API 映射、
不越层、改完必跑测试与门禁、不把本机路径和账号信息写进仓库。

### 合规与免责声明

本项目只调用暴雪公开的客户端 API，示例不自动购买、不自动上架、不模拟点击。
使用前请阅读并遵守你所玩服务器与客户端的规则。本项目与 Blizzard Entertainment
无关联，不包含任何暴雪美术资源。

### License

MIT。见 [`LICENSE`](LICENSE)。

---

## English

### What this is

A development harness that can be **verified**, not another blank template. It
turns the error-prone parts of Retail add-on development into four executable
rules:

- **Four layers**: entry wiring / adapter / data / presentation. Every file has
  exactly one home.
- **One modern API surface**: Retail has no legacy Auction House, so the code
  keeps no “just in case” legacy branch. Raw APIs live only in `Core/Init.lua`
  and `Core/Env.lua`.
- **Offline simulation with lupa**: load every Lua file in real `.toc` order
  without launching the game. The minimal API mock catches nil crashes, wrong
  return shapes, and event-registration mistakes.
- **Gate + packaging**: one command checks the toc, layer leaks, leftover legacy
  APIs, version sync, LF/BOM, and sensitive strings, then builds an installable
  `AHProbe` folder.

### Why a separate repository

Retail add-on architecture is not the same problem as “Classic + modern AH”:
Retail has only the modern Auction House, but adds connected realms, a
factionless market, a level cap of 90, and APIs that may exist in documentation
but not in a given build. Mixing those concerns with a dual-client adapter makes
both trees harder to read.

| Repository | Client | Hard part |
| --- | --- | --- |
| `wow-addon-harness-classic` | Classic Era 1.15 + 1.60 modern AH | two API sets, mutually exclusive events |
| `wow-addon-harness-retail` | Retail 12.x | connected-realm key, factionless market, capability probing, throttling |

### Why “harness”

A harness is a test bench. The real risk in add-on development is not a syntax
error; it is “it loaded, but it does not work”: an event name typo, a whole table
treated as a single row, or reading the wrong host frame while the Auction House
is open. Those bugs are slow to debug in game and fast to reproduce on a bench.

### Quick start

```bash
python -m pip install lupa

python -m unittest discover -s tests -t . -v
python tools/gate.py
python tools/package.py --out dist
```

Copy `dist/AHProbe/AHProbe` into Retail's `Interface/AddOns/`, then type
`/ahprobe` in game.

### The demo add-on

`AHProbe` does one thing: after the Auction House is open, click **Scan** and it
shows the number of current browse results. It deliberately demonstrates four
real Retail pitfalls:

1. `C_AuctionHouse.GetBrowseResults()` takes **no index** and returns the whole
   table.
2. Retail has no `AuctionFrame`; the host is `AuctionHouseFrame`.
3. The Auction House can be **throttled**, so check `IsThrottled()` before
   sending.
4. Some commodity-search APIs documented online may be absent in a real build;
   probe with `Env.CapMissing()` first.

It does not auto-buy, auto-list, or simulate clicks. It only calls public
Blizzard APIs. Use it as a minimal starting point and replace the behavior with
your own.

### Learn more

- [`docs/architecture.md`](docs/architecture.md) — four layers and placement rules
- [`docs/api-map.md`](docs/api-map.md) — verified Retail API shapes
- [`docs/pitfalls.md`](docs/pitfalls.md) — the mistakes this harness exists to catch
- [`docs/workflow.md`](docs/workflow.md) — the day-to-day loop
- [`AGENTS.md`](AGENTS.md) — rules for AI coding agents

### Who this is for

First-time add-on authors, returning players, tool builders, and AI agents. You
do not need to learn the entire WoW API first. Get the demo running, then change
one small thing at a time.

Building add-ons is not a closed club. The point of this repository is to bring
“it runs” down to one command.

### Compliance

This project only calls public Blizzard client APIs. The demo does not auto-buy,
auto-list, or simulate clicks. Follow the rules of the server and client you use.
This project is not affiliated with Blizzard Entertainment and contains no
Blizzard art assets.

### License

MIT. See [`LICENSE`](LICENSE).
