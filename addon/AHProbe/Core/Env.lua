--[[
  AHProbe / Core/Env.lua

  Retail-only adapter (12.x, Interface 120105). There is no legacy branch here:
  the classic repository owns the dual-client adapter. This tree stays
  single-flavor so the rules are easy to see and easy to test.

  Rules that still apply:
    1. Raw client APIs belong here (and in Init), never in business code.
    2. No business decisions in this file.
    3. Every external call is wrapped in pcall. A missing API is normal, not an
       exception; return nil and let the caller degrade explicitly.
]]

local ADDON_NAME, ns = ...

local Env = {}
ns.Env = Env

local AH_EVENTS = {
  browse = {
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "AUCTION_HOUSE_BROWSE_FAILURE",
  },
  item = {
    "ITEM_SEARCH_RESULTS_UPDATED",
  },
  commodity = {
    "COMMODITY_PRICE_UPDATED",
    "COMMODITY_PRICE_UNAVAILABLE",
    "COMMODITY_PURCHASE_SUCCEEDED",
    "COMMODITY_PURCHASE_FAILED",
  },
  ah = {
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
  },
}

-- Capability probe list. Retail builds are not identical: an API that exists in
-- the documentation may be absent in a given build. Probe before relying on it.
Env.CAPS = {
  "C_AuctionHouse.SendBrowseQuery",
  "C_AuctionHouse.GetBrowseResults",
  "C_AuctionHouse.HasFullBrowseResults",
  "C_AuctionHouse.RequestMoreBrowseResults",
  "C_AuctionHouse.IsThrottled",
  "C_AuctionHouse.MakeItemKey",
  "C_AuctionHouse.GetItemKeyInfo",
  "C_AuctionHouse.SendSearchQuery",
  "C_AuctionHouse.GetNumItemSearchResults",
  "C_AuctionHouse.GetItemSearchResultInfo",
  "C_AuctionHouse.GetCommoditySearchResults",
  "C_AuctionHouse.GetNumCommoditySearchResults",
  "C_AuctionHouse.RequestMoreCommoditySearchResults",
  "C_AuctionHouse.IsSellItemValid",
  "C_AuctionHouse.GetAvailablePostCount",
  "C_AuctionHouse.PlaceBid",
  "C_AuctionHouse.StartCommoditiesPurchase",
  "C_AuctionHouse.ConfirmCommoditiesPurchase",
  "C_AuctionHouse.PostCommodity",
  "C_AuctionHouse.CalculateCommodityDeposit",
  "C_AuctionHouse.CalculateItemDeposit",
  "C_AuctionHouse.GetAuctionInfoByID",
  "C_AuctionHouse.QueryOwnedAuctions",
  "C_AuctionHouse.GetOwnedAuctionInfo",
}

