# API Map / API 映射

> **Baseline / 基线** — Retail 12.x, Interface `120105`, modern Auction House
> only. Always probe at runtime with `Env.Has()`; a documented API may be absent
> in a given build.
>
> **原则** — 写任何涉及 API 的代码前，先在本表找到那一行。表里的“坑”都对应一次
> 真实事故或真机实测，不是从通用文档推断的。

## 1. Client context / 客户端环境

| Capability | Retail 12.x | Adapter | Pitfall |
| --- | --- | --- | --- |
| Flavor | `Env.Flavor() == "retail"` | `Env.Flavor()` | Do not read `ns.FLAVOR` in business code |
| AH host frame | `AuctionHouseFrame` | `ns.GetAHFrame()` | There is no `AuctionFrame` |
| AH open? | host `:IsShown()` | `Env.IsAuctionOpen()` | Never hard-code the host name |
| Level cap | 90 | `Env.MaxLevel()` | Writing 60 makes high-level gear unfilterable |
| Market faction | none | `Env.FactionKey()` → `""` | Do not bucket prices by faction |
| AH storage key | connected realm / ruleset | `Env.RealmKey()` | Often not the character's realm |
| Throttle | `C_AuctionHouse.IsThrottled()` | `Env.CanBrowse()` | A throttled query can silently do nothing |
| Capability probe | — | `Env.Has(path)`, `Env.CapMissing()` | Retail builds are not identical |

`Env.RealmKey()` follows the Auction House key, not the character:

1. If `RegionalUniqueNamesEnabled()` is true, the AH is grouped by ruleset:
   `PvP` / `RP` / `HC` / `PvE`.
2. Otherwise take `GetAutoCompleteRealms()`, sort it, and use the first name.
3. Fall back to `GetNormalizedRealmName()` or `GetRealmName()`.

## 2. Browse / 浏览查询

| Capability | Retail 12.x | Adapter | Pitfall |
| --- | --- | --- | --- |
| Send query | `C_AuctionHouse.SendBrowseQuery(queryTable)` | `Env.QueryBrowse()` | Results arrive by event, not return value |
| Result count | `#C_AuctionHouse.GetBrowseResults()` | `Env.GetBrowseCount()` | Takes **no index** |
| Result rows | `C_AuctionHouse.GetBrowseResults()` → whole table | Read via adapter | Do not call it per row |
| Full results? | `C_AuctionHouse.HasFullBrowseResults()` | Adapter | More pages may still be loading |
| Request more | `C_AuctionHouse.RequestMoreBrowseResults()` | Adapter | Do not assume one page is the whole market |
| Throttle | `C_AuctionHouse.IsThrottled()` | `Env.CanBrowse()` | Check before sending |

## 3. Events / 事件

| Capability | Retail 12.x | Adapter |
| --- | --- | --- |
| Browse results | `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED`, `_ADDED`, `_FAILURE` | `Env.RegisterAHEvents(frame, "browse")` |
| Item search | `ITEM_SEARCH_RESULTS_UPDATED` | `"item"` |
| Commodity purchase | `COMMODITY_PRICE_UPDATED`, `_UNAVAILABLE`, `COMMODITY_PURCHASE_SUCCEEDED`, `_FAILED` | `"commodity"` |
| AH open/close | `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED` | `"ah"` |

These are global broadcasts. If you act on a result, verify that it belongs to the
query you sent. Register each event inside `pcall`; a missing event must not abort
initialization.

## 4. Items / 物品

| Capability | Retail 12.x | Adapter | Pitfall |
| --- | --- | --- | --- |
| Item info | `C_Item.GetItemInfo(id)` | `ns.GetItemInfoSafe()` | Cold cache returns `nil`; that is normal |
| Item name | `C_Item.GetItemNameByID(id)` fallback | `Env.ItemName()` | Do not use a name as a hard filter |
| Max stack | return 8 | `Env.ItemMaxStack()` | `> 1` = commodity, `== 1` = unique item |
| Class ID | return **12** | `Env.ItemClassID()` | Return 11 is vendor price, not classID |
| Equip location | return 9 | `Env.ItemEquipLoc()` | Empty string is valid for non-equipment |

## 5. Bags / 背包

| Capability | Retail 12.x | Adapter |
| --- | --- | --- |
| Slot count | `C_Container.GetContainerNumSlots(bag)` | `Env.BagNumSlots()` |
| Item ID | `C_Container.GetContainerItemID(bag, slot)` | `Env.BagItemID()` |
| Item info | `C_Container.GetContainerItemInfo(...)` → info table | `Env.BagItemInfo()` |
| Item link | `C_Container.GetContainerItemLink(...)` | `Env.BagItemInfo().link` |

`C_Container` must be fetched at **call time**, not captured at file load time.
The offline harness installs the API after the add-on loads; a top-of-file
capture becomes `nil` forever. Modern container info is a table with a
`stackCount` field, not multiple return values.

## 6. Trading actions (not used by the demo) / 交易动作（示例未使用）

The demo is read-only on purpose. If you add trading, these are the shapes to
start from; verify them on the real client before shipping.

| Capability | Retail 12.x | Notes |
| --- | --- | --- |
| Bid / buy item | `C_AuctionHouse.PlaceBid(auctionID, bidAmount)` | `auctionID` comes from a browse row |
| Buy commodity | `StartCommoditiesPurchase(itemID, quantity)` → `ConfirmCommoditiesPurchase(itemID, quantity)` → `CancelCommoditiesPurchase()` | First argument is an **itemID number**, not an itemKey table |
| Post commodity | `C_AuctionHouse.PostCommodity(...)` | Verify stack count and duration |
| Available posts | `C_AuctionHouse.GetAvailablePostCount(itemKey)` | Do not assume one |
| Item key | `MakeItemKey(itemID, itemLevel, itemSuffix, battlePetSpeciesID)` | Needed by search/sell paths |
| Owned auctions | `QueryOwnedAuctions(...)`, `GetOwnedAuctionInfo(...)` | Results arrive by event |

Two warnings:

- Purchase confirmation must run inside the client's real click stack. A
  self-drawn button that directly calls the purchase API can be silently
  discarded by the server. Use the native dialog/menu, and verify the result,
  not just the button state.
- Do not infer success from local UI state. Confirm from the server response or
  your own ledger.

## 7. Return-shape cheat sheet / 返回值速查

```lua
-- Retail browse: one table, no index.
local ok, rows = pcall(C_AuctionHouse.GetBrowseResults)

-- Retail container info: one table with a stackCount field.
local info = C_Container.GetContainerItemInfo(bag, slot)
local count = info and info.stackCount or 0

-- Retail item info: return 11 is vendor price; return 12 is classID.
local name, link, quality, ilvl, reqLevel, class, subclass,
      maxStack, equipLoc, icon, vendorPrice, classID = C_Item.GetItemInfo(id)
```

If a function's return shape is surprising, confirm it once on the real client
and write the result in this table. Do not add a guess to business code.
