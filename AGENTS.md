# Agent Guide / Agent 指南

> Read this before changing code. 改代码前先读这里。
> The gate enforces most of these rules; the rest need judgment.
> 门禁会强制其中大部分规则，剩下的靠判断。

## Non-negotiables / 铁律

1. **API map first / 先查映射表.** Before writing API code, find the row in
   `docs/api-map.md`. Do not trust memory or generic tutorials.
   写任何 API 代码前先在 `docs/api-map.md` 找到对应行，不要凭记忆或通用教程。

2. **One adapter, one client / 一个适配层，一个客户端.** Raw modern APIs
   (`C_AuctionHouse`, `C_Container`, `C_Item`, `AuctionHouseFrame`) belong in
   `Core/Init.lua` and `Core/Env.lua` only. Business code calls `ns.Env.*`.
   This tree is Retail-only: do not add legacy APIs or a `ns.MODERN_AH` flag.
   `tools/gate.py` fails on both.
   原始现代 API 只允许出现在 `Core/Init.lua` 和 `Core/Env.lua`，业务代码一律调用
   `ns.Env.*`。本仓只做正式服：不许加老 API，也不许加 `ns.MODERN_AH` 分支；
   两者都会被门禁拦下。

3. **Load order is dependency order / 加载顺序即依赖顺序.** New files must be
   added to `AHProbe.toc` between what they depend on and what depends on them.
   The test loader reads the toc; never hand-write a file list.
   新文件必须按依赖顺序加入 `AHProbe.toc`；测试按 toc 全量加载，禁止手写清单。

4. **Test behavior, not strings / 测行为，不测字符串.** A static assertion cannot
   catch “the button does nothing”. Fire the event, call the function, read the
   result.
   静态断言抓不住“点了没反应”。要触发事件、调用函数、读回结果。

5. **Gate, package, then claim done / 先过门禁与打包，再说完成.** Run the tests,
   the gate, and the package before reporting success.
   声称完成前必须跑测试、门禁和打包。

6. **No secrets, no local paths / 不写密钥与本机路径.** Never add absolute
   paths, account directory names, tokens, SavedVariables dumps, logs, or
   database files. The gate scans for these.
   不写绝对路径、账号目录名、token、存档转储、日志或数据库文件；门禁会扫描。

7. **Public APIs only / 只调用公开 API.** No automation, no simulated clicks, no
   auto-buy, no auto-list. The demo is deliberately read-only.
   不自动购买、不自动上架、不模拟点击；示例只读。

## Workflow / 工作流

```bash
python -m unittest discover -s tests -t . -v
python tools/gate.py
python tools/package.py --out dist
```

If a change touches `Core/Env.lua`, the full suite must still pass. If it adds a
new file, update the toc and the expected file list in `tests/test_retail.py`.
如果改了 `Core/Env.lua`，全套测试必须通过；如果新增文件，同步更新 toc 与
`tests/test_retail.py` 里的期望文件清单。

## When unsure / 拿不准时

Ask the three placement questions in `docs/architecture.md`. If all three fail,
the requirement is not decomposed enough; split it before writing code.
用 `docs/architecture.md` 的三问判断落层；三问都答不上，说明需求拆得不够，先拆需求。