local function Call1(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if ok then
    return value
  end
  return nil
end

-- Fetch these at call time, not at file load time. The offline harness installs
-- the globals after the add-on loads; a top-of-file capture stays nil forever.
local function AH()
  return (type(_G.C_AuctionHouse) == "table") and _G.C_AuctionHouse or nil
end

local function CC()
  return (type(_G.C_Container) == "table") and _G.C_Container or nil
end

local function CCfn(name)
  local cc = CC()
  if cc and type(cc[name]) == "function" then
    return cc[name]
  end
  return nil
end

local function RulesetName()
  local rules = _G.C_GameRules
  local enum = _G.Enum and _G.Enum.GameRule
  if type(rules) ~= "table" or type(rules.IsGameRuleActive) ~= "function"
      or type(enum) ~= "table" then
    return nil
  end

  local function active(key)
    local id = enum[key]
    if id == nil then
      return false
    end
    local ok, value = pcall(rules.IsGameRuleActive, id)
    return (ok and value) and true or false
  end

  if active("PvPRuleset") then return "PvP" end
  if active("RPRuleset") then return "RP" end
  if active("HardcoreRuleset") then return "HC" end
  return "PvE"
end

function Env.IsModern()
  return true
end

function Env.Flavor()
  return "retail"
end

function Env.MaxLevel()
  return 90
end

-- Dotted-path existence check: Env.Has("C_AuctionHouse.GetBrowseResults").
function Env.Has(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  local node = _G
  for part in path:gmatch("[^%.]+") do
    if type(node) ~= "table" then
      return false
    end
    node = node[part]
    if node == nil then
      return false
    end
  end
  return true
end

function Env.Cap(name)
  return Env.Has(name)
end

function Env.CapAll()
  local result = {}
  for _, name in ipairs(Env.CAPS) do
    result[name] = Env.Has(name)
  end
  return result
end

function Env.CapMissing()
  local missing = {}
  for _, name in ipairs(Env.CAPS) do
    if not Env.Has(name) then
      missing[#missing + 1] = name
    end
  end
  return missing
end

-- Retail Auction House key. The AH is shared by a connected realm, so the key
-- is the alphabetically first connected realm, or a ruleset name when regional
-- unique names are enabled. It is often NOT the character's own realm name.
function Env.RealmKey()
  if type(_G.RegionalUniqueNamesEnabled) == "function" then
    local ok, enabled = pcall(_G.RegionalUniqueNamesEnabled)
    if ok and enabled then
      local ruleset = RulesetName()
      if ruleset then
        return ruleset
      end
    end
  end

  if type(_G.GetAutoCompleteRealms) == "function" then
    local ok, realms = pcall(_G.GetAutoCompleteRealms)
    if ok and type(realms) == "table" and #realms > 0 then
      local sorted = {}
      for i = 1, #realms do
        sorted[i] = tostring(realms[i])
      end
      table.sort(sorted)
      if sorted[1] and sorted[1] ~= "" then
        return sorted[1]
      end
    end
  end

  local realm = Call1(_G.GetNormalizedRealmName) or Call1(_G.GetRealmName)
  return (type(realm) == "string" and realm ~= "") and realm or "?"
end

-- The retail Auction House is factionless: both factions share one market, and
-- price databases have no faction dimension.
function Env.FactionKey()
  return ""
end

-- ---------------------------------------------------------------------------
-- Bags / 背包
-- ---------------------------------------------------------------------------

function Env.BagCount()
  local count = (type(_G.NUM_BAG_SLOTS) == "number") and _G.NUM_BAG_SLOTS or 4
  if type(_G.NUM_REAGENTBAG_SLOTS) == "number" then
    count = count + _G.NUM_REAGENTBAG_SLOTS
  end
  if count < 5 then
    count = 5
  end
  return count
end

function Env.BagNumSlots(bag)
  bag = tonumber(bag)
  if not bag then
    return 0
  end
  return tonumber(Call1(CCfn("GetContainerNumSlots"), bag)) or 0
end

function Env.BagItemID(bag, slot)
  bag, slot = tonumber(bag), tonumber(slot)
  if not bag or not slot then
    return nil
  end
  local id = tonumber(Call1(CCfn("GetContainerItemID"), bag, slot))
  if id then
    return id
  end
  local link = Call1(CCfn("GetContainerItemLink"), bag, slot)
  if type(link) == "string" then
    return tonumber(link:match("item:(%d+)"))
  end
  return nil
end

-- Returns { itemID, stackCount, link } or nil for an empty slot.
function Env.BagItemInfo(bag, slot)
  bag, slot = tonumber(bag), tonumber(slot)
  if not bag or not slot then
    return nil
  end

  local info = Call1(CCfn("GetContainerItemInfo"), bag, slot)
  if type(info) == "table" then
    local id = tonumber(info.itemID) or Env.BagItemID(bag, slot)
    if id then
      return {
        itemID = id,
        stackCount = tonumber(info.stackCount) or 1,
        link = info.itemLink or info.link,
      }
    end
  end

  -- Some builds expose the ID but not the info table. Keep the ID, assume 1.
  local id = Env.BagItemID(bag, slot)
  if id then
    return { itemID = id, stackCount = 1, link = nil }
  end
  return nil
end

function Env.ForEachBagSlot(fn)
  if fn == nil then
    return 0
  end
  local visited = 0
  for bag = 0, Env.BagCount() do
    local slots = Env.BagNumSlots(bag)
    for slot = 1, slots do
      local info = Env.BagItemInfo(bag, slot)
      if info then
        visited = visited + 1
        fn(bag, slot, info.itemID, info.stackCount, info.link)
      end
    end
  end
  return visited
end

-- ---------------------------------------------------------------------------
-- Items / 物品
-- ---------------------------------------------------------------------------

function Env.ItemInfo(item)
  return ns.GetItemInfoSafe(item)
end

function Env.ItemID(item)
  local id = tonumber(item)
  if id then
    return id
  end
  if type(item) == "string" then
    return tonumber(item:match("item:(%d+)"))
  end
  return nil
end

function Env.ItemName(item)
  return ns.GetItemInfoSafe(item)
end

function Env.ItemMaxStack(item)
  return ns.ItemMaxStack(item)
end

function Env.ItemClassID(item)
  local _, _, raw = ns.GetItemInfoSafe(item)
  return tonumber(raw and raw[12])
end

function Env.ItemEquipLoc(item)
  local _, _, raw = ns.GetItemInfoSafe(item)
  local value = raw and raw[9]
  return (type(value) == "string") and value or nil
end

-- ---------------------------------------------------------------------------
-- Auction House / 拍卖行
-- ---------------------------------------------------------------------------

function Env.AHFrame()
  return ns.GetAHFrame()
end

function Env.IsAuctionOpen()
  return ns.IsAuctionOpen()
end

function Env.CanBrowse()
  local ah = AH()
  if type(ah) ~= "table" then
    return false
  end
  if type(ah.IsThrottled) == "function" then
    local ok, throttled = pcall(ah.IsThrottled)
    if ok then
      return not throttled
    end
  end
  return true
end

function Env.QueryBrowse()
  local ah = AH()
  if type(ah) ~= "table" or type(ah.SendBrowseQuery) ~= "function" then
    return false, "C_AuctionHouse.SendBrowseQuery is missing"
  end
  local ok, err = pcall(ah.SendBrowseQuery, {})
  if not ok then
    return false, tostring(err)
  end
  return true
end

-- GetBrowseResults takes no index; it returns the whole table.
function Env.GetBrowseCount()
  local ah = AH()
  if type(ah) ~= "table" or type(ah.GetBrowseResults) ~= "function" then
    return 0
  end
  local ok, rows = pcall(ah.GetBrowseResults)
  if ok and type(rows) == "table" then
    return #rows
  end
  return 0
end

function Env.RegisterAHEvents(frame, set)
  if type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
    return 0
  end
  local list = AH_EVENTS[set]
  if not list then
    return 0
  end

  local count = 0
  for i = 1, #list do
    if pcall(frame.RegisterEvent, frame, list[i]) then
      count = count + 1
    end
  end
  return count
end

function Env.NewEventFrame(events)
  local frame = _G.CreateFrame("Frame")
  if type(events) == "table" then
    for i = 1, #events do
      pcall(frame.RegisterEvent, frame, events[i])
    end
  end
  return frame
end
