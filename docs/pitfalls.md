# Pitfalls / 踩坑清单

> **EN TL;DR** — Most Retail add-on bugs are not syntax errors. They are wrong
> return shapes, missing APIs, wrong host frames, connected-realm keys, and mocks
> that are nicer than the real client. This page lists the mistakes the harness
> is designed to catch.
>
> **中文摘要** — 正式服插件 bug 大多不是语法错误，而是返回值形状、缺失 API、
> 宿主窗口、连接服键，以及“比真机更宽松”的夹具。下面这些坑，试验台就是为它们
> 准备的。

## English

1. **`C_AuctionHouse.GetBrowseResults()` takes no index.** It returns the whole
   table. `GetBrowseResults(i)` is a paper API that does not exist on the real
   client.

2. **Retail has no `AuctionFrame`.** The host is `AuctionHouseFrame`.
   Hard-coding the legacy name makes the add-on claim the AH is closed even when
   it is open.

3. **The Auction House can be throttled.** Check `C_AuctionHouse.IsThrottled()`
   before sending a query. A throttled query can silently do nothing.

4. **Documented commodity-search APIs may be missing.** Probe with
   `Env.Has("C_AuctionHouse.X")` or `Env.CapMissing()` and degrade explicitly.
   Do not spin a progress indicator forever.

5. **The AH key is the connected realm, not the character's realm.**
   `GetNormalizedRealmName()` can differ from the key used by price databases.
   Sort `GetAutoCompleteRealms()` and take the first name.

6. **Regional unique names change the grouping.** When
   `RegionalUniqueNamesEnabled()` is true, the AH is grouped by ruleset
   (`PvP` / `RP` / `HC` / `PvE`), not by realm.

7. **Retail's Auction House is factionless.** Do not bucket prices by
   `UnitFactionGroup`; both factions share one market.

8. **The level cap is 90.** Writing 60 into an item-level filter silently hides
   high-level gear.

9. **`C_Container` must be fetched at call time.** Capturing it at file load
   time is `nil` in the offline harness and can be `nil` during early load in
   game. Fetch inside the function.

10. **Container info is a table, not multiple returns.** Read
    `info.stackCount`, not the second return value.

11. **Item info indexes are easy to swap.** Return 11 is the vendor price,
    return 12 is `classID`. Getting this wrong misclassifies items.

12. **`maxStack > 1` is the commodity test.** Do not use `isCommodity`; an
    aggregated gear row can be misclassified as a commodity.

13. **A commodity purchase starts with an itemID, not an itemKey.** Passing a
    table where a number is expected is a common paper-API mistake.

14. **Purchase confirmation must be in the real click stack.** A self-drawn
    button that directly calls the purchase API can be silently dropped. Use the
    native dialog/menu and verify the result.

15. **“The button changed color” is not “the purchase succeeded”.** Confirm from
    the server response or the ledger, not from local UI state.

16. **A mock that is nicer than the client hides bugs.** If the mock adds a
    method the real client does not have, the test can pass while the game
    fails. Only mock methods you have verified.

17. **lupa runs Lua 5.5; the game runs Lua 5.1.** Add the shim
    `unpack = unpack or table.unpack` before loading anything.

18. **Load the full `.toc`, not a hand-written file list.** A file missing from
    the test list is a file whose bugs are invisible.

19. **A cold item cache returns `nil`.** That is normal. Do not use a name as a
    hard filter; use item IDs where possible.

## 中文

1. **`C_AuctionHouse.GetBrowseResults()` 不接受索引。** 它直接返回整张表。
   `GetBrowseResults(i)` 是纸面 API，真机不存在。

2. **正式服没有 `AuctionFrame`。** 宿主是 `AuctionHouseFrame`。写死老名字，
   拍卖行明明开着也会被判成“没开”。

3. **拍卖行可能被限流。** 发查询前先问 `C_AuctionHouse.IsThrottled()`。
   限流状态下，查询可能静默地什么也不做。

4. **文档里的商品搜索 API 可能不存在。** 先用
   `Env.Has("C_AuctionHouse.X")` 或 `Env.CapMissing()` 探测，缺了显式降级，
   不要一直转圈。

5. **拍卖行键是连接服，不是角色所在服。** `GetNormalizedRealmName()` 可能与
   价格库使用的键不同。取 `GetAutoCompleteRealms()` 排序后的首个名字。

6. **区域唯一名会改变分组。** `RegionalUniqueNamesEnabled()` 为真时，拍卖行按
   规则集分组（`PvP` / `RP` / `HC` / `PvE`），不再按服务器名。

7. **正式服拍卖行不分阵营。** 不要用 `UnitFactionGroup` 给价格分桶；联盟部落
   共用一个市场。

8. **等级上限是 90。** 把 60 写进装备等级筛选项，会静默过滤掉高级装备。

9. **`C_Container` 必须在函数体内取。** 文件顶部捕获，在离线夹具里永远是 `nil`；
   游戏里过早加载也可能拿不到。调用时再取。

10. **背包信息是一张表，不是多个返回值。** 读 `info.stackCount`，不要读第二个
    返回值。

11. **物品信息的下标很容易错。** 第 11 项是卖店价，第 12 项才是 `classID`。
    取错会把物品分错类。

12. **`maxStack > 1` 才是商品判据。** 不要用 `isCommodity`；聚合后的装备行会被
    误判成商品。

13. **商品购买的第一个参数是 itemID，不是 itemKey。** 该传数字的地方传表，
    是典型的“照抄纸面文档”错误。

14. **购买确认必须在真实点击栈内。** 自绘按钮直接调购买 API，可能被服务器静默
    丢弃。用原生对话框/菜单，并校验结果。

15. **“按钮变色了”不等于“买到了”。** 以服务端回执或账本为准，不以本地 UI 状态为准。

16. **比真机更宽松的夹具会藏 bug。** 夹具里多一个真机没有的方法，测试会绿、游戏会炸。
    只 mock 你核实过的方法。

17. **lupa 跑 Lua 5.5，游戏跑 Lua 5.1。** 加载任何东西之前先垫
    `unpack = unpack or table.unpack`。

18. **按完整 `.toc` 加载，不要手写文件清单。** 测试清单里漏掉的文件，它的 bug
    就是隐形的。

19. **物品缓存冷启动返回 `nil` 是正常的。** 不要拿名字当硬过滤条件；能用 itemID
    就用 itemID。
