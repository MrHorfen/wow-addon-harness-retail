--[[
  AHProbe / Core/Init.lua

  Entry point for the Retail (12.x, Interface 120105) harness.

  Retail has a modern Auction House API. There is no legacy branch here on
  purpose: the classic repository owns the dual-client adapter. Keeping this
  tree single-flavor makes both trees easier to read and test.
]]

local ADDON_NAME, ns = ...

ns.VERSION = "0.1.0"
ns.DISPLAY = "AH Probe"
ns.FLAVOR = "retail"

-- Debug handle for the offline harness. Harmless in game.
_G.AHProbeNS = ns

-- Minimal localization. Add another table if you need more languages.
ns.L = {
  enUS = {
    TITLE = "AH Probe",
    MODE = "Mode",
    AUCTIONS = "Auctions",
    SCAN = "Scan",
    OPEN_AH = "Open the auction house first.",
    THROTTLED = "The auction house is throttled. Try again in a moment.",
    QUERY_SENT = "Browse query sent (%s).",
    QUERY_FAILED = "Query failed: %s",
    RETAIL = "Retail",
  },
  zhCN = {
    TITLE = "拍卖行探针",
    MODE = "模式",
    AUCTIONS = "拍卖行条目",
    SCAN = "扫描",
    OPEN_AH = "请先打开拍卖行。",
    THROTTLED = "拍卖行正在限流，请稍后再试。",
    QUERY_SENT = "已发出浏览查询（%s）。",
    QUERY_FAILED = "查询失败：%s",
    RETAIL = "正式服",
  },
}

function ns.Lang(key)
  local locale = (type(_G.GetLocale) == "function" and _G.GetLocale()) or "enUS"
  local pack = (locale == "zhCN" or locale == "zhTW") and ns.L.zhCN or ns.L.enUS
  return pack[key] or ns.L.enUS[key] or key
end

function ns.Print(message)
  if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
    _G.DEFAULT_CHAT_FRAME:AddMessage(
      "|cff00ff96" .. ns.DISPLAY .. "|r " .. tostring(message)
    )
  end
end

function ns.GetAHFrame()
  return _G.AuctionHouseFrame
end

function ns.IsAuctionOpen()
  local frame = ns.GetAHFrame()
  if not frame or type(frame.IsShown) ~= "function" then
    return false
  end
  local ok, shown = pcall(frame.IsShown, frame)
  return (ok and shown) and true or false
end

-- Returns name, link, raw[1..12].
-- raw[8] = maxStack, raw[11] = vendor price, raw[12] = classID.
function ns.GetItemInfoSafe(item)
  local item_api = _G.C_Item
  local fn = (type(item_api) == "table") and item_api.GetItemInfo or nil
  if type(fn) ~= "function" then
    return nil
  end

  local ok, name, link, quality, ilvl, reqLevel, class, subclass,
        maxStack, equipLoc, icon, vendorPrice, classID = pcall(fn, item)
  if not ok or name == nil then
    return nil
  end

  local raw = {
    name, link, quality, ilvl, reqLevel, class, subclass,
    maxStack, equipLoc, icon, vendorPrice, classID,
  }
  return name, link, raw
end

function ns.ItemMaxStack(item)
  local _, _, raw = ns.GetItemInfoSafe(item)
  return tonumber(raw and raw[8]) or 1
end
